//
//  FamilyService.swift
//  Cira
//
//  Service for managing family groups
//

import Foundation
import Supabase

// MARK: - Models
struct Family: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let cover_data: String?
    let owner_id: UUID
    let invite_code: String?
    let is_active: Bool?
    let created_at: String?
}

struct FamilyMembership: Codable {
    let family_id: UUID
    let user_id: UUID
    let role: String
    let joined_at: String?
}

struct FamilyMemberProfile: Codable, Identifiable {
    var id: UUID { user_id }
    let user_id: UUID
    let role: String
    let username: String?
    let avatar_data: String?
}

// MARK: - FamilyService
@MainActor
final class FamilyService {
    static let shared = FamilyService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private var currentUserId: UUID? {
        SupabaseManager.shared.currentUser?.id
    }
    
    // MARK: - Create Family
    func createFamily(name: String, description: String? = nil) async throws -> Family {
        guard let myId = currentUserId else {
            throw FamilyError.notAuthenticated
        }
        
        struct CreateData: Encodable {
            let name: String
            let description: String?
            let owner_id: String
        }
        
        let data = CreateData(
            name: name,
            description: description,
            owner_id: myId.uuidString
        )
        
        let family: Family = try await client
            .from("families")
            .insert(data)
            .select()
            .single()
            .execute()
            .value
        
        // Auto-add creator as admin member
        try await addMember(familyId: family.id, userId: myId, role: "admin")
        
        return family
    }
    
    // MARK: - Join Family (by invite code)
    func joinFamily(inviteCode: String) async throws -> Family {
        guard let myId = currentUserId else {
            throw FamilyError.notAuthenticated
        }
        
        // Find family by invite code
        let family: Family = try await client
            .from("families")
            .select()
            .eq("invite_code", value: inviteCode)
            .eq("is_active", value: true)
            .single()
            .execute()
            .value
        
        // Add self as member
        try await addMember(familyId: family.id, userId: myId, role: "member")
        
        return family
    }
    
    // MARK: - Add Member (internal)
    private func addMember(familyId: UUID, userId: UUID, role: String) async throws {
        struct MemberData: Encodable {
            let family_id: String
            let user_id: String
            let role: String
        }
        
        let data = MemberData(
            family_id: familyId.uuidString,
            user_id: userId.uuidString,
            role: role
        )
        
        try await client
            .from("family_members")
            .insert(data)
            .execute()
    }
    
    // MARK: - Leave Family
    func leaveFamily(familyId: UUID) async throws {
        guard let myId = currentUserId else {
            throw FamilyError.notAuthenticated
        }
        
        try await client
            .from("family_members")
            .delete()
            .eq("family_id", value: familyId.uuidString)
            .eq("user_id", value: myId.uuidString)
            .execute()
    }
    
    // MARK: - Get My Families
    func getMyFamilies() async throws -> [Family] {
        guard let myId = currentUserId else {
            throw FamilyError.notAuthenticated
        }
        
        // Get family IDs where I'm a member
        let memberships: [FamilyMembership] = try await client
            .from("family_members")
            .select()
            .eq("user_id", value: myId.uuidString)
            .execute()
            .value
        
        let familyIds = memberships.map { $0.family_id.uuidString }
        
        guard !familyIds.isEmpty else { return [] }
        
        // Fetch family details
        let families: [Family] = try await client
            .from("families")
            .select()
            .in("id", values: familyIds)
            .eq("is_active", value: true)
            .execute()
            .value
        
        return families
    }
    
    // MARK: - Get Family Members
    func getFamilyMembers(familyId: UUID) async throws -> [FamilyMemberProfile] {
        // Get memberships
        let memberships: [FamilyMembership] = try await client
            .from("family_members")
            .select()
            .eq("family_id", value: familyId.uuidString)
            .execute()
            .value
        
        let userIds = memberships.map { $0.user_id.uuidString }
        
        guard !userIds.isEmpty else { return [] }
        
        // Fetch profiles
        let profiles: [FriendProfile] = try await client
            .from("profiles")
            .select("id, username, avatar_data")
            .in("id", values: userIds)
            .execute()
            .value
        
        // Combine membership role with profile
        return memberships.compactMap { member in
            guard let profile = profiles.first(where: { $0.id == member.user_id }) else { return nil }
            return FamilyMemberProfile(
                user_id: member.user_id,
                role: member.role,
                username: profile.username,
                avatar_data: profile.avatar_data
            )
        }
    }
    
    // MARK: - Update Family
    func updateFamily(id: UUID, name: String?, description: String?) async throws {
        var updates: [String: String] = [:]
        if let name = name { updates["name"] = name }
        if let description = description { updates["description"] = description }
        
        guard !updates.isEmpty else { return }
        
        try await client
            .from("families")
            .update(updates)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Delete Family (soft delete)
    func deleteFamily(id: UUID) async throws {
        try await client
            .from("families")
            .update(["is_active": false])
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Errors
enum FamilyError: LocalizedError {
    case notAuthenticated
    case familyNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to manage families."
        case .familyNotFound:
            return "Family not found or invalid invite code."
        }
    }
}
