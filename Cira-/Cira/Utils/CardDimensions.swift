//
//  CardDimensions.swift
//  Cira
//
//  Shared card dimensions calculation for consistency across views
//

import SwiftUI

/// Helper to calculate card dimensions consistently across the app
struct CardDimensions {
    
    // MARK: - Constants
    static let horizontalPadding: CGFloat = 32 // 16pt each side
    static let cornerRadius: CGFloat = 40
    
    // Layout Constants matching CameraView
    static let topSpace: CGFloat = 8
    static let controlsHeight: CGFloat = 80 // Reduced slighly from 90 to fit better
    static let extraBottomSpacing: CGFloat = 110 // Reduced from 130 to increase card height
    
    // MARK: - Calculation
    static func calculateMainCardSize(screenSize: CGSize, safeArea: EdgeInsets) -> CGSize {
        // Redesign: Return full screen size for immersive experience
        return screenSize
    }
    
    static func topSpacing(safeArea: EdgeInsets) -> CGFloat {
        let topBarPadding = safeArea.top > 0 ? safeArea.top : 44 // Removed +10
        let topBarHeight: CGFloat = 44
        return topBarPadding + topBarHeight + topSpace
    }
}
