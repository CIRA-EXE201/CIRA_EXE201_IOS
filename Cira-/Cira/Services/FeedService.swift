//
//  FeedService.swift
//  Cira
//
//  Service for fetching social feed (posts from friends and family)
//

import Foundation
import Supabase
import WidgetKit
import UIKit

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
    
    init(id: UUID, owner_id: UUID, image_path: String? = nil, live_photo_path: String? = nil, message: String? = nil, voice_url: String? = nil, voice_duration: Double? = nil, visibility: String, created_at: String, updated_at: String? = nil, like_count: Int? = 0, comment_count: Int? = 0, is_liked: Bool? = false, author_username: String? = nil, author_avatar_data: String? = nil) {
        self.id = id
        self.owner_id = owner_id
        self.image_path = image_path
        self.live_photo_path = live_photo_path
        self.message = message
        self.voice_url = voice_url
        self.voice_duration = voice_duration
        self.visibility = visibility
        self.created_at = created_at
        self.updated_at = updated_at
        self.like_count = like_count
        self.comment_count = comment_count
        self.is_liked = is_liked
        self.author_username = author_username
        self.author_avatar_data = author_avatar_data
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
    
    // Local cache (in-memory)
    private var cachedFeed: [FeedPost] = []
    private var lastFetchDate: Date?
    
    // Signed URL cache with TTL (50 minutes, URLs expire at 60)
    private var signedURLCache: [String: (url: URL, expiresAt: Date)] = [:]
    private let signedURLTTL: TimeInterval = 50 * 60 // 50 minutes
    
    // MARK: - Load from Disk Cache (Instant)
    /// Returns cached feed from local JSON file. Zero network calls.
    func loadCachedFeed() -> [FeedPost] {
        let cached = FeedCache.shared.load()
        if !cached.isEmpty {
            cachedFeed = cached
        }
        return cached
    }
    
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
        
        // Load blocked users
        let blockedIds = try await ReportService.shared.getBlockedUserIds()
        
        // RLS will automatically filter based on visibility and relationships
        var posts: [FeedPost] = try await client
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
        
        // Filter out blocked users
        if !blockedIds.isEmpty {
            posts = posts.filter { !blockedIds.contains($0.owner_id) }
        }
        
        cachedFeed = posts
        lastFetchDate = Date()
        
        // Persist to disk for next app launch
        FeedCache.shared.save(posts)
        
        // Update widget data for home screen widget
        Task.detached(priority: .utility) {
            await Self.updateWidgetData(from: posts)
        }
        
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
    
    // MARK: - Clear Cache
    /// Clears in-memory feed data. Call on sign out.
    func clearCache() {
        cachedFeed = []
        lastFetchDate = nil
        signedURLCache = [:]
    }
    
    // MARK: - Convert to Display Post
    func convertToDisplayPost(feedPost: FeedPost) async -> Post {
        var voiceItem: Post.VoiceItem? = nil
        
        if let voiceURL = feedPost.voice_url, !voiceURL.isEmpty, let duration = feedPost.voice_duration, duration > 0 {
            var finalVoiceURL: URL? = nil
            
            if voiceURL.starts(with: "http") {
                // Already a full URL
                finalVoiceURL = URL(string: voiceURL)
            } else {
                // Relative storage path — need signed URL
                // Check signed URL cache first
                if let cached = signedURLCache[voiceURL], cached.expiresAt > Date() {
                    finalVoiceURL = cached.url
                } else {
                    if let signedURL = try? await SupabaseManager.shared.client.storage
                        .from("audios")
                        .createSignedURL(path: voiceURL, expiresIn: 3600) {
                        finalVoiceURL = signedURL
                        signedURLCache[voiceURL] = (url: signedURL, expiresAt: Date().addingTimeInterval(signedURLTTL))
                    } else {
                        print("⚠️ Could not create signed URL for voice: \(voiceURL)")
                    }
                }
            }
            
            if finalVoiceURL != nil {
                voiceItem = Post.VoiceItem(
                    duration: duration,
                    audioURL: finalVoiceURL,
                    waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7]
                )
            }
        }
        
        // Pre-generate signed image URL so PostCardView has it immediately
        var signedImageURL: URL? = nil
        if let imagePath = feedPost.image_path, !imagePath.isEmpty {
            // Check signed URL cache first
            if let cached = signedURLCache[imagePath], cached.expiresAt > Date() {
                signedImageURL = cached.url
            } else {
                if let url = try? await SupabaseManager.shared.client.storage
                    .from("photos")
                    .createSignedURL(path: imagePath, expiresIn: 3600) {
                    signedImageURL = url
                    signedURLCache[imagePath] = (url: url, expiresAt: Date().addingTimeInterval(signedURLTTL))
                }
            }
        }
        
        let photoItem = Post.PhotoItem(
            id: feedPost.id,
            imageURL: signedImageURL, // Pre-signed URL ready for immediate use
            imageData: nil,
            remoteImagePath: feedPost.image_path,
            livePhotoMoviePath: feedPost.live_photo_path,
            voiceNote: voiceItem
        )
        
        // Determine author display name
        let isOwnPost = feedPost.owner_id == currentUserId
        let authorName = isOwnPost ? "Me" : (feedPost.author_username ?? "Unknown")
        
        let createdDate = DateFormatters.parseISO8601(feedPost.created_at) ?? Date()
        
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
    
    // MARK: - Widget Data Orchestration
    
    /// Converts FeedPosts to WidgetPosts, caches thumbnails, and triggers widget refresh.
    /// This runs on a detached task after each feed refresh.
    private static func updateWidgetData(from feedPosts: [FeedPost]) async {
        let maxPosts = 5
        let topPosts = Array(feedPosts.prefix(maxPosts))
        
        var widgetPosts: [WidgetPost] = []
        
        for feedPost in topPosts {
            let widgetPost = WidgetPost(
                id: feedPost.id,
                authorUsername: feedPost.author_username ?? "Friend",
                message: feedPost.message,
                hasVoice: feedPost.voice_url != nil && !(feedPost.voice_url?.isEmpty ?? true),
                createdAt: DateFormatters.parseISO8601(feedPost.created_at) ?? Date()
            )
            widgetPosts.append(widgetPost)
            
            // Download and cache thumbnail
            if let imagePath = feedPost.image_path, !imagePath.isEmpty {
                await cacheWidgetImage(storagePath: imagePath, postId: feedPost.id)
            }
        }
        
        WidgetDataProvider.shared.savePosts(widgetPosts)
        
        // Refresh widget timeline
        await MainActor.run {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    /// Downloads image from Supabase and saves as a JPEG thumbnail for the widget.
    private static func cacheWidgetImage(storagePath: String, postId: UUID) async {
        // Skip if already cached
        guard !WidgetDataProvider.shared.hasImage(postId: postId) else { return }
        
        do {
            let data = try await SupabaseManager.shared.client.storage
                .from("photos")
                .download(path: storagePath)
            
            // Downscale to widget size (2x retina for small widget ≈ 310×310px)
            if let original = UIImage(data: data) {
                let maxDimension: CGFloat = 400
                let size = original.size
                let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
                let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let thumbnail = renderer.image { _ in
                    original.draw(in: CGRect(origin: .zero, size: newSize))
                }
                
                if let jpegData = thumbnail.jpegData(compressionQuality: 0.7) {
                    WidgetDataProvider.shared.saveImage(jpegData, postId: postId)
                }
            }
        } catch {
            print("⚠️ Widget: Failed to cache image for \(postId): \(error)")
        }
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
