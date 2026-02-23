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
    var like_count: Int?
    var comment_count: Int?
    var is_liked: Bool?
    
    // Author info from join
    var author_username: String?
    var author_avatar_data: String?
    
    enum CodingKeys: String, CodingKey {
        case id, owner_id, image_path, live_photo_path, message, voice_url, voice_duration, visibility, created_at, updated_at
        case author_username, author_avatar_data
        case profiles
        case like_count, comment_count, is_liked
    }
    
    struct ProfileData: Codable {
        let username: String?
        let avatar_data: String?
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        owner_id = try container.decode(UUID.self, forKey: .owner_id)
        image_path = try container.decodeIfPresent(String.self, forKey: .image_path)
        live_photo_path = try container.decodeIfPresent(String.self, forKey: .live_photo_path)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        voice_url = try container.decodeIfPresent(String.self, forKey: .voice_url)
        voice_duration = try container.decodeIfPresent(Double.self, forKey: .voice_duration)
        visibility = try container.decode(String.self, forKey: .visibility)
        created_at = try container.decode(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        
        if let profiles = try container.decodeIfPresent(ProfileData.self, forKey: .profiles) {
            author_username = profiles.username
            author_avatar_data = profiles.avatar_data
        } else {
            author_username = try container.decodeIfPresent(String.self, forKey: .author_username)
            author_avatar_data = try container.decodeIfPresent(String.self, forKey: .author_avatar_data)
        }
        
        like_count = try container.decodeIfPresent(Int.self, forKey: .like_count)
        comment_count = try container.decodeIfPresent(Int.self, forKey: .comment_count)
        is_liked = try container.decodeIfPresent(Bool.self, forKey: .is_liked)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(owner_id, forKey: .owner_id)
        try container.encodeIfPresent(image_path, forKey: .image_path)
        try container.encodeIfPresent(live_photo_path, forKey: .live_photo_path)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(voice_url, forKey: .voice_url)
        try container.encodeIfPresent(voice_duration, forKey: .voice_duration)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(author_username, forKey: .author_username)
        try container.encodeIfPresent(author_avatar_data, forKey: .author_avatar_data)
        try container.encodeIfPresent(like_count, forKey: .like_count)
        try container.encodeIfPresent(comment_count, forKey: .comment_count)
        try container.encodeIfPresent(is_liked, forKey: .is_liked)
        // We don't encode `profiles` because it's a derived/input-only field
    }
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
                like_count,
                comment_count,
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
        
        var publicImageURL: URL?
        if let imagePath = feedPost.image_path {
            publicImageURL = try? SupabaseManager.shared.client.storage
                .from("photos")
                .getPublicURL(path: imagePath)
        }
        
        let photoItem = Post.PhotoItem(
            id: feedPost.id,
            imageURL: publicImageURL,
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
            likeCount: feedPost.like_count ?? 0,
            commentCount: feedPost.comment_count ?? 0,
            isLiked: feedPost.is_liked ?? false,
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
