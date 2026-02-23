//
//  CardDimensions.swift
//  Cira
//

import SwiftUI

struct CardDimensions {
    // MARK: - Constants
    static let cornerRadius: CGFloat = 36
    static let navbarHeight: CGFloat = 60
    static let tabbarHeight: CGFloat = 100
    static let interactionHeight: CGFloat = 110
    static let standardGap: CGFloat = 16
    
    // MARK: - Layout Calculations
    
    static func topAreaHeight(safeArea: EdgeInsets) -> CGFloat {
        return safeArea.top + navbarHeight
    }
    
    static func bottomAreaHeight(safeArea: EdgeInsets) -> CGFloat {
        return safeArea.bottom + tabbarHeight
    }
    
    /// Dịch toàn bộ khối nội dung (ảnh + controls) xuống dưới so với vị trí chính giữa
    static let verticalShift: CGFloat = 36
    
    /// Height of the main card (e.g. 4:5 aspect ratio or optimized for screen)
    static func calculateCardHeight(screenHeight: CGFloat, safeArea: EdgeInsets) -> CGFloat {
        let top = topAreaHeight(safeArea: safeArea)
        let bottom = bottomAreaHeight(safeArea: safeArea)
        let available = screenHeight - top - bottom - standardGap - interactionHeight
        
        // We want the card to be as large as possible but not cramped. 
        // 58% of screen is usually the sweet spot for the image area.
        return min(screenHeight * 0.58, available)
    }
    
    /// The spacer height needed at the top AND bottom of the content block to center it
    static func calculateVerticalCenteringPadding(screenHeight: CGFloat, safeArea: EdgeInsets) -> CGFloat {
        let cardH = calculateCardHeight(screenHeight: screenHeight, safeArea: safeArea)
        let totalContentH = cardH + standardGap + interactionHeight
        let availableH = screenHeight - topAreaHeight(safeArea: safeArea) - bottomAreaHeight(safeArea: safeArea)
        
        let centerPadding = max((availableH - totalContentH) / 2, 0)
        return centerPadding + verticalShift
    }
    
    // MARK: - Legacy Compatibility (To prevent build breakages)
    
    static func calculateMainCardSize(screenSize: CGSize, safeArea: EdgeInsets) -> CGSize {
        let h = calculateCardHeight(screenHeight: screenSize.height, safeArea: safeArea)
        return CGSize(width: screenSize.width, height: h)
    }
    
    static func topSpacing(safeArea: EdgeInsets) -> CGFloat {
        return topAreaHeight(safeArea: safeArea)
    }
}
