//
//  ReportService.swift
//  Cira
//
//  Service for reporting content and blocking users (App Store compliance)
//

import Foundation
import Supabase

// MARK: - Report Reason
enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "spam"
    case harassment = "harassment"
    case inappropriate = "inappropriate"
    case violence = "violence"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .spam: return "Spam / Quảng cáo"
        case .harassment: return "Quấy rối"
        case .inappropriate: return "Nội dung không phù hợp"
        case .violence: return "Bạo lực"
        case .other: return "Khác"
        }
    }
    
    var icon: String {
        switch self {
        case .spam: return "exclamationmark.bubble"
        case .harassment: return "hand.raised"
        case .inappropriate: return "eye.slash"
        case .violence: return "bolt.shield"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Report DTO
private struct ReportInsert: Encodable {
    let reporter_id: String
    let reported_user_id: String
    let post_id: String?
    let reason: String
    let details: String?
}

// MARK: - Block DTO
private struct BlockInsert: Encodable {
    let blocker_id: String
    let blocked_id: String
}

// MARK: - Blocked User Response
private struct BlockedUserRow: Decodable {
    let blocked_id: UUID
}

// MARK: - ReportService
@MainActor
final class ReportService {
    static let shared = ReportService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private var currentUserId: String? {
        SupabaseManager.shared.currentUser?.id.uuidString
    }
    
    // Cached blocked user IDs
    private var blockedUserIds: Set<UUID> = []
    private var hasLoadedBlocks = false
    
    // MARK: - Report Content
    func reportContent(
        postId: UUID?,
        reportedUserId: UUID,
        reason: ReportReason,
        details: String? = nil
    ) async throws {
        guard let userId = currentUserId else {
            throw ReportError.notAuthenticated
        }
        
        let report = ReportInsert(
            reporter_id: userId,
            reported_user_id: reportedUserId.uuidString,
            post_id: postId?.uuidString,
            reason: reason.rawValue,
            details: details
        )
        
        try await client
            .from("reports")
            .insert(report)
            .execute()
    }
    
    // MARK: - Block User
    func blockUser(userId: UUID) async throws {
        guard let currentId = currentUserId else {
            throw ReportError.notAuthenticated
        }
        
        let block = BlockInsert(
            blocker_id: currentId,
            blocked_id: userId.uuidString
        )
        
        try await client
            .from("blocked_users")
            .insert(block)
            .execute()
        
        // Update local cache
        blockedUserIds.insert(userId)
    }
    
    // MARK: - Unblock User
    func unblockUser(userId: UUID) async throws {
        guard let currentId = currentUserId else {
            throw ReportError.notAuthenticated
        }
        
        try await client
            .from("blocked_users")
            .delete()
            .eq("blocker_id", value: currentId)
            .eq("blocked_id", value: userId.uuidString)
            .execute()
        
        // Update local cache
        blockedUserIds.remove(userId)
    }
    
    // MARK: - Get Blocked User IDs
    func getBlockedUserIds() async throws -> Set<UUID> {
        guard let currentId = currentUserId else {
            return []
        }
        
        let rows: [BlockedUserRow] = try await client
            .from("blocked_users")
            .select("blocked_id")
            .eq("blocker_id", value: currentId)
            .execute()
            .value
        
        blockedUserIds = Set(rows.map(\.blocked_id))
        hasLoadedBlocks = true
        return blockedUserIds
    }
    
    // MARK: - Check if Blocked (uses cache)
    func isBlocked(userId: UUID) -> Bool {
        blockedUserIds.contains(userId)
    }
    
    // MARK: - Ensure blocks are loaded
    func ensureBlocksLoaded() async {
        guard !hasLoadedBlocks else { return }
        _ = try? await getBlockedUserIds()
    }
    
    // MARK: - Clear cache (on sign out)
    func clearCache() {
        blockedUserIds.removeAll()
        hasLoadedBlocks = false
    }
}

// MARK: - Errors
enum ReportError: LocalizedError {
    case notAuthenticated
    case alreadyReported
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Bạn cần đăng nhập để thực hiện thao tác này."
        case .alreadyReported:
            return "Bạn đã báo cáo nội dung này rồi."
        }
    }
}
