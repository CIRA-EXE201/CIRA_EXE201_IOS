//
//  HomeViewModel.swift
//  Cira
//
//  ViewModel for Home Feed
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import Auth

// MARK: - Wall Category
enum WallCategory: String, CaseIterable {
    case family = "Family"
    case friends = "Friends"
    
    var icon: String {
        switch self {
        case .family: return "house.fill"
        case .friends: return "person.2.fill"
        }
    }
}

// MARK: - Friend Wall Model
struct FriendWall: Identifiable {
    let id: UUID
    let name: String
    let hasNewPost: Bool
    let category: WallCategory
    let avatarData: String?
    
    init(id: UUID, name: String, hasNewPost: Bool = false, category: WallCategory, avatarData: String? = nil) {
        self.id = id
        self.name = name
        self.hasNewPost = hasNewPost
        self.category = category
        self.avatarData = avatarData
    }
    
    // Mock data for fallback
    static let mockFamily: [FriendWall] = [
        FriendWall(id: UUID(), name: "Mom", hasNewPost: true, category: .family),
        FriendWall(id: UUID(), name: "Dad", hasNewPost: false, category: .family),
        FriendWall(id: UUID(), name: "Sister", hasNewPost: true, category: .family),
    ]
    
    static let mockFriends: [FriendWall] = [
        FriendWall(id: UUID(), name: "Lan", hasNewPost: true, category: .friends),
        FriendWall(id: UUID(), name: "Minh", hasNewPost: true, category: .friends),
        FriendWall(id: UUID(), name: "Ha", hasNewPost: false, category: .friends),
    ]
}

