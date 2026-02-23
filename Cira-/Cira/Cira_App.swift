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
                                    // Receiver (the person clicking the link) gets the request from the sender (inviterId)
                                    try await FriendService.shared.receiveFriendRequest(from: uuid)
                                    print("✅ Automatically received friend request from \(inviterId)")
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
