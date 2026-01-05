//
//  CardDimensions.swift
//  Cira
//
//  Shared card dimensions calculation for consistency across views
//

import SwiftUI

/// Helper to calculate card dimensions consistently across the app
struct CardDimensions {
    /// Space reserved for voice bar at bottom
    static let voiceBarSpace: CGFloat = 70
    
    /// Horizontal padding (total = 25pt, roughly 12.5pt each side)
    static let horizontalPadding: CGFloat = 25
    
    /// Vertical padding
    static let verticalPadding: CGFloat = 25
    
    /// Extra vertical padding for compact mode (camera preview, etc.)
    static let compactExtraPadding: CGFloat = 100
    
    /// Card corner radius
    static let cornerRadius: CGFloat = 24
    
    /// Calculate card size based on available geometry
    /// - Parameters:
    ///   - geometry: The GeometryProxy from GeometryReader
    ///   - includeVoiceBar: Whether to account for voice bar space (true for HomeView)
    ///   - compact: Whether to use compact mode (smaller card for camera preview state)
    /// - Returns: A tuple of (width, height)
    static func calculate(
        geometry: GeometryProxy,
        includeVoiceBar: Bool = true,
        compact: Bool = false
    ) -> (width: CGFloat, height: CGFloat) {
        let width = geometry.size.width - horizontalPadding
        var height = geometry.size.height - verticalPadding
        
        if includeVoiceBar {
            height -= voiceBarSpace
        }
        
        if compact {
            height -= compactExtraPadding
        }
        
        return (width, height)
    }
}
