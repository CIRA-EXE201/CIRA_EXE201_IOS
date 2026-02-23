import Foundation
import Supabase

// MARK: - Comment Model
struct PostComment: Codable, Identifiable {
    let id: UUID
    let post_id: UUID
    let user_id: UUID
    let content: String
    let created_at: String
    
    // Author info from join
    var author_username: String?
    var author_avatar_data: String?
    
    enum CodingKeys: String, CodingKey {
        case id, post_id, user_id, content, created_at
        case author_username, author_avatar_data
        case profiles
    }
    
    struct ProfileData: Codable {
        let username: String?
        let avatar_data: String?
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        post_id = try container.decode(UUID.self, forKey: .post_id)
        user_id = try container.decode(UUID.self, forKey: .user_id)
        content = try container.decode(String.self, forKey: .content)
        created_at = try container.decode(String.self, forKey: .created_at)
        
        if let profiles = try container.decodeIfPresent(ProfileData.self, forKey: .profiles) {
            author_username = profiles.username
            author_avatar_data = profiles.avatar_data
        } else {
            author_username = try container.decodeIfPresent(String.self, forKey: .author_username)
            author_avatar_data = try container.decodeIfPresent(String.self, forKey: .author_avatar_data)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(post_id, forKey: .post_id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(content, forKey: .content)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(author_username, forKey: .author_username)
        try container.encodeIfPresent(author_avatar_data, forKey: .author_avatar_data)
        // Note: profiles is derived from joined data and not encoded
    }
}

@MainActor
final class CommentService {
    static let shared = CommentService()
    private init() {}
    
    // MARK: - Fetch Comments for Post
    func fetchComments(for postId: UUID, limit: Int = 20) async throws -> [PostComment] {
        guard SupabaseManager.shared.currentUser != nil else {
            throw FeedError.notAuthenticated
        }
        
        let comments: [PostComment] = try await SupabaseManager.shared.client
            .from("post_comments")
            .select("""
                *,
                profiles!post_comments_user_id_fkey(username, avatar_data)
            """)
            .eq("post_id", value: postId)
            .order("created_at", ascending: true) // oldest first typical for comments
            .limit(limit)
            .execute()
            .value
            
        return comments
    }
    
    // MARK: - Add Comment
    func addComment(to postId: UUID, content: String) async throws -> PostComment {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            throw FeedError.notAuthenticated
        }
        
        struct CommentInsert: Encodable {
            let post_id: UUID
            let user_id: UUID
            let content: String
        }
        
        let newComment: PostComment = try await SupabaseManager.shared.client
            .from("post_comments")
            .insert(CommentInsert(post_id: postId, user_id: currentUserId, content: content))
            .select("""
                *,
                profiles!post_comments_user_id_fkey(username, avatar_data)
            """)
            .single()
            .execute()
            .value
            
        return newComment
    }
    
    // MARK: - Delete Comment
    func deleteComment(_ commentId: UUID) async throws {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            throw FeedError.notAuthenticated
        }
        
        try await SupabaseManager.shared.client
            .from("post_comments")
            .delete()
            .eq("id", value: commentId)
            .eq("user_id", value: currentUserId) // Ensure only owner can delete
            .execute()
    }
}
