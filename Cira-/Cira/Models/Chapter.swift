//
//  Chapter.swift
//  Cira
//
//  SwiftData model for Chapter (Story collection)
//

import Foundation
import SwiftData

@Model
final class Chapter {
    var id: UUID
    var name: String
    var descriptionText: String?
    var coverImageData: Data?
    var createdAt: Date
    var updatedAt: Date
    
    // Sync status
    var syncStatusRaw: String = SyncStatus.pending.rawValue
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .nullify)
    var photos: [Photo] = []
    
    // Computed properties
    var photoCount: Int {
        photos.count
    }
    
    var voiceCount: Int {
        photos.filter { $0.hasVoice }.count
    }
    
    var hasVoiceNotes: Bool {
        photos.contains { $0.voiceNote != nil }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
    
    init(name: String, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.descriptionText = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatusRaw = SyncStatus.pending.rawValue
    }
}
