//
//  SupabaseManager.swift
//  Cira
//
//  Singleton for Supabase client initialization
//

import Foundation
import Supabase

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let supabaseURLString = json["SUPABASE_URL"],
              let supabaseURL = URL(string: supabaseURLString),
              let supabaseKey = json["SUPABASE_ANON_KEY"] else {
            fatalError("🚨 Secrets.json is missing or invalid. Please check the Walkthrough.")
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(schema: "public"),
                auth: SupabaseClientOptions.AuthOptions(
                    flowType: .pkce
                )
            )
        )
        
        // Share auth token with widget on init
        Task {
            await shareTokenWithWidget()
        }
    }
    
    // MARK: - Widget Token Sharing
    private static let widgetAppGroupID = "group.com.cira.app"
    
    /// Share the current auth token with the widget extension via App Group UserDefaults.
    func shareTokenWithWidget() async {
        do {
            let session = try await client.auth.session
            let defaults = UserDefaults(suiteName: Self.widgetAppGroupID)
            defaults?.set(session.accessToken, forKey: "widget_access_token")
            defaults?.set(session.user.id.uuidString, forKey: "widget_user_id")
            defaults?.synchronize()
            print("✅ Shared auth token + user ID with widget")
        } catch {
            print("⚠️ Could not share token with widget: \(error)")
        }
    }
    
    /// Clear the widget auth token (call on sign out).
    func clearWidgetToken() {
        let defaults = UserDefaults(suiteName: Self.widgetAppGroupID)
        defaults?.removeObject(forKey: "widget_access_token")
        defaults?.synchronize()
    }
    
    // MARK: - Auth Helpers
    var currentUser: User? {
        client.auth.currentUser
    }
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    /// Native Google Sign-In using GoogleSignIn SDK
    func signInWithGoogle() async throws {
        // 1. Get ID Token from Native Google Sign-In
        let idToken = try await GoogleAuthManager.shared.signIn()
        
        // 2. Exchange ID Token with Supabase
        try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken
            )
        )
    }
    
    /// Fallback: Browser-based OAuth (if Native fails)
    func signInWithGoogleBrowser() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "cira://login-callback")
        )
    }
    
    func signOut() async throws {
        clearWidgetToken()
        try await client.auth.signOut()
    }
    
    /// Delete the current user's account via Edge Function (cascade delete all data)
    func deleteAccount() async throws {
        // Get the current session token
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "DeleteAccount", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Call the Edge Function
        let response = try await client.functions.invoke(
            "delete-user-account",
            options: .init(
                headers: ["Authorization": "Bearer \(session.accessToken)"]
            )
        )
        
        // Check HTTP status from the response
        // The function returns 200 on success
        // If we get here without throwing, assume success
        
        // Sign out locally
        try? await client.auth.signOut()
    }
    
    // MARK: - Storage Helpers
    func uploadAudio(data: Data, fileName: String) async throws -> String {
        let path = "\(currentUser?.id.uuidString ?? "anonymous")/\(fileName)"
        
        try await client.storage
            .from("audios")
            .upload(path: path, file: data, options: FileOptions(contentType: "audio/m4a", upsert: true))
        
        return path
    }
    
    func deleteAudio(path: String) async throws {
        try await client.storage
            .from("audios")
            .remove(paths: [path])
    }
    
    // MARK: - Photo/Video Storage
    func uploadImage(data: Data, fileName: String) async throws -> String {
        let path = "\(currentUser?.id.uuidString ?? "anonymous")/\(fileName)"
        
        try await client.storage
            .from("photos")
            .upload(path: path, file: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        
        // Return the path for DB storage (not the full URL, to keep it clean)
        return path
    }
    
    func uploadVideo(fileURL: URL, fileName: String) async throws -> String {
        let path = "\(currentUser?.id.uuidString ?? "anonymous")/\(fileName)"
        
        // SDK requires Data for upload
        let data = try Data(contentsOf: fileURL)
        
        try await client.storage
            .from("photos")
            .upload(path: path, file: data, options: FileOptions(contentType: "video/quicktime", upsert: true))
        
        return path
    }
    
    // MARK: - Download Helpers
    func downloadFile(bucket: String, path: String) async throws -> Data {
        let data = try await client.storage
            .from(bucket)
            .download(path: path)
        return data
    }
    
    func fetchUserPosts(userId: String, after date: Date? = nil) async throws -> [PostDTO] {
        var query = client
            .from("posts")
            .select("*, profiles!inner(username, avatar_data)")
            .eq("owner_id", value: userId)
            
        if let startDate = date {
            // Delta Sync: Only get posts updated AFTER the last sync
            let dateString = ISO8601DateFormatter().string(from: startDate)
            query = query.gt("updated_at", value: dateString)
        }
            
        // Apply sorting at the end
        let posts: [PostDTO] = try await query
            .order("updated_at", ascending: false) 
            .execute()
            .value
        
        return posts
    }
    
    // Fetch all posts visible to user (including friends)
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    func fetchAllVisiblePosts(after date: Date? = nil) async throws -> [PostDTO] {
        var query = client
            .from("posts")
            .select("*, profiles!inner(username, avatar_data)")
            
        if let startDate = date {
            // Delta Sync: Only get posts updated AFTER the last sync
            let dateString = Self.iso8601Formatter.string(from: startDate)
            query = query.gt("updated_at", value: dateString)
        }
            
        // Apply sorting and limit at the end
        let posts: [PostDTO] = try await query
            .order("updated_at", ascending: false)
            .limit(200)
            .execute()
            .value
        
        return posts
    }
}
