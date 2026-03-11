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
    private var messagesChannel: RealtimeChannelV2?
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
        
        // Subscribe to messages changes
        await subscribeToMessages(userId: userId)
        
        // Subscribe to friendship changes (accept/remove)
        await subscribeToFriendships(userId: userId)
        
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
    
    // MARK: - Subscribe to Messages
    private func subscribeToMessages(userId: String) async {
        let client = SupabaseManager.shared.client
        
        messagesChannel = client.realtimeV2.channel("direct_messages_\(userId)")
        
        // Supabase Realtime does NOT support compound or=() filters.
        // Subscribe without filter and check sender/receiver in handleMessageChange.
        let changes = messagesChannel!.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "direct_messages"
        )
        
        await messagesChannel!.subscribe()
        
        Task {
            for await change in changes {
                await handleMessageChange(change)
            }
        }
        
        print("✅ [Realtime] Subscribed to messages")
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
                
                NotificationCenter.default.post(name: .postInserted, object: dto)
                
            case .update(let action):
                let data = try JSONEncoder().encode(action.record)
                let dto = try JSONDecoder().decode(PostDTO.self, from: data)
                
                NotificationCenter.default.post(name: .postUpdated, object: dto)
                
            case .delete(let action):
                let oldRecord = action.oldRecord
                let data = try JSONEncoder().encode(oldRecord)
                struct DeletedRecord: Decodable { let id: String }
                let deleted = try JSONDecoder().decode(DeletedRecord.self, from: data)
                
                if let id = UUID(uuidString: deleted.id) {
                    await deletePostFromRemote(id: id)
                    
                    NotificationCenter.default.post(name: .postDeleted, object: id)
                }
            default:
                break
            }
        } catch {
            print("❌ [Realtime] Failed to decode post change: \(error)")
        }
        
        lastSyncTime = Date()
    }
    
    // MARK: - Handle Message Changes from Server
    private func handleMessageChange(_ change: AnyAction) async {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id.uuidString else { return }
        
        do {
            switch change {
            case .insert(let action):
                let data = try JSONEncoder().encode(action.record)
                let message = try JSONDecoder().decode(DirectMessage.self, from: data)
                
                // Only process messages that involve the current user
                guard message.sender_id.uuidString == currentUserId
                   || message.receiver_id.uuidString == currentUserId else {
                    return
                }
                
                print("📩 [Realtime] New message received: \(message.content)")
                
                NotificationCenter.default.post(name: .messageReceived, object: message)
            default:
                break
            }
        } catch {
            print("❌ [Realtime] Failed to decode message change: \(error)")
        }
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
    
    // MARK: - Subscribe to Friendships
    private var friendshipsChannel: RealtimeChannelV2?
    
    private func subscribeToFriendships(userId: String) async {
        let client = SupabaseManager.shared.client
        
        friendshipsChannel = client.realtimeV2.channel("friendships_\(userId)")
        
        // Supabase Realtime doesn't support compound or= filters.
        // Subscribe without filter and check in handler.
        let changes = friendshipsChannel!.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "friendships"
        )
        
        await friendshipsChannel!.subscribe()
        
        Task {
            for await change in changes {
                await handleFriendshipChange(change, userId: userId)
            }
        }
        
        print("✅ [Realtime] Subscribed to friendships")
    }
    
    // MARK: - Handle Friendship Changes
    private func handleFriendshipChange(_ change: AnyAction, userId: String) async {
        // Helper to process friendship record data
        func processFriendshipRecord(_ data: Data) throws {
            let friendship = try JSONDecoder().decode(Friendship.self, from: data)
            
            // Only process if this friendship involves the current user
            guard friendship.requester_id.uuidString == userId
               || friendship.addressee_id.uuidString == userId else {
                return
            }
            
            print("👥 [Realtime] Friendship change: \(friendship.status)")
            
            NotificationCenter.default.post(name: .friendListUpdated, object: nil)
        }
        
        do {
            switch change {
            case .insert(let action):
                let data = try JSONEncoder().encode(action.record)
                try processFriendshipRecord(data)
                
            case .update(let action):
                let data = try JSONEncoder().encode(action.record)
                try processFriendshipRecord(data)
                
            case .delete(_):
                // Friend removed — reload friend list
                NotificationCenter.default.post(name: .friendListUpdated, object: nil)
                
            default:
                break
            }
        } catch {
            print("❌ [Realtime] Failed to decode friendship change: \(error)")
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
        if let channel = messagesChannel {
            await channel.unsubscribe()
        }
        if let channel = friendshipsChannel {
            await channel.unsubscribe()
        }
        
        chaptersChannel = nil
        postsChannel = nil
        messagesChannel = nil
        friendshipsChannel = nil
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
