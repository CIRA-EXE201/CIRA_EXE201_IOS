//
//  Photo.swift
//  Cira
//
//  SwiftData model for Photo
//

import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID
    var createdAt: Date
    var imageData: Data?
    var thumbnailData: Data?
    var message: String?
    var livePhotoMoviePath: String?
    
    @Relationship(deleteRule: .cascade)
    var voiceNote: VoiceNote?
    
    @Relationship(inverse: \Chapter.photos)
    var chapter: Chapter?
    
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
    
    init(imageData: Data? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.imageData = imageData
    }
}
