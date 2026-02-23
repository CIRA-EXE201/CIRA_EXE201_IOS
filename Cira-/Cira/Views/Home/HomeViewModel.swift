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
    @Published private(set) var posts: [Post] = []          // Local SwiftData posts (yours)
    @Published private(set) var feedPosts: [Post] = []      // Social feed from friends/family
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var familyWalls: [FriendWall] = []
    @Published private(set) var friendWalls: [FriendWall] = []
    
    // Combined feed (local + social, sorted by date)
    var combinedPosts: [Post] {
        // Merge local posts with social feed posts
        var allPosts = posts + feedPosts
        
        // Remove duplicates (keep first occurrence by ID)
        var seenIDs = Set<UUID>()
        allPosts = allPosts.filter { post in
            if seenIDs.contains(post.id) { return false }
            seenIDs.insert(post.id)
            return true
        }
        
        // Sort by date (newest first)
        return allPosts.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init() {}
    
    // MARK: - Setup
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Configure SyncManager with model context
        SyncManager.shared.configure(modelContext: modelContext)
        
        // Configure RealtimeManager for real-time sync
        RealtimeManager.shared.configure(modelContext: modelContext)
        
        // Load local posts first (instant)
        loadLocalPosts()
        
        // Then load everything from network
        Task {
            // Sync local data with Supabase
            await SyncManager.shared.performFullSync()
            
            // Reload local data after sync
            loadLocalPosts()
            
            // Load social feed from friends/family
            await loadSocialFeed()
            
            // Start listening to realtime changes
            await RealtimeManager.shared.startListening()
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
        
        // Load friends and families from Supabase
        Task {
            await loadFriendsAndFamilies()
        }
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
        
        let photos = PostService.shared.fetchPosts(modelContext: modelContext)
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
            let socialFeed = try await FeedService.shared.fetchSimpleFeed(limit: 50)
            
            // Convert FeedPost to Post for display
            var displayPosts = socialFeed.map { feedPost in
                FeedService.shared.convertToDisplayPost(feedPost: feedPost)
            }
            
            // Try to set isLiked correctly using fetchLikedPostIds
            if let likedIds = try? await LikeService.shared.fetchLikedPostIds() {
                displayPosts = displayPosts.map { post in
                    var p = post
                    p.isLiked = likedIds.contains(p.id)
                    return p
                }
                
                // Also update local `posts` since they might have been loaded earlier as false
                self.posts = self.posts.map { post in
                    var p = post
                    p.isLiked = likedIds.contains(p.id)
                    return p
                }
            }
            
            self.feedPosts = displayPosts
            print("✅ Loaded \(feedPosts.count) posts from social feed")
        } catch {
            print("❌ Failed to load social feed: \(error)")
            self.errorMessage = "Failed to load feed: \(error.localizedDescription)"
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
    }
}
