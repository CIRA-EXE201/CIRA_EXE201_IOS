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
            posts = Post.mockPosts
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
        
        posts = uniquePosts
    }
    
    // MARK: - Load Social Feed from Friends/Family
    func loadSocialFeed() async {
        do {
            let socialFeed = try await FeedService.shared.fetchSimpleFeed(limit: 50)
            
            // Convert FeedPost to Post for display
            let displayPosts = socialFeed.map { feedPost in
                FeedService.shared.convertToDisplayPost(feedPost: feedPost)
            }
            
            feedPosts = displayPosts
            print("✅ Loaded \(feedPosts.count) posts from social feed")
        } catch {
            print("❌ Failed to load social feed: \(error)")
            errorMessage = "Failed to load feed: \(error.localizedDescription)"
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
    
    func likePost(_ post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likeCount += posts[index].isLiked ? 1 : -1
    }
}
