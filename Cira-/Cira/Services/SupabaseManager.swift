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
        try await client.auth.signOut()
    }
    
    // MARK: - Storage Helpers
    func uploadAudio(data: Data, fileName: String) async throws -> String {
        let path = "\(currentUser?.id.uuidString ?? "anonymous")/\(fileName)"
        
        try await client.storage
            .from("audios")
            .upload(path: path, file: data, options: FileOptions(contentType: "audio/m4a"))
        
        let publicURL = try client.storage
            .from("audios")
            .getPublicURL(path: path)
        
        return publicURL.absoluteString
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
            .select() // Select all fields
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
}
