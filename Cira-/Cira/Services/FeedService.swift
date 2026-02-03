//
//  FeedService.swift
//  Cira
//
//  Service for fetching social feed (posts from friends and family)
//

import Foundation
import Supabase

// MARK: - Feed Post Model
struct FeedPost: Codable, Identifiable {
    let id: UUID
    let owner_id: UUID
    let image_path: String?
    let live_photo_path: String?
    let message: String?
    let voice_url: String?
    let voice_duration: Double?
    let visibility: String
    let created_at: String
    let updated_at: String?
    
    // Author info from join
    let author_username: String?
    let author_avatar_data: String?
}

// MARK: - FeedService
@MainActor
final class FeedService {
    static let shared = FeedService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private var currentUserId: UUID? {
        SupabaseManager.shared.currentUser?.id
    }
    
    // Local cache
    private var cachedFeed: [FeedPost] = []
    private var lastFetchDate: Date?
    
    // MARK: - Fetch Social Feed
    /// Fetches posts from friends, family, and self
    /// Uses RLS policies to automatically filter based on relationships
    func fetchFeed(limit: Int = 50, offset: Int = 0) async throws -> [FeedPost] {
        guard currentUserId != nil else {
            throw FeedError.notAuthenticated
        }
        
        // The RLS policies will automatically filter:
        // - Own posts (any visibility)
        // - Friend posts (visibility = friends/public)
        // - Family posts (visibility = family/public)
        // - Public posts (visibility = public)
        
        let query = """
        SELECT 
            posts.*,
            profiles.username as author_username,
            profiles.avatar_data as author_avatar_data
        FROM posts
        LEFT JOIN profiles ON posts.owner_id = profiles.id
        WHERE posts.is_active = true
        ORDER BY posts.created_at DESC
        LIMIT \(limit) OFFSET \(offset)
        """
        
        let posts: [FeedPost] = try await client
            .rpc("fetch_social_feed", params: ["p_limit": limit, "p_offset": offset])
            .execute()
            .value
        
        // Update cache
        if offset == 0 {
            cachedFeed = posts
        } else {
            cachedFeed.append(contentsOf: posts)
        }
        lastFetchDate = Date()
        
        return posts
    }
    
    // MARK: - Simple Feed (Without RPC)
    /// Alternative method using direct query - RLS handles filtering
    func fetchSimpleFeed(limit: Int = 50) async throws -> [FeedPost] {
        guard currentUserId != nil else {
            throw FeedError.notAuthenticated
        }
        
        // RLS will automatically filter based on visibility and relationships
        let posts: [FeedPost] = try await client
            .from("posts")
            .select("""
                id,
                owner_id,
                image_path,
                live_photo_path,
                message,
                voice_url,
                voice_duration,
                visibility,
                created_at,
                updated_at,
                profiles!posts_owner_id_fkey(username, avatar_data)
            """)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        cachedFeed = posts
        lastFetchDate = Date()
        
        return posts
    }
    
    // MARK: - Get Cached Feed
    func getCachedFeed() -> [FeedPost] {
        return cachedFeed
    }
    
    // MARK: - Refresh Feed
    func refreshFeed() async throws {
        _ = try await fetchSimpleFeed()
    }
    
    // MARK: - Convert to Display Post
    func convertToDisplayPost(feedPost: FeedPost) -> Post {
        var voiceItem: Post.VoiceItem? = nil
        
        if let voiceURL = feedPost.voice_url, let duration = feedPost.voice_duration {
            voiceItem = Post.VoiceItem(
                duration: duration,
                audioURL: URL(string: voiceURL),
                waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7]
            )
        }
        
        let photoItem = Post.PhotoItem(
            id: feedPost.id,
            imageURL: nil, // Will load from storage
            imageData: nil,
            livePhotoMoviePath: feedPost.live_photo_path,
            voiceNote: voiceItem
        )
        
        // Determine author display name
        let isOwnPost = feedPost.owner_id == currentUserId
        let authorName = isOwnPost ? "Me" : (feedPost.author_username ?? "Unknown")
        
        // Parse date
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: feedPost.created_at) ?? Date()
        
        return Post(
            id: feedPost.id,
            type: .single,
            photos: [photoItem],
            author: Post.Author(
                id: feedPost.owner_id,
                username: authorName,
                avatarURL: nil // Will handle avatar separately
            ),
            createdAt: createdDate,
            likeCount: 0, // TODO: Add like system
            commentCount: 0,
            isLiked: false,
            message: feedPost.message
        )
    }
}

// MARK: - Errors
enum FeedError: LocalizedError {
    case notAuthenticated
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to view feed."
        case .fetchFailed:
            return "Failed to fetch feed. Please try again."
        }
    }
}
