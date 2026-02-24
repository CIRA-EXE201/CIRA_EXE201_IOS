//
//  Cira_App.swift
//  Cira-
//
//  Created by Tu Huynh on 1/12/25.
//

import SwiftUI
import SwiftData
import Supabase

@main
struct Cira_App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Photo.self,
            VoiceNote.self,
            Chapter.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var pendingInviterProfile: FriendProfile?
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .onOpenURL { url in
                    // Handle Google Sign-In URL
                    if GoogleAuthManager.shared.handle(url) {
                        return
                    }
                    
                    // Handle Invite Deep Link (cira://invite/<userId> or https://cira.app/invite/<userId>)
                    if let inviterId = extractInviteUserId(from: url) {
                        print("🔗 Received invite from: \(inviterId)")
                        
                        Task {
                            do {
                                // Ensure authenticated
                                if SupabaseManager.shared.isAuthenticated,
                                   let uuid = UUID(uuidString: inviterId) {
                                    
                                    // Fetch the inviter's profile and show the popup
                                    let profile = try await FriendService.shared.getUserProfile(userId: uuid)
                                    await MainActor.run {
                                        pendingInviterProfile = profile
                                    }
                                }
                            } catch {
                                print("❌ Failed to process invite: \(error)")
                            }
                        }
                        return
                    }
                    
                    // Handle Supabase Auth URL
                    Task {
                        try? await SupabaseManager.shared.client.handle(url)
                    }
                }
                .sheet(item: $pendingInviterProfile) { profile in
                    FriendInviteSheet(
                        profile: profile,
                        onAccept: {
                            Task {
                                do {
                                    // Receiver (the person clicking the link) gets the request from the sender (inviterId)
                                    try await FriendService.shared.receiveFriendRequest(from: profile.id)
                                    print("✅ Automatically received friend request from \(profile.id)")
                                } catch {
                                    print("❌ Failed to accept invite: \(error)")
                                }
                                await MainActor.run {
                                    pendingInviterProfile = nil
                                }
                            }
                        },
                        onDecline: {
                            pendingInviterProfile = nil
                        }
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // Helper function to extract invite user ID from both deep link and Universal Link
    private func extractInviteUserId(from url: URL) -> String? {
        // Handle cira://invite/<userId>
        if url.scheme == "cira", url.host == "invite" {
            let pathComponents = url.pathComponents
            if pathComponents.count > 1 {
                return pathComponents[1]
            }
        }
        
        // Handle https://cira-web-blue.vercel.app/invite/<userId> (Universal Link)
        if url.scheme == "https",
           url.host == "cira-web-blue.vercel.app",
           url.pathComponents.count > 2,
           url.pathComponents[1] == "invite" {
            return url.pathComponents[2]
        }
        
        return nil
    }
}
//
//  FriendInviteSheet.swift
//  Cira
//
//  Created by Cira on 2/23/26.
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
