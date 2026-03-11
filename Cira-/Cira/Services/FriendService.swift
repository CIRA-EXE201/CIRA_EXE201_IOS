//
//  FriendService.swift
//  Cira
//
//  Service for managing friendships
//

import Foundation
import Supabase

// MARK: - Models
struct Friendship: Codable, Identifiable {
    let id: UUID
    let requester_id: UUID
    let addressee_id: UUID
    let status: String
    let created_at: String?
}

struct FriendProfile: Codable, Identifiable {
    let id: UUID
    let username: String?
    let avatar_data: String?
}

struct PendingFriendRequest: Identifiable {
    var id: UUID { friendshipId }
    let friendshipId: UUID
    let profile: FriendProfile
}


// MARK: - FriendService
@MainActor
final class FriendService {
    static let shared = FriendService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private var currentUserId: UUID? {
        SupabaseManager.shared.currentUser?.id
    }
    
    // MARK: - Send Friend Request
    func sendFriendRequest(to userId: UUID) async throws {
        guard let myId = currentUserId else {
            throw FriendError.notAuthenticated
        }
        
        let data: [String: String] = [
            "requester_id": myId.uuidString,
            "addressee_id": userId.uuidString,
            "status": "pending"
        ]
        
        try await client
            .from("friendships")
            .insert(data)
            .execute()
    }
    
    // MARK: - Receive Friend Request (from deep link)
    func receiveFriendRequest(from requesterId: UUID) async throws {
        guard let myId = currentUserId else {
            throw FriendError.notAuthenticated
        }
        
        // Ensure we don't add ourselves
        guard myId != requesterId else { return }
        
        let data: [String: String] = [
            "requester_id": requesterId.uuidString,
            "addressee_id": myId.uuidString,
            "status": "pending"
        ]
        
        try await client
            .from("friendships")
            .insert(data)
            .execute()
    }
    
    // MARK: - Accept Friend Request
    func acceptFriendRequest(_ friendshipId: UUID) async throws {
        try await client
            .from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }
    
    // MARK: - Block User
    func blockUser(_ friendshipId: UUID) async throws {
        try await client
            .from("friendships")
            .update(["status": "blocked"])
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }
    
    // MARK: - Remove Friend / Cancel Request
    func removeFriend(_ friendshipId: UUID) async throws {
        try await client
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }
    
    // MARK: - Get Friends List (accepted only)
    func getFriends() async throws -> [FriendProfile] {
        guard let myId = currentUserId else {
            throw FriendError.notAuthenticated
        }
        
        // Get all accepted friendships where I'm either requester or addressee
        let friendships: [Friendship] = try await client
            .from("friendships")
            .select("id, requester_id, addressee_id, status")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(myId.uuidString),addressee_id.eq.\(myId.uuidString)")
            .execute()
            .value
        
        // Extract friend IDs (the other person in each friendship)
        let friendIds = friendships.map { friendship in
            friendship.requester_id == myId ? friendship.addressee_id : friendship.requester_id
        }
        
        guard !friendIds.isEmpty else { return [] }
        
        // Fetch friend profiles
        let profiles: [FriendProfile] = try await client
            .from("profiles")
            .select("id, username, avatar_data")
            .in("id", values: friendIds.map { $0.uuidString })
            .execute()
            .value
        
        return profiles
    }
    
    // MARK: - Get Pending Requests (received)
    func getPendingRequests() async throws -> [Friendship] {
        guard let myId = currentUserId else {
            throw FriendError.notAuthenticated
        }
        
        let requests: [Friendship] = try await client
            .from("friendships")
            .select("id, requester_id, addressee_id, status")
            .eq("addressee_id", value: myId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return requests
    }
    
    // MARK: - Get Pending Requests with Profiles
    func getPendingFriendRequestsWithProfiles() async throws -> [PendingFriendRequest] {
        let friendships = try await getPendingRequests()
        guard !friendships.isEmpty else { return [] }
        
        // Batch fetch all requester profiles in a single query (fixes N+1)
        let requesterIds = friendships.map { $0.requester_id.uuidString }
        let profiles: [FriendProfile] = try await client
            .from("profiles")
            .select("id, username, avatar_data")
            .in("id", values: requesterIds)
            .execute()
            .value
        
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        
        return friendships.compactMap { friendship in
            guard let profile = profileMap[friendship.requester_id] else { return nil }
            return PendingFriendRequest(friendshipId: friendship.id, profile: profile)
        }
    }
    
    // MARK: - Search Users by Username
    func searchUsers(query: String) async throws -> [FriendProfile] {
        guard !query.isEmpty else { return [] }
        
        let profiles: [FriendProfile] = try await client
            .from("profiles")
            .select("id, username, avatar_data")
            .ilike("username", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value
        
        // Filter out current user
        return profiles.filter { $0.id != currentUserId }
    }
    
    // MARK: - Get User Profile by ID
    func getUserProfile(userId: UUID) async throws -> FriendProfile {
        let profile: FriendProfile = try await client
            .from("profiles")
            .select("id, username, avatar_data")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        return profile
    }
}

// MARK: - Errors
enum FriendError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to manage friends."
        }
    }
}
