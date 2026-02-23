//
//  RealtimeManager.swift
//  Cira
//
//  Supabase Realtime Manager for real-time sync via WebSocket
//  Handles bidirectional sync for chapters and posts
//

import Foundation
import SwiftData
import Supabase
import Realtime
import Combine

// MARK: - Realtime Event Types
enum RealtimeEventType: String {
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
}

// MARK: - Realtime Manager
@MainActor
final class RealtimeManager: ObservableObject {
    static let shared = RealtimeManager()
    
    @Published private(set) var isConnected = false
    @Published private(set) var lastSyncTime: Date?
    
    private var modelContext: ModelContext?
    private var chaptersChannel: RealtimeChannelV2?
    private var postsChannel: RealtimeChannelV2?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Setup
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Subscribe to Realtime Changes
    func startListening() async {
        guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
            print("❌ [Realtime] Cannot subscribe: No authenticated user")
            return
        }
        
        print("🔌 [Realtime] Starting realtime subscriptions for user: \(userId)")
        
        // Subscribe to chapters changes
        await subscribeToChapters(userId: userId)
        
        // Subscribe to posts changes
        await subscribeToPosts(userId: userId)
        
        isConnected = true
    }
    
    // MARK: - Subscribe to Chapters
    private func subscribeToChapters(userId: String) async {
        let client = SupabaseManager.shared.client
        
        chaptersChannel = client.realtimeV2.channel("chapters_\(userId)")
        
        let changes = chaptersChannel!.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "chapters",
            filter: "owner_id=eq.\(userId)"
        )
        
        await chaptersChannel!.subscribe()
        
        Task {
            for await change in changes {
                await handleChapterChange(change)
            }
        }
        
        print("✅ [Realtime] Subscribed to chapters")
    }
    
    // MARK: - Subscribe to Posts
    private func subscribeToPosts(userId: String) async {
        let client = SupabaseManager.shared.client
        
        postsChannel = client.realtimeV2.channel("public_posts")
        
        let changes = postsChannel!.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "posts"
            // No filter, so we receive updates for all posts in the feed
        )
        
        await postsChannel!.subscribe()
        
        Task {
            for await change in changes {
                await handlePostChange(change)
            }
        }
        
        print("✅ [Realtime] Subscribed to posts")
    }
    
    // MARK: - Handle Chapter Changes from Server
    private func handleChapterChange(_ change: AnyAction) async {
        guard let modelContext = modelContext else { return }
        
        print("📥 [Realtime] Chapter change received: \(change)")
        
        do {
            switch change {
            case .insert(let action):
                let data = try JSONEncoder().encode(action.record)
                let dto = try JSONDecoder().decode(ChapterDTO.self, from: data)
                await insertChapterFromRemote(dto: dto)
                
            case .update(let action):
                let data = try JSONEncoder().encode(action.record)
                let dto = try JSONDecoder().decode(ChapterDTO.self, from: data)
                await updateChapterFromRemote(dto: dto)
                
            case .delete(let action):
                let oldRecord = action.oldRecord
                let data = try JSONEncoder().encode(oldRecord)
                struct DeletedRecord: Decodable { let id: String }
                let deleted = try JSONDecoder().decode(DeletedRecord.self, from: data)
                
                if let id = UUID(uuidString: deleted.id) {
                    await deleteChapterFromRemote(id: id)
                }
            default:
                break
            }
        } catch {
            print("❌ [Realtime] Failed to decode chapter change: \(error)")
        }
        
        lastSyncTime = Date()
    }
    
    // MARK: - Handle Post Changes from Server
    private func handlePostChange(_ change: AnyAction) async {
        guard let modelContext = modelContext else { return }
        
        do {
            switch change {
            case .insert(let action):
                let data = try JSONEncoder().encode(action.record)
                let dto = try JSONDecoder().decode(PostDTO.self, from: data)
                
                if dto.owner_id == SupabaseManager.shared.currentUser?.id.uuidString {
                    await SyncManager.shared.downloadAndSaveFromRealtime(dto: dto)
                }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .postInserted, object: dto)
                }
                
            case .update(let action):
                let data = try JSONEncoder().encode(action.record)
                let dto = try JSONDecoder().decode(PostDTO.self, from: data)
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .postUpdated, object: dto)
                }
                
            case .delete(let action):
                let oldRecord = action.oldRecord
                let data = try JSONEncoder().encode(oldRecord)
                struct DeletedRecord: Decodable { let id: String }
                let deleted = try JSONDecoder().decode(DeletedRecord.self, from: data)
                
                if let id = UUID(uuidString: deleted.id) {
                    await deletePostFromRemote(id: id)
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .postDeleted, object: id)
                    }
                }
            default:
                break
            }
        } catch {
            print("❌ [Realtime] Failed to decode post change: \(error)")
        }
        
        lastSyncTime = Date()
    }
    
    // MARK: - Insert Chapter from Remote
    private func insertChapterFromRemote(dto: ChapterDTO) async {
        guard let modelContext = modelContext else { return }
        guard let id = UUID(uuidString: dto.id) else { return }
        
        // Check if already exists locally
        let descriptor = FetchDescriptor<Chapter>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let existing = try modelContext.fetch(descriptor)
            if !existing.isEmpty {
                print("   ↳ Chapter already exists locally, skipping insert")
                return
            }
            
            // Create new chapter
            let chapter = Chapter(name: dto.name, description: dto.description_text)
            chapter.id = id
            chapter.createdAt = ISO8601DateFormatter().date(from: dto.created_at) ?? Date()
            chapter.updatedAt = ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
            chapter.syncStatus = .synced
            
            // Download cover image if exists
            if let coverPath = dto.cover_image_path, !coverPath.isEmpty {
                do {
                    let imageData = try await SupabaseManager.shared.downloadFile(bucket: "photos", path: coverPath)
                    chapter.coverImageData = imageData
                } catch {
                    print("   ⚠️ Failed to download cover image: \(error)")
                }
            }
            
            modelContext.insert(chapter)
            try modelContext.save()
            
            print("✅ [Realtime] Inserted chapter from remote: \(dto.name)")
            
            // Notify UI
            NotificationCenter.default.post(name: .chapterSyncCompleted, object: nil)
            
        } catch {
            print("❌ [Realtime] Failed to insert chapter: \(error)")
        }
    }
    
    // MARK: - Update Chapter from Remote
    private func updateChapterFromRemote(dto: ChapterDTO) async {
        guard let modelContext = modelContext else { return }
        guard let id = UUID(uuidString: dto.id) else { return }
        
        let descriptor = FetchDescriptor<Chapter>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let chapters = try modelContext.fetch(descriptor)
            guard let chapter = chapters.first else {
                // Doesn't exist locally, insert it
                await insertChapterFromRemote(dto: dto)
                return
            }
            
            // Update local chapter
            let remoteUpdatedAt = ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
            
            // Only update if remote is newer
            if remoteUpdatedAt > chapter.updatedAt {
                chapter.name = dto.name
                chapter.descriptionText = dto.description_text
                chapter.updatedAt = remoteUpdatedAt
                chapter.syncStatus = .synced
                
                try modelContext.save()
                print("✅ [Realtime] Updated chapter from remote: \(dto.name)")
                
                NotificationCenter.default.post(name: .chapterSyncCompleted, object: nil)
            } else {
                print("   ↳ Local chapter is newer, skipping update")
            }
            
        } catch {
            print("❌ [Realtime] Failed to update chapter: \(error)")
        }
    }
    
    // MARK: - Delete Chapter from Remote
    private func deleteChapterFromRemote(id: UUID) async {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<Chapter>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let chapters = try modelContext.fetch(descriptor)
            if let chapter = chapters.first {
                modelContext.delete(chapter)
                try modelContext.save()
                print("✅ [Realtime] Deleted chapter from remote: \(id)")
                
                NotificationCenter.default.post(name: .chapterSyncCompleted, object: nil)
            }
        } catch {
            print("❌ [Realtime] Failed to delete chapter: \(error)")
        }
    }
    
    // MARK: - Delete Post from Remote
    private func deletePostFromRemote(id: UUID) async {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let photos = try modelContext.fetch(descriptor)
            if let photo = photos.first {
                modelContext.delete(photo)
                try modelContext.save()
                print("✅ [Realtime] Deleted post from remote: \(id)")
                
                NotificationCenter.default.post(name: .newPostSaved, object: nil)
            }
        } catch {
            print("❌ [Realtime] Failed to delete post: \(error)")
        }
    }
    
    // MARK: - Stop Listening
    func stopListening() async {
        if let channel = chaptersChannel {
            await channel.unsubscribe()
        }
        if let channel = postsChannel {
            await channel.unsubscribe()
        }
        
        chaptersChannel = nil
        postsChannel = nil
        isConnected = false
        
        print("🔌 [Realtime] Disconnected from realtime")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let chapterSyncCompleted = Notification.Name("chapterSyncCompleted")
    static let postInserted = Notification.Name("postInserted")
    static let postUpdated = Notification.Name("postUpdated")
    static let postDeleted = Notification.Name("postDeleted")
}
