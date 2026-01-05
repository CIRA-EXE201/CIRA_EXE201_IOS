//
//  VoiceNote.swift
//  Cira
//
//  SwiftData model for VoiceNote
//

import Foundation
import SwiftData

@Model
final class VoiceNote {
    var id: UUID
    var duration: TimeInterval
    var audioFileName: String
    var createdAt: Date
    var waveformData: [Float]?
    
    var photo: Photo?
    
    // Computed properties
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var audioFileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent(audioFileName)
    }
    
    init(audioFileName: String, duration: TimeInterval) {
        self.id = UUID()
        self.audioFileName = audioFileName
        self.duration = duration
        self.createdAt = Date()
    }
}
