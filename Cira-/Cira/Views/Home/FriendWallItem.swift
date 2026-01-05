//
//  FriendWallItem.swift
//  Cira
//
//  Friend wall item - compact button style with avatar and name
//

import SwiftUI

struct FriendWallItem: View {
    let name: String
    let isMyWall: Bool
    let hasNewPost: Bool
    var isSelected: Bool = false
    var avatarImage: Image? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            // Small avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 28, height: 28)
                
                if let avatar = avatarImage {
                    avatar
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else if isMyWall {
                    Image(systemName: "house.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                } else {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.7))
                }
                
                // New post indicator dot
                if hasNewPost && !isMyWall {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .offset(x: 10, y: -10)
                }
            }
            
            // Name
            Text(isMyWall ? "Của tôi" : name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .black : .secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? Color.black.opacity(0.06) : Color.clear)
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.black : Color.clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        // Selected state
        HStack(spacing: 8) {
            FriendWallItem(name: "Tôi", isMyWall: true, hasNewPost: false, isSelected: true)
            FriendWallItem(name: "Lan", isMyWall: false, hasNewPost: true, isSelected: false)
            FriendWallItem(name: "Minh", isMyWall: false, hasNewPost: false, isSelected: false)
        }
        
        // Different selection
        HStack(spacing: 8) {
            FriendWallItem(name: "Tôi", isMyWall: true, hasNewPost: false, isSelected: false)
            FriendWallItem(name: "Lan", isMyWall: false, hasNewPost: true, isSelected: true)
            FriendWallItem(name: "Minh", isMyWall: false, hasNewPost: false, isSelected: false)
        }
    }
    .padding()
    .background(.white)
}
