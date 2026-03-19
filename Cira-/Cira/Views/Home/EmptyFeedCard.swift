//
//  EmptyFeedCard.swift
//  Cira
//

import SwiftUI

struct EmptyFeedCard: View {
    let screenSize: CGSize
    let safeArea: EdgeInsets
    @Binding var showSocialHub: Bool
    
    private var cardH: CGFloat {
        CardDimensions.calculateCardHeight(screenHeight: screenSize.height, safeArea: safeArea)
    }
    
    var body: some View {
        let topAreaH = CardDimensions.topAreaHeight(safeArea: safeArea)
        let centeringSpacerH = CardDimensions.calculateVerticalCenteringPadding(
            screenHeight: screenSize.height, safeArea: safeArea
        )
        
        VStack(spacing: 0) {
            Color.clear.frame(height: topAreaH)
            Color.clear.frame(height: centeringSpacerH)
            
            // Card
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color(red: 1.0, green: 0.75, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Text
                VStack(spacing: 8) {
                    Text("Chưa có bài viết nào")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Thêm bạn bè để khám phá\nnhững khoảnh khắc mới")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                
                // CTA Button
                Button(action: { showSocialHub = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Tìm bạn bè")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.orange, Color(red: 1.0, green: 0.75, blue: 0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 12, y: 6)
                }
                
                Spacer()
            }
            .frame(width: screenSize.width, height: cardH)
            .background(
                RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            
            Spacer()
        }
    }
}
