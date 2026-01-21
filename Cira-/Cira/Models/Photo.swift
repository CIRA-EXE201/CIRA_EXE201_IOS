//
//  Photo.swift
//  Cira
//
//  SwiftData model for Photo
//

import Foundation
import SwiftData

// MARK: - Sync Status
enum SyncStatus: String, Codable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
}

@Model
final class Photo {
    var id: UUID
    var createdAt: Date
    var imageData: Data?
    var thumbnailData: Data?
    var message: String?
    var livePhotoMoviePath: String?
    
    // Store as String for SwiftData compatibility
    var syncStatusRaw: String = SyncStatus.pending.rawValue
    
    @Relationship(deleteRule: .cascade)
    var voiceNote: VoiceNote?
    
    @Relationship(inverse: \Chapter.photos)
    var chapter: Chapter?
    
    // Computed property for enum access
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    // Computed properties
    var hasVoice: Bool {
        voiceNote != nil
    }
    
    var hasLivePhoto: Bool {
        livePhotoMoviePath != nil
    }
    
    var livePhotoMovieURL: URL? {
        guard let path = livePhotoMoviePath else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent(path)
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var isSynced: Bool {
        syncStatus == .synced
    }
    
    var needsSync: Bool {
        syncStatus == .pending || syncStatus == .failed
    }
    
    init(imageData: Data? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.imageData = imageData
        self.syncStatusRaw = SyncStatus.pending.rawValue
    }
}
