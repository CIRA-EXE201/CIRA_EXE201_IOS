//
//  WidgetPost.swift
//  Cira
//
//  Lightweight Codable model shared between main app and widget extension.
//  Does NOT depend on SwiftData — safe for Widget Extension target.
//

import Foundation

/// Represents a post for display in the home screen widget.
/// This must be added to BOTH the main app target AND the widget extension target.
struct WidgetPost: Codable, Identifiable {
    let id: UUID
    let authorUsername: String
    let message: String?        // caption text
    let hasVoice: Bool          // show play button if true
    let createdAt: Date
    
    /// Filename for the cached thumbnail in the shared App Group container.
    /// Format: "\(id.uuidString).jpg"
    var thumbnailFilename: String {
        "\(id.uuidString).jpg"
    }
}
