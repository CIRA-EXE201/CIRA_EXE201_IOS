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

// MARK: - Friend Wall Model
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

struct FriendWall: Identifiable {
    let id: UUID
    let name: String
    let hasNewPost: Bool
    let category: WallCategory
    
    static let mockFamily: [FriendWall] = [
        FriendWall(id: UUID(), name: "Mom", hasNewPost: true, category: .family),
        FriendWall(id: UUID(), name: "Dad", hasNewPost: false, category: .family),
        FriendWall(id: UUID(), name: "Sister", hasNewPost: true, category: .family),
        FriendWall(id: UUID(), name: "Grandpa", hasNewPost: false, category: .family),
    ]
    
    static let mockFriends: [FriendWall] = [
        FriendWall(id: UUID(), name: "Lan", hasNewPost: true, category: .friends),
        FriendWall(id: UUID(), name: "Minh", hasNewPost: true, category: .friends),
        FriendWall(id: UUID(), name: "Ha", hasNewPost: false, category: .friends),
        FriendWall(id: UUID(), name: "Tuan", hasNewPost: true, category: .friends),
        FriendWall(id: UUID(), name: "Mai", hasNewPost: false, category: .friends),
        FriendWall(id: UUID(), name: "Dung", hasNewPost: false, category: .friends),
        FriendWall(id: UUID(), name: "Linh", hasNewPost: true, category: .friends),
    ]
}

@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var familyWalls: [FriendWall] = FriendWall.mockFamily
    @Published private(set) var friendWalls: [FriendWall] = FriendWall.mockFriends
    
    private var modelContext: ModelContext?
    
    // MARK: - Init
    init() {}
    
    // MARK: - Setup
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPosts()
    }
    
    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        loadPosts()
        isLoading = false
    }
    
    func loadPosts() {
        guard let modelContext = modelContext else {
            // Fallback to mock data if no context
            posts = Post.mockPosts
            return
        }
        
        // Fetch photos from SwiftData
        let photos = PostService.shared.fetchPosts(modelContext: modelContext)
        
        // Convert to Posts
        let allPosts: [Post] = photos.map { photo in
            PostService.shared.convertToPost(photo: photo)
        }
        
        // Add mock posts at the end for demo
        // allPosts.append(contentsOf: Post.mockPosts)
        
        posts = allPosts
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