@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var posts: [Post] = [] {          // Local SwiftData posts (yours)
        didSet { rebuildCombinedPosts() }
    }
    @Published private(set) var feedPosts: [Post] = [] {      // Social feed from friends/family display items
        didSet { rebuildCombinedPosts() }
    }
    @Published private var rawFeedPosts: [FeedPost] = []    // Raw social feed from Supabase
    private var currentConversionIndex = 0                  // Pagination tracker for display items
    private var isConvertingPosts = false                   // Prevent concurrent lazy load fetches
    private var cachedLikedIds: Set<UUID> = []              // Cached liked post IDs (Issue #6 fix)
    @Published private(set) var isInitialLoading = true             // Track initial feed load
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var familyWalls: [FriendWall] = []
    @Published private(set) var friendWalls: [FriendWall] = []
    
    // Combined feed (local + social, sorted by date) — cached for performance
    @Published private(set) var combinedPosts: [Post] = []
    
    private func rebuildCombinedPosts() {
        var allPosts = posts + feedPosts
        var seenIDs = Set<UUID>()
        allPosts = allPosts.filter { post in
            if seenIDs.contains(post.id) { return false }
            seenIDs.insert(post.id)
            return true
        }
        combinedPosts = allPosts.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private var hasSetup = false
    
    // MARK: - Init
    init() {}
    
    // MARK: - Setup
    func setup(modelContext: ModelContext) {
        if hasSetup {
            Task {
                // Background refresh — don't block UI
                await refreshFeedInBackground()
            }
            return
        }
        hasSetup = true
        
        self.modelContext = modelContext
        
        // Configure SyncManager with model context
        SyncManager.shared.configure(modelContext: modelContext)
        
        // Configure RealtimeManager for real-time sync
        RealtimeManager.shared.configure(modelContext: modelContext)
        
        // DON'T load local posts yet — wait until friend posts are also ready
        // so combinedPosts is built ONCE with everything, not twice (local-only → local+friends)
        
        // Load cached social feed from disk (instant, no network)
        let cachedFeed = FeedService.shared.loadCachedFeed()
        if !cachedFeed.isEmpty {
            self.rawFeedPosts = cachedFeed
            self.currentConversionIndex = 0
            
            Task {
                // Convert first 3 cached friend posts
                await loadMoreSocialPosts(count: 3)
                
                // NOW load local posts — both local + friend posts build combinedPosts together
                loadLocalPosts()
                self.isInitialLoading = false
                
                // Background refresh from network
                await refreshFeedInBackground()
                
                // Start listening to realtime changes
                await RealtimeManager.shared.startListening()
            }
        } else {
            // No cache — first time user, fetch friend posts from network first
            Task {
                // Load friend posts FIRST (this is what the user sees immediately)
                await loadSocialFeed()
                
                // THEN load local posts — combinedPosts now has both
                loadLocalPosts()
                self.isInitialLoading = false
                
                await RealtimeManager.shared.startListening()
                
                // Sync local data with Supabase in background
                Task {
                    await SyncManager.shared.performFullSync()
                    self.loadLocalPosts()
                }
            }
        }
        
        // Listen to realtime updates via NotificationCenter
        NotificationCenter.default.publisher(for: .postUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let dto = notification.object as? PostDTO,
                      let postId = UUID(uuidString: dto.id) else { return }
                
                self.updatePostFromNetwork(id: postId, likeCount: dto.like_count ?? 0, commentCount: dto.comment_count ?? 0)
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .postDeleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self, let postId = notification.object as? UUID else { return }
                self.removePost(id: postId)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .newPostSaved)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadLocalPosts()
            }
            .store(in: &cancellables)
            
        // Listen for new post inserts (including friends' posts) — refresh feed silently
        NotificationCenter.default.publisher(for: .postInserted)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let dto = notification.object as? PostDTO else { return }
                
                Task {
                    await self.handleNewRealtimePost(dto: dto)
                }
            }
            .store(in: &cancellables)
        
        // Load friends and families from Supabase
        Task {
            await loadFriendsAndFamilies()
        }
        
        // When friendship changes (accepted/removed), reload feed automatically
        NotificationCenter.default.publisher(for: .friendListUpdated)
            .receive(on: RunLoop.main)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.loadFriendsAndFamilies()
                    await self?.loadSocialFeed()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        
        // Perform full sync (upload + download)
        await SyncManager.shared.performFullSync()
        
        // Reload local data
        loadLocalPosts()
        
        // Reload social feed
        await loadSocialFeed()
        
        // Reload friends/families
        await loadFriendsAndFamilies()
        
        isLoading = false
    }
    
    // MARK: - Load Local Posts from SwiftData
    func loadLocalPosts() {
        guard let modelContext = modelContext else {
            posts = []
            return
        }
        
        let photos = PostService.shared.fetchAllPosts(modelContext: modelContext)
        let allPosts: [Post] = photos.map { photo in
            PostService.shared.convertToPost(photo: photo)
        }
        
        // Remove duplicates by ID (keep first occurrence)
        var seenIDs = Set<UUID>()
        let uniquePosts = allPosts.filter { post in
            if seenIDs.contains(post.id) {
                return false
            }
            seenIDs.insert(post.id)
            return true
        }
        
        // Remove mock posts logic as per user request
        posts = uniquePosts
    }
    
    // MARK: - Load Social Feed from Friends/Family
    @MainActor
    func loadSocialFeed() async {
        do {
            // Fetch raw feed metadata from network
            let socialFeed = try await FeedService.shared.fetchSimpleFeed(limit: 50)
            
            self.rawFeedPosts = socialFeed
            self.feedPosts = []
            self.currentConversionIndex = 0
            
            // Fetch likedIds ONCE and cache (Issue #6 fix)
            if let likedIds = try? await LikeService.shared.fetchLikedPostIds() {
                self.cachedLikedIds = likedIds
            }
            
            // Rapidly convert just the first 3 items to show the UI instantly
            await loadMoreSocialPosts(count: 3)
            
            print("✅ Pre-loaded raw feed. Displaying first batch.")
        } catch {
            print("❌ Failed to load social feed: \(error)")
            self.errorMessage = "Failed to load feed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Background Refresh (Smart Merge)
    /// Fetches latest feed from network and merges with current display.
    /// Does NOT clear existing posts — only adds new ones and updates counts.
    @MainActor
    private func refreshFeedInBackground() async {
        do {
            let networkFeed = try await FeedService.shared.fetchSimpleFeed(limit: 50)
            
            // Fetch likedIds
            if let likedIds = try? await LikeService.shared.fetchLikedPostIds() {
                self.cachedLikedIds = likedIds
            }
            
            // Build set of network post IDs for quick lookup
            let networkIds = Set(networkFeed.map { $0.id })
            let existingIds = Set(rawFeedPosts.map { $0.id })
            
            // Find new posts (in network but not in current feed)
            let newPosts = networkFeed.filter { !existingIds.contains($0.id) }
            
            // Find removed posts (in current feed but not in network)
            let removedIds = existingIds.subtracting(networkIds)
            
            // Replace raw feed with network data
            self.rawFeedPosts = networkFeed
            
            // Remove deleted posts from display
            if !removedIds.isEmpty {
                self.feedPosts.removeAll { removedIds.contains($0.id) }
            }
            
            // Update like/comment counts for existing posts
            for feedPost in networkFeed {
                if let displayIndex = self.feedPosts.firstIndex(where: { $0.id == feedPost.id }) {
                    self.feedPosts[displayIndex].likeCount = feedPost.like_count ?? 0
                    self.feedPosts[displayIndex].commentCount = feedPost.comment_count ?? 0
                    self.feedPosts[displayIndex].isLiked = self.cachedLikedIds.contains(feedPost.id)
                }
            }
            
            // Convert and prepend new posts
            if !newPosts.isEmpty {
                var newDisplayPosts: [Post] = []
                for feedPost in newPosts {
                    var post = await FeedService.shared.convertToDisplayPost(feedPost: feedPost)
                    post.isLiked = cachedLikedIds.contains(post.id)
                    newDisplayPosts.append(post)
                }
                self.feedPosts.insert(contentsOf: newDisplayPosts, at: 0)
                
                // Prefetch images for new posts
                let newImageURLs = newDisplayPosts.compactMap { $0.photos.first?.imageURL }
                if !newImageURLs.isEmpty {
                    ImageCacheManager.shared.prefetch(urls: newImageURLs)
                }
            }
            
            // Update conversion index to match full raw feed
            self.currentConversionIndex = min(self.currentConversionIndex, self.feedPosts.count)
            
            // Sync local posts in background
            Task {
                await SyncManager.shared.performFullSync()
                self.loadLocalPosts()
            }
            
            print("✅ Background refresh complete: \(newPosts.count) new, \(removedIds.count) removed")
        } catch {
            print("❌ Background refresh failed: \(error)")
        }
    }
    
    // MARK: - Lazy Loading Social Posts
    @MainActor
    func loadMoreSocialPosts(count: Int) async {
        guard !isConvertingPosts else { return }
        
        let startIndex = currentConversionIndex
        let endIndex = min(startIndex + count, rawFeedPosts.count)
        
        guard startIndex < endIndex else { return } // No more posts to convert
        
        isConvertingPosts = true
        let sliceToConvert = rawFeedPosts[startIndex..<endIndex]
        
        // Convert incrementally (request Signed URLs)
        var newDisplayPosts: [Post] = []
        for feedPost in sliceToConvert {
            let post = await FeedService.shared.convertToDisplayPost(feedPost: feedPost)
            newDisplayPosts.append(post)
        }
        
        // Apply cached likedIds (fetched once in loadSocialFeed)
        if !cachedLikedIds.isEmpty {
            newDisplayPosts = newDisplayPosts.map { post in
                var p = post
                p.isLiked = cachedLikedIds.contains(p.id)
                return p
            }
        }
        
        self.feedPosts.append(contentsOf: newDisplayPosts)
        self.currentConversionIndex = endIndex
        self.isConvertingPosts = false
        
        // Prefetch image data into cache so images display instantly when scrolled to
        let imageURLs = newDisplayPosts.compactMap { post -> URL? in
            post.photos.first?.imageURL
        }
        if !imageURLs.isEmpty {
            ImageCacheManager.shared.prefetch(urls: imageURLs)
        }
    }
    
    // Trigger from view when scrolling
    @MainActor
    func loadMoreIfNeeded(currentPost: Post) {
        guard !isConvertingPosts else { return }
        
        // Check if we are near the bottom of visible posts (3 away from end for more prefetch runway)
        let combined = self.combinedPosts
        if let index = combined.firstIndex(where: { $0.id == currentPost.id }) {
            if index >= combined.count - 3 {
                // User is near the bottom, load the next 3 posts
                Task {
                    await loadMoreSocialPosts(count: 3)
                }
            }
        }
    }
    
    // Backward compatibility - loadPosts calls both
    func loadPosts() {
        loadLocalPosts()
        Task {
            await loadSocialFeed()
        }
    }
    
    // MARK: - Load Friends & Families from Supabase
    func loadFriendsAndFamilies() async {
        // Load Friends
        do {
            let friends = try await FriendService.shared.getFriends()
            friendWalls = friends.map { profile in
                FriendWall(
                    id: profile.id,
                    name: profile.username ?? "Friend",
                    hasNewPost: false,
                    category: .friends,
                    avatarData: profile.avatar_data
                )
            }
            print("✅ Loaded \(friendWalls.count) friends from Supabase")
        } catch {
            print("❌ Failed to load friends: \(error)")
            // Don't fallback to mock - keep empty or current list
        }
        
        // Load Family Members from all families
        do {
            let families = try await FamilyService.shared.getMyFamilies()
            print("✅ Found \(families.count) families")
            
            var allFamilyMembers: [FriendWall] = []
            
            for family in families {
                let members = try await FamilyService.shared.getFamilyMembers(familyId: family.id)
                let walls = members.map { member in
                    FriendWall(
                        id: member.user_id,
                        name: member.username ?? "Member",
                        hasNewPost: false,
                        category: .family,
                        avatarData: member.avatar_data
                    )
                }
                allFamilyMembers.append(contentsOf: walls)
            }
            
            // Remove duplicates (same user in multiple families)
            var seen = Set<UUID>()
            familyWalls = allFamilyMembers.filter { wall in
                if seen.contains(wall.id) { return false }
                seen.insert(wall.id)
                return true
            }
            print("✅ Loaded \(familyWalls.count) family members from Supabase")
        } catch {
            print("❌ Failed to load families: \(error)")
            // Don't fallback to mock - keep empty or current list
        }
    }
    
    func loadMore() async {
        // TODO: Implement pagination
    }
    
    func toggleLike(for postId: UUID) {
        // Find in local posts
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].isLiked.toggle()
            posts[index].likeCount += posts[index].isLiked ? 1 : -1
        }
        
        // Find in feed posts
        if let index = feedPosts.firstIndex(where: { $0.id == postId }) {
            feedPosts[index].isLiked.toggle()
            feedPosts[index].likeCount += feedPosts[index].isLiked ? 1 : -1
        }
    }
    
    // MARK: - Handlers for Realtime Events
    private func updatePostFromNetwork(id: UUID, likeCount: Int, commentCount: Int) {
        // Update in posts
        if let index = posts.firstIndex(where: { $0.id == id }) {
            posts[index].likeCount = likeCount
            posts[index].commentCount = commentCount
        }
        
        // Update in feedPosts
        if let index = feedPosts.firstIndex(where: { $0.id == id }) {
            feedPosts[index].likeCount = likeCount
            feedPosts[index].commentCount = commentCount
        }
    }
    
    private func removePost(id: UUID) {
        posts.removeAll(where: { $0.id == id })
        feedPosts.removeAll(where: { $0.id == id })
        rawFeedPosts.removeAll(where: { $0.id == id })
        // Decrement conversion index if we removed a post that was already converted
        if currentConversionIndex > 0 {
            currentConversionIndex -= 1
        }
    }
    
    @MainActor
    private func handleNewRealtimePost(dto: PostDTO) async {
        // Skip if it is our own post, local DB already has it
        if dto.owner_id == SupabaseManager.shared.currentUser?.id.uuidString { return }
        
        // Prevent duplicate append if it somehow already exists
        guard let uuid = UUID(uuidString: dto.id), !rawFeedPosts.contains(where: { $0.id == uuid }) else { return }
        
        // Create raw feed post structure
        var profileUsername: String?
        var profileAvatar: String?
        
        // Fetch author info to build FeedPost (single lookup instead of fetching all friends)
        if let authorId = UUID(uuidString: dto.owner_id) {
            if let profile = try? await FriendService.shared.getUserProfile(userId: authorId) {
                profileUsername = profile.username
                profileAvatar = profile.avatar_data
            }
        }
        
        let rawPost = FeedPost(
            id: uuid,
            owner_id: UUID(uuidString: dto.owner_id) ?? UUID(),
            image_path: dto.image_path,
            live_photo_path: dto.live_photo_path,
            message: dto.message,
            voice_url: dto.voice_url,
            voice_duration: dto.voice_duration,
            visibility: dto.visibility ?? "friends",
            created_at: dto.created_at ?? "",
            updated_at: dto.updated_at,
            like_count: dto.like_count,
            comment_count: dto.comment_count,
            is_liked: false,
            author_username: profileUsername,
            author_avatar_data: profileAvatar
        )
        
        // 1. Insert into raw feeds
        rawFeedPosts.insert(rawPost, at: 0)
        currentConversionIndex += 1
        
        // 2. Convert and instantly display at the top
        let displayPost = await FeedService.shared.convertToDisplayPost(feedPost: rawPost)
        feedPosts.insert(displayPost, at: 0)
    }
}
