//
//  FriendInviteSheet.swift
//  Cira
//
//  Extracted from Cira_App.swift
//

import SwiftUI

struct FriendInviteSheet: View {
    let profile: FriendProfile
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Lời mời kết bạn")
                .font(.title2.weight(.bold))
            
            // Avatar
            if let avatarStr = profile.avatar_data,
               let data = Data(base64Encoded: avatarStr),
               let uiImage = UIImage(data: data) {
                 Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            } else {
                 Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 90, height: 90)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            
            // Message
            Text("Bạn có đồng ý kết bạn với **\(profile.username ?? "người này")** không?")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            HStack(spacing: 16) {
                Button {
                    onDecline()
                } label: {
                    Text("Từ chối")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                }
                
                Button {
                    onAccept()
                } label: {
                    Text("Đồng ý")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.visible)
    }
}
