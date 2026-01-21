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

// MARK: - Encodable Post Data
struct PostUploadData: Encodable {
    let id: String
    let owner_id: String
    // We send base64 for legacy support if needed, but prefer storage path
    // let image_data: String 
    let image_path: String?
    let live_photo_path: String?
    let message: String
    let voice_url: String
    let voice_duration: Double
    let created_at: String
}

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
    }
    
    // MARK: - Setup
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Network Monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                
                // Auto-sync when coming back online
                if wasOffline && path.status == .satisfied {
                    await self?.syncPendingPosts()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Sync Operations
    func syncPendingPosts() async {
        guard isOnline, !isSyncing, let modelContext = modelContext else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
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
            
            for photo in pendingPhotos {
                await syncPhoto(photo)
            }
            
            try modelContext.save()
            pendingCount = 0
        } catch {
            print("❌ Sync failed: \(error)")
        }
    }
    
    private func syncPhoto(_ photo: Photo) async {
        photo.syncStatus = .syncing
        
        do {
            // 1. Upload Voice Note (if exists)
            var voiceURL: String = ""
            if let voiceNote = photo.voiceNote,
               let audioURL = voiceNote.audioFileURL,
               let audioData = try? Data(contentsOf: audioURL) {
                voiceURL = try await SupabaseManager.shared.uploadAudio(
                    data: audioData,
                    fileName: "voice_\(photo.id.uuidString).m4a"
                )
            }
            
            // 2. Upload Live Photo Video (if exists)
            var livePhotoPath: String? = nil
            if let movieURL = photo.livePhotoMovieURL {
                livePhotoPath = try await SupabaseManager.shared.uploadVideo(
                    fileURL: movieURL,
                    fileName: "video_\(photo.id.uuidString).mov"
                )
            }
            
            // 3. Upload Image
            var imagePath: String? = nil
            if let imageData = photo.imageData {
                imagePath = try await SupabaseManager.shared.uploadImage(
                    data: imageData,
                    fileName: "image_\(photo.id.uuidString).jpg"
                )
            }
            
            // 4. Upsert Post Record
            let postData = PostUploadData(
                id: photo.id.uuidString,
                owner_id: SupabaseManager.shared.currentUser?.id.uuidString ?? "",
                image_path: imagePath,
                live_photo_path: livePhotoPath,
                message: photo.message ?? "",
                voice_url: voiceURL,
                voice_duration: photo.voiceNote?.duration ?? 0,
                created_at: ISO8601DateFormatter().string(from: photo.createdAt)
            )
            
            try await SupabaseManager.shared.client
                .from("posts")
                .upsert(postData)
                .execute()
            
            photo.syncStatus = .synced
            print("✅ Synced photo: \(photo.id)")
            
        } catch {
            photo.syncStatus = .failed
            print("❌ Failed to sync photo \(photo.id): \(error)")
        }
    }
    
    // MARK: - Manual Trigger
    func forceSyncAll() async {
        await syncPendingPosts()
    }
}

