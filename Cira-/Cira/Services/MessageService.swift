import Foundation
import Supabase

struct DirectMessage: Codable, Identifiable {
    let id: UUID
    let sender_id: UUID
    let receiver_id: UUID
    let post_id: UUID?
    let content: String
    let created_at: String
}

struct MessageProfile: Codable {
    let id: UUID
    let username: String?
    let avatar_data: String?
}

struct Conversation: Identifiable {
    let id: UUID // The other user's ID
    let otherUserName: String
    let otherUserAvatarData: String?
    let lastMessage: String
    let lastMessageDate: Date
    var unreadCount: Int = 0
}

@MainActor
final class MessageService {
    static let shared = MessageService()
    private init() {}
    
    // MARK: - Send Direct Message
    func sendMessage(to receiverId: UUID, postId: UUID?, content: String) async throws -> DirectMessage {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            struct TemporaryFeedError: Error {}
            throw TemporaryFeedError()
        }
        
        struct MessageInsert: Encodable {
            let sender_id: UUID
            let receiver_id: UUID
            let post_id: UUID?
            let content: String
        }
        
        let insertData = MessageInsert(
            sender_id: currentUserId,
            receiver_id: receiverId,
            post_id: postId,
            content: content
        )
        
        let newMessage: DirectMessage = try await SupabaseManager.shared.client
            .from("direct_messages")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
            
        return newMessage
    }
    
    // MARK: - Fetch Conversations
    func fetchConversations() async throws -> [Conversation] {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            return []
        }
        
        let messages: [DirectMessage] = try await SupabaseManager.shared.client
            .from("direct_messages")
            .select()
            .or("sender_id.eq.\(currentUserId.uuidString),receiver_id.eq.\(currentUserId.uuidString)")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
            
        var grouped: [UUID: DirectMessage] = [:]
        for msg in messages {
            let otherId = (msg.sender_id == currentUserId) ? msg.receiver_id : msg.sender_id
            if grouped[otherId] == nil {
                grouped[otherId] = msg
            }
        }
        
        let otherUserIds = Array(grouped.keys)
        if otherUserIds.isEmpty { return [] }
        
        // Fetch profiles one by one to avoid complex `.in()` syntax issues
        var profileDict: [UUID: MessageProfile] = [:]
        for id in otherUserIds {
            if let p: MessageProfile = try? await SupabaseManager.shared.client
                .from("profiles")
                .select("id, username, avatar_data")
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value {
                profileDict[id] = p
            }
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let backupFormatter = ISO8601DateFormatter()
        
        var conversations: [Conversation] = []
        for (otherId, msg) in grouped {
            let p = profileDict[otherId]
            let date = formatter.date(from: msg.created_at) ?? backupFormatter.date(from: msg.created_at) ?? Date()
            
            conversations.append(Conversation(
                id: otherId,
                otherUserName: p?.username ?? "Unknown",
                otherUserAvatarData: p?.avatar_data,
                lastMessage: msg.content,
                lastMessageDate: date,
                unreadCount: 0
            ))
        }
        
        return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
    
    // MARK: - Fetch Messages for Conversation
    func fetchMessages(with otherUserId: UUID) async throws -> [DirectMessage] {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            return []
        }
        
        let messages: [DirectMessage] = try await SupabaseManager.shared.client
            .from("direct_messages")
            .select()
            .or("and(sender_id.eq.\(currentUserId.uuidString),receiver_id.eq.\(otherUserId.uuidString)),and(sender_id.eq.\(otherUserId.uuidString),receiver_id.eq.\(currentUserId.uuidString))")
            .order("created_at", ascending: true)
            .limit(100)
            .execute()
            .value
            
        return messages
    }
}
