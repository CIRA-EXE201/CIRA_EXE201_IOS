//
//  SyncManager.swift
//  Cira
//
//  Offline-first sync manager for Supabase
//

import Foundation
import Network
import SwiftData
import Combine
import Supabase
import Auth



// MARK: - Chapter DTO for Supabase


@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published private(set) var isOnline = true
    @Published private(set) var isSyncing = false
    @Published private(set) var pendingCount = 0
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var modelContext: ModelContext?
    
    private init() {
        startMonitoring()
        
        NotificationCenter.default.addObserver(
            forName: .newPostSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.performFullSync()
            }
        }
    }
    
    // MARK: - Setup
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Fix any duplicate objects created by previous sync bugs
        deduplicateData(context: modelContext)
    }
    
    private func deduplicateData(context: ModelContext) {
        do {
            if let chapters = try? context.fetch(FetchDescriptor<Chapter>()) {
                var seen = Set<String>()
                for chapter in chapters {
                    let idStr = chapter.id.uuidString.lowercased()
                    if seen.contains(idStr) {
                        context.delete(chapter)
                    } else {
                        seen.insert(idStr)
                    }
                }
            }
            if let photos = try? context.fetch(FetchDescriptor<Photo>()) {
                var seen = Set<String>()
                for photo in photos {
                    let idStr = photo.id.uuidString.lowercased()
                    if seen.contains(idStr) {
                        context.delete(photo)
                    } else {
                        seen.insert(idStr)
                    }
                }
            }
            try context.save()
        } catch {
            print("❌ Failed to deduplicate data: \(error)")
        }
    }
    
    // MARK: - Network Monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                
                // Auto-sync when coming back online
                if wasOffline && path.status == .satisfied {
                    await self?.performFullSync()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Sync Operations
    func performFullSync() async {
        guard isOnline else {
            print("⚠️ Sync skipped: Device is offline")
            return
        }
        guard !isSyncing else {
            print("⚠️ Sync skipped: Already syncing")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("🔄 Starting Full Sync...")
        
        // Only run expensive repair + upload when there are pending posts
        if await hasPendingPosts() {
            await repairIncompleteUploads()
            await syncPendingPosts()
        }
        
        await syncPendingChapters()
        await syncDown()
        await syncDownChapters()
        print("🔄 Full Sync Complete!")
    }
    
    // MARK: - Quick Pending Check
    private func hasPendingPosts() async -> Bool {
        guard let modelContext = modelContext else { return false }
        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.syncStatusRaw == pendingRaw || $0.syncStatusRaw == failedRaw }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
    
    // MARK: - Repair Incomplete Uploads
    /// Finds posts that are marked as .synced locally but have missing image_path on server
    /// This can happen if sync was interrupted or imageData was nil during upload
    func repairIncompleteUploads() async {
        guard let modelContext = modelContext else { return }
        guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else { return }
        
        print("🔧 Checking for incomplete uploads...")
        
        do {
            // 1. Get all local posts marked as synced
            let syncedRaw = SyncStatus.synced.rawValue
            let descriptor = FetchDescriptor<Photo>(
                predicate: #Predicate { $0.syncStatusRaw == syncedRaw }
            )
            let syncedPhotos = try modelContext.fetch(descriptor)
            
            if syncedPhotos.isEmpty {
                print("🔧 No synced posts to verify")
                return
            }
            
            // 2. Get all remote posts for this user
            let remotePosts: [PostDTO] = try await SupabaseManager.shared.fetchUserPosts(userId: userId)
            
            // 3. Find posts that exist on server but have no image_path
            let brokenRemoteIDs = Set(remotePosts.filter { $0.image_path == nil || $0.image_path?.isEmpty == true }.map { $0.id })
            
            // 4. Find local posts that match broken remote posts
            var repairedCount = 0
            for photo in syncedPhotos {
                let photoIdString = photo.id.uuidString
                if brokenRemoteIDs.contains(photoIdString) {
                    print("🔧 Found broken sync for photo: \(photoIdString)")
                    
                    // Check if we have imageData locally
                    if photo.imageData != nil {
                        // We have the image, reset to pending so it will be re-uploaded
                        photo.syncStatus = .pending
                        repairedCount += 1
                        print("   ↳ Reset to pending - will re-upload")
                    } else {
                        // We don't have the image locally either - mark as failed
                        photo.syncStatus = .failed
                        print("   ↳ No local imageData - marked as failed")
                    }
                }
            }
            
            if repairedCount > 0 {
                try modelContext.save()
                print("🔧 Repaired \(repairedCount) incomplete uploads - will re-sync")
            } else {
                print("🔧 All synced posts are complete")
            }
            
        } catch {
            print("❌ Repair check failed: \(error)")
        }
    }
    
    func syncPendingPosts() async {
        guard let modelContext = modelContext else { return }
        
        // Use raw string values for predicate comparison
        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.syncStatusRaw == pendingRaw || $0.syncStatusRaw == failedRaw }
        )
        
        // Debug Auth
        guard let user = SupabaseManager.shared.currentUser else {
            print("❌ Sync aborted: No authenticated user found.")
            return
        }
        print("👤 Syncing as user: \(user.id) | Email: \(user.email ?? "nil")")
        
        do {
            let pendingPhotos = try modelContext.fetch(descriptor)
            pendingCount = pendingPhotos.count
            
            // Limit concurrency to avoid overwhelming network/server
            // Since we are on MainActor, we need to be careful.
            // We use TaskGroup but we must ensure we don't block.
            
            await withTaskGroup(of: Void.self) { group in
                for photo in pendingPhotos {
                    group.addTask {
                        // Capturing 'photo' (SwiftData class) in a Sendable closure might be risky
                        // if strict concurrency is on. But since syncPhoto is on MainActor,
                        // and we await it, actual mutation happens on MainActor.
                        await self.syncPhoto(photo)
                    }
                }
            }
            
            try modelContext.save()
            pendingCount = 0
        } catch {
            print("❌ Sync failed: \(error)")
        }
    }
    
    private func syncPhoto(_ photo: Photo) async {
        photo.syncStatus = .syncing
        
        // CRITICAL: Don't sync if imageData is nil - this would create incomplete records
        guard let imageData = photo.imageData else {
            print("⚠️ Cannot sync photo \(photo.id): imageData is nil - keeping as pending")
            photo.syncStatus = .pending // Keep as pending so we can retry later
            return
        }
        
        do {
            // Prepare upload tasks
            // We use async let to run them concurrently on the network layer
            
            // 1. Upload Voice Note (if exists)
            async let voiceURLUpload: String? = {
                if let voiceNote = photo.voiceNote,
                   let audioURL = voiceNote.audioFileURL,
                   let audioData = try? Data(contentsOf: audioURL) {
                    return try await SupabaseManager.shared.uploadAudio(
                        data: audioData,
                        fileName: "voice_\(photo.id.uuidString).m4a"
                    )
                }
                return nil
            }()
            
            // 2. Upload Live Photo Video (if exists)
            async let livePhotoPathUpload: String? = {
                if let movieURL = photo.livePhotoMovieURL {
                    return try await SupabaseManager.shared.uploadVideo(
                        fileURL: movieURL,
                        fileName: "video_\(photo.id.uuidString).mov"
                    )
                }
                return nil
            }()
            
            // 3. Upload Image (REQUIRED)
            async let imagePathUpload: String = SupabaseManager.shared.uploadImage(
                data: imageData,
                fileName: "image_\(photo.id.uuidString).jpg"
            )
            
            // Await all results
            let (voiceURL, livePhotoPath, imagePath) = try await (voiceURLUpload, livePhotoPathUpload, imagePathUpload)
            
            print("📤 Uploaded image to path: \(imagePath)")
            
            // 4. Upsert Post Record
            let postData = PostDTO(
                id: photo.id.uuidString,
                owner_id: SupabaseManager.shared.currentUser?.id.uuidString ?? "",
                image_path: imagePath,
                live_photo_path: livePhotoPath,
                message: photo.message,
                voice_url: voiceURL,
                voice_duration: photo.voiceNote?.duration,
                visibility: photo.visibility.rawValue,  // Use post's visibility setting
                created_at: ISO8601DateFormatter().string(from: photo.createdAt),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await SupabaseManager.shared.client
                .from("posts")
                .upsert(postData)
                .execute()
            
            photo.syncStatus = .synced
            print("✅ Synced photo: \(photo.id) with image_path: \(imagePath)")
            
        } catch {
            photo.syncStatus = .failed
            print("❌ Failed to sync photo \(photo.id): \(error)")
        }
    }
    
    // MARK: - Down Sync
    // MARK: - Delta Sync Persistence
    private var lastSyncTime: Date? {
        get {
            guard let interval = UserDefaults.standard.value(forKey: "last_sync_timestamp") as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "last_sync_timestamp")
            } else {
                UserDefaults.standard.removeObject(forKey: "last_sync_timestamp")
            }
        }
    }
    
    // MARK: - Down Sync
    func syncDown() async {
        guard let modelContext = modelContext else {
            print("❌ SyncDown skipped: No modelContext configured")
            return
        }
        
        guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
            print("❌ SyncDown skipped: No authenticated user")
            return
        }
        
        print("📥 Starting Down Sync for user: \(userId)")
        
        // Use lastSyncTime for Delta Sync (if available)
        let lastSync = lastSyncTime
        if let lastSync = lastSync {
            print("⏱️ Delta Sync: Fetching changes since \(lastSync)")
        } else {
            print("🌍 Full Sync: Fetching all posts")
        }
        
        do {
            // 1. Fetch Remote Posts (Delta or Full - ALL visible posts, including friends)
            let remotePosts: [PostDTO] = try await SupabaseManager.shared.fetchAllVisiblePosts(after: lastSync)
            print("📥 Found \(remotePosts.count) new/updated remote posts")
            
            if remotePosts.isEmpty {
                print("✅ Sync is up to date.")
                return 
            }
            
            // 2. Process fetched posts
            // For delta sync, we just process everything we got because it's new/updated.
            // However, we still check existing ID to support updates (upsert logic).
            
            let IDs = remotePosts.map { $0.id }
            let descriptor = FetchDescriptor<Photo>(
                predicate: #Predicate { IDs.contains($0.id.uuidString) }
            )
            // Ideally we'd optimize this predicates but SwiftData predicate with array is tricky.
            // Better to verify existence one by one or fetch potentially existing batch.
            // Given delta sync should return small batches, one-by-one check might be okay,
            // OR fetch all local IDs first if dataset is huge?
            // "fetchUserPosts" returns ALL matching, but delta returns only modified.
            // Let's rely on simple check.
            
            let existingDescriptor = FetchDescriptor<Photo>() // Fetching all is inefficient for delta check...
            // Optimization: Only fetch items that match the IDs we downloaded?
            // Currently existing code fetches ALL photos. Let's optimize this too.
            // BUT predicate with array contains is not always supported well in SwiftData yet.
            // Let's stick to checking `downloadAndSave`'s insert/update logic.
            // For now, let's grab all local IDs to avoid N database fetches if we have many posts.
            // Wait, fetching ALL local IDs is still O(N).
            // Ideal Delta Sync means we blindly trust server "new" items?
            // Or we try to fetch by ID locally.
            
            // Re-using old approach but optimized:
            // Fetch all local items is NOT good if we have 1000 items. e.g.
            // Let's iterate and try to fetch individually or assume new?
            // Safest: Fetch all existing IDs (projection) if possible.
            // Since we can't project IDs easily without fetching objects in SwiftData models (yet),
            // Let's implement individual check inside `downloadAndSave` or `downloadAndSave` handles upsert.
            
            // Current `downloadAndSave` inserts blindly? Let's check it.
            // It creates `Photo(...)` then `modelContext.insert(photo)`.
            // If ID exists, SwiftData might crash or duplicate depending on configuration.
            // We need `upsert` logic.
            
            // For this step, let's keep it simple:
            // 1. We have [PostDTO].
            // 2. We iterate them.
            // 3. We check if we have it locally.
            
            // Optimization: fetching ALL IDs is lighter than fetching ALL DATA.
            // But let's defer detailed DB opt.
            // Important part is we only downloaded CHANGED items from network.
            
            var downloadedCount = 0
            
            // Check existence per remote post WITHOUT loading entire Photo objects
            // (Previous code fetched ALL Photos including imageData blobs into RAM)
            for dto in remotePosts {
                let dtoUUID = UUID(uuidString: dto.id) ?? UUID()
                let existsDescriptor = FetchDescriptor<Photo>(
                    predicate: #Predicate { $0.id == dtoUUID }
                )
                let existsCount = (try? modelContext.fetchCount(existsDescriptor)) ?? 0
                
                if existsCount == 0 {
                    await downloadAndSave(dto: dto)
                    downloadedCount += 1
                }
            }
            
            print("✅ Down Sync Complete - Processed \(remotePosts.count) items, Downloaded \(downloadedCount) new.")
            
            // Update lastSyncTime only on success
            if !remotePosts.isEmpty {
                 // Use the latest updated_at from the fetched batch
                 // Or just current time? Better to use server time effectively?
                 // Safest is to use Current Date of the execution - Buffer.
                 self.lastSyncTime = Date()
            } else if lastSyncTime == nil {
                // If full sync returned empty, set sync time so next time is delta
                self.lastSyncTime = Date()
            }
            
        } catch {
            print("❌ Down Sync Failed: \(error)")
        }
    }
    
    private func downloadAndSave(dto: PostDTO) async {
        print("⬇️ Downloading post: \(dto.id)")
        
        // CRITICAL: Skip posts that have no image_path - they are incomplete uploads
        guard let imagePath = dto.image_path, !imagePath.isEmpty else {
            print("   ⚠️ Skipped - no image_path (incomplete upload on server)")
            return
        }
        
        do {
            // 1. Download Image (Only for own posts)
            let isOwnPost = dto.owner_id == SupabaseManager.shared.currentUser?.id.uuidString
            var imageData: Data? = nil
            if isOwnPost {
                imageData = try? await SupabaseManager.shared.downloadFile(bucket: "photos", path: imagePath)
            }
            
            let photo = Photo(imageData: imageData)
            photo.remoteImagePath = imagePath
            photo.id = UUID(uuidString: dto.id) ?? UUID()
            photo.message = dto.message
            photo.createdAt = ISO8601DateFormatter().date(from: dto.created_at) ?? Date()
            photo.syncStatus = .synced // It's from server, so it's synced
            
            // Set offline cache info
            photo.ownerId = dto.owner_id
            photo.authorUsername = dto.profiles?.username
            photo.authorAvatarData = dto.profiles?.avatar_data
            
            // 2. Download Voice (Optional)
            if let voiceUrlStr = dto.voice_url, !voiceUrlStr.isEmpty {
                 var finalURL: URL? = URL(string: voiceUrlStr)
                 if !voiceUrlStr.starts(with: "http") {
                     finalURL = try? await SupabaseManager.shared.client.storage
                         .from("audios")
                         .createSignedURL(path: voiceUrlStr, expiresIn: 3600)
                 }
                 
                 if let url = finalURL {
                     if let (data, _) = try? await URLSession.shared.data(from: url) {
                         // Save to local file
                         let fileName = "voice_\(photo.id.uuidString).m4a"
                         let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                         let destinationURL = documentsPath.appendingPathComponent(fileName)
                         try? data.write(to: destinationURL)
                         
                         let duration = dto.voice_duration ?? 0
                         let voiceNote = VoiceNote(audioFileName: fileName, duration: duration)
                         photo.voiceNote = voiceNote
                         modelContext?.insert(voiceNote)
                     }
                 }
            }
            
            // 3. Download Live Photo Video (Optional)
            if let videoPath = dto.live_photo_path {
                 let videoData = try await SupabaseManager.shared.downloadFile(bucket: "photos", path: videoPath)
                 
                 let fileName = "livephoto_\(photo.id.uuidString).mov"
                 let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                 let destinationURL = documentsPath.appendingPathComponent(fileName)
                 try videoData.write(to: destinationURL)
                 
                 photo.livePhotoMoviePath = fileName
            }
            
            modelContext?.insert(photo)
            try modelContext?.save()
            print("✅ Saved remote post: \(photo.id)")
            
        } catch {
            print("❌ Failed to download post \(dto.id): \(error)")
        }
    }
    
    // MARK: - Download Post from Realtime Event
    func downloadAndSaveFromRealtime(dto: PostDTO) async {
        await downloadAndSave(dto: dto)
        
        // Notify UI about new post
        NotificationCenter.default.post(name: .newPostSaved, object: nil)
    }
    
    // MARK: - Chapter Sync Operations
    func syncChapters() async {
        await syncPendingChapters()
        await syncDownChapters()
    }
    
    // MARK: - Sync Pending Chapters (Upload)
    func syncPendingChapters() async {
        guard let modelContext = modelContext else { return }
        
        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        
        let descriptor = FetchDescriptor<Chapter>(
            predicate: #Predicate { $0.syncStatusRaw == pendingRaw || $0.syncStatusRaw == failedRaw }
        )
        
        guard let user = SupabaseManager.shared.currentUser else {
            print("❌ Chapter sync aborted: No authenticated user")
            return
        }
        
        do {
            let pendingChapters = try modelContext.fetch(descriptor)
            print("📤 Found \(pendingChapters.count) pending chapters to sync")
            
            for chapter in pendingChapters {
                await syncChapter(chapter, userId: user.id.uuidString)
            }
            
            try modelContext.save()
        } catch {
            print("❌ Chapter sync failed: \(error)")
        }
    }
    
    private func syncChapter(_ chapter: Chapter, userId: String) async {
        chapter.syncStatus = .syncing
        
        do {
            // 1. Upload cover image if exists
            var coverImagePath: String? = nil
            if let coverData = chapter.coverImageData {
                coverImagePath = try await SupabaseManager.shared.uploadImage(
                    data: coverData,
                    fileName: "chapter_cover_\(chapter.id.uuidString).jpg"
                )
            }
            
            // 2. Upsert chapter record
            let chapterData = ChapterDTO(
                id: chapter.id.uuidString,
                owner_id: userId,
                name: chapter.name,
                description_text: chapter.descriptionText,
                cover_image_path: coverImagePath,
                created_at: ISO8601DateFormatter().string(from: chapter.createdAt),
                updated_at: ISO8601DateFormatter().string(from: chapter.updatedAt)
            )
            
            try await SupabaseManager.shared.client
                .from("chapters")
                .upsert(chapterData)
                .execute()
            
            chapter.syncStatus = .synced
            print("✅ Synced chapter: \(chapter.name)")
            
        } catch {
            chapter.syncStatus = .failed
            print("❌ Failed to sync chapter \(chapter.name): \(error)")
        }
    }
    
    // MARK: - Sync Down Chapters (Download)
    func syncDownChapters() async {
        guard let modelContext = modelContext else { return }
        guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else { return }
        
        print("📥 Starting Chapter Down Sync...")
        
        do {
            // 1. Fetch remote chapters
            let remoteChapters: [ChapterDTO] = try await SupabaseManager.shared.client
                .from("chapters")
                .select()
                .eq("owner_id", value: userId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            print("📥 Found \(remoteChapters.count) remote chapters")
            
            // 2. Get existing local chapters
            let existingDescriptor = FetchDescriptor<Chapter>()
            let existingChapters = try modelContext.fetch(existingDescriptor)
            let existingIDs = Set(existingChapters.map { $0.id.uuidString.lowercased() })
            
            // 3. Insert new chapters
            var downloadedCount = 0
            for dto in remoteChapters {
                if !existingIDs.contains(dto.id.lowercased()) {
                    await downloadAndSaveChapter(dto: dto)
                    downloadedCount += 1
                }
            }
            
            print("✅ Chapter Down Sync Complete - Downloaded \(downloadedCount) new chapters")
            
        } catch {
            print("❌ Chapter Down Sync Failed: \(error)")
        }
    }
    
    private func downloadAndSaveChapter(dto: ChapterDTO) async {
        guard let modelContext = modelContext else { return }
        
        print("⬇️ Downloading chapter: \(dto.name)")
        
        do {
            let chapter = Chapter(name: dto.name, description: dto.description_text)
            chapter.id = UUID(uuidString: dto.id) ?? UUID()
            chapter.createdAt = ISO8601DateFormatter().date(from: dto.created_at) ?? Date()
            chapter.updatedAt = ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
            chapter.syncStatus = .synced
            
            // Download cover image if exists
            if let coverPath = dto.cover_image_path, !coverPath.isEmpty {
                let imageData = try await SupabaseManager.shared.downloadFile(bucket: "photos", path: coverPath)
                chapter.coverImageData = imageData
            }
            
            modelContext.insert(chapter)
            try modelContext.save()
            print("✅ Saved remote chapter: \(chapter.name)")
            
        } catch {
            print("❌ Failed to download chapter \(dto.name): \(error)")
        }
    }
    
    // MARK: - Delete Chapter (with sync)
    func deleteChapter(_ chapter: Chapter) async {
        guard let modelContext = modelContext else { return }
        
        // Delete from server first
        do {
            try await SupabaseManager.shared.client
                .from("chapters")
                .delete()
                .eq("id", value: chapter.id.uuidString)
                .execute()
            
            print("✅ Deleted chapter from server: \(chapter.name)")
        } catch {
            print("❌ Failed to delete chapter from server: \(error)")
        }
        
        // Delete locally
        modelContext.delete(chapter)
        try? modelContext.save()
    }
    
    // MARK: - Manual Trigger
    func forceSyncAll() async {
        await performFullSync()
    }
    
    // MARK: - Clear All Local Data (Sign Out)
    /// Deletes all local SwiftData objects and resets sync state.
    /// Call this when user signs out to prevent data leakage to next user.
    func clearAllLocalData() {
        guard let modelContext = modelContext else {
            print("⚠️ clearAllLocalData: No modelContext")
            return
        }
        
        do {
            // Delete all Photos
            let photos = try modelContext.fetch(FetchDescriptor<Photo>())
            for photo in photos {
                modelContext.delete(photo)
            }
            
            // Delete all VoiceNotes
            let voiceNotes = try modelContext.fetch(FetchDescriptor<VoiceNote>())
            for note in voiceNotes {
                modelContext.delete(note)
            }
            
            // Delete all Chapters
            let chapters = try modelContext.fetch(FetchDescriptor<Chapter>())
            for chapter in chapters {
                modelContext.delete(chapter)
            }
            
            try modelContext.save()
            
            // Reset sync timestamp
            lastSyncTime = nil
            
            // Clear downloaded voice/video files from Documents
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let files = (try? FileManager.default.contentsOfDirectory(atPath: documentsPath.path)) ?? []
            for file in files where file.hasPrefix("voice_") || file.hasPrefix("livephoto_") {
                try? FileManager.default.removeItem(at: documentsPath.appendingPathComponent(file))
            }
            
            print("🗑️ SyncManager: All local data cleared for sign out")
        } catch {
            print("❌ Failed to clear local data: \(error)")
        }
    }
}

