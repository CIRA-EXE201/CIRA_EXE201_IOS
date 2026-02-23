import Foundation
import Supabase

@MainActor
final class LikeService {
    static let shared = LikeService()
    private init() {}
    
    // MARK: - Like/Unlike Post
    func toggleLike(for postId: UUID) async throws {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            throw FeedError.notAuthenticated
        }
        
        let isLiked = try await isPostLiked(postId)
        if isLiked {
            // Unlike
            try await SupabaseManager.shared.client
                .from("post_likes")
                .delete()
                .eq("post_id", value: postId)
                .eq("user_id", value: currentUserId)
                .execute()
        } else {
            // Like
            struct LikeInsert: Encodable { let post_id: UUID; let user_id: UUID }
            try await SupabaseManager.shared.client
                .from("post_likes")
                .insert(LikeInsert(post_id: postId, user_id: currentUserId))
                .execute()
        }
    }
    
    // MARK: - Check if Post is Liked
    func isPostLiked(_ postId: UUID) async throws -> Bool {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            return false
        }
        
        struct LikeSelect: Decodable {}
        let likes: [LikeSelect] = try await SupabaseManager.shared.client
            .from("post_likes")
            .select()
            .eq("post_id", value: postId)
            .eq("user_id", value: currentUserId)
            .execute()
            .value
            
        return !likes.isEmpty
    }
    
    /// Batched method to get all liked post IDs (useful for feed loading)
    func fetchLikedPostIds() async throws -> Set<UUID> {
        guard let currentUserId = SupabaseManager.shared.currentUser?.id else {
            return []
        }
        
        struct LikedPostId: Decodable { let post_id: UUID }
        let likes: [LikedPostId] = try await SupabaseManager.shared.client
            .from("post_likes")
            .select("post_id")
            .eq("user_id", value: currentUserId)
            .execute()
            .value
            
        return Set(likes.map { $0.post_id })
    }
}
