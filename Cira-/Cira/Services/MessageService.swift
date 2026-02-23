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

@MainActor
final class MessageService {
    static let shared = MessageService()
    private init() {}
    
    // MARK: - Send Direct Message
    func sendMessage(to receiverId: UUID, postId: UUID?, content: String) async throws -> DirectMessage {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            throw FeedError.notAuthenticated
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
}
