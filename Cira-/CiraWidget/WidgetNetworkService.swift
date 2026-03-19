//
//  WidgetNetworkService.swift
//  CiraWidget
//
//  Lightweight network service for fetching posts directly from Supabase.
//  Uses the auth token shared via App Group UserDefaults.
//

import Foundation
import UIKit

struct WidgetNetworkService {
    
    private static let supabaseURL = "https://vireabjnzjubdqpwfyrq.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpcmVhYmpuemp1YmRxcHdmeXJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM5NjA3OTEsImV4cCI6MjA3OTUzNjc5MX0.QMSm4wgr8jelgOYEt9mZn8q-Q-wGfHmfU78cv0vMA60"
    private static let appGroupID = "group.com.cira.app"
    
    // MARK: - Shared Auth

    static var accessToken: String? {
        let defaults = UserDefaults(suiteName: appGroupID)
        return defaults?.string(forKey: "widget_access_token")
    }
    
    static var currentUserId: String? {
        let defaults = UserDefaults(suiteName: appGroupID)
        return defaults?.string(forKey: "widget_user_id")
    }
    
    // MARK: - Fetch & Cache
    
    /// Fetches latest posts — friend posts first, own posts as fallback.
    static func fetchAndCachePosts() async -> (posts: [WidgetPost], firstImage: UIImage?) {
        guard let token = accessToken else {
            print("⚠️ Widget: No access token in App Group")
            return ([], nil)
        }
        
        let userId = currentUserId
        
        // Step 1: Try friend posts first (exclude own)
        if let userId = userId {
            print("📡 Widget: Fetching friend posts (excluding \(userId.prefix(8))...)")
            let result = await fetchPosts(token: token, excludeOwnerId: userId)
            if !result.posts.isEmpty {
                return result
            }
            print("📡 Widget: No friend posts, falling back to own posts")
        }
        
        // Step 2: Fallback to all posts (including own)
        return await fetchPosts(token: token, excludeOwnerId: nil)
    }
    
    /// Core fetch logic — optionally excludes posts by a specific owner.
    private static func fetchPosts(token: String, excludeOwnerId: String?) async -> (posts: [WidgetPost], firstImage: UIImage?) {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/posts")!
        var queryItems = [
            URLQueryItem(name: "select", value: "id,owner_id,message,voice_url,image_path,created_at,profiles!posts_owner_id_fkey(username)"),
            URLQueryItem(name: "is_active", value: "eq.true"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "5")
        ]
        
        // Filter out own posts if user ID provided
        if let ownerId = excludeOwnerId {
            queryItems.append(URLQueryItem(name: "owner_id", value: "neq.\(ownerId)"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            print("⚠️ Widget: Invalid URL")
            return ([], nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("📡 Widget: PostgREST status=\(statusCode), bytes=\(data.count)")
            
            if statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "?"
                print("⚠️ Widget: PostgREST error: \(body)")
                return ([], nil)
            }
            
            let dtos = try JSONDecoder().decode([WidgetPostDTO].self, from: data)
            print("✅ Widget: Decoded \(dtos.count) posts (friends-only: \(excludeOwnerId != nil))")
            
            if dtos.isEmpty {
                return ([], nil)
            }
            
            let widgetPosts = dtos.map { dto in
                WidgetPost(
                    id: UUID(uuidString: dto.id) ?? UUID(),
                    authorUsername: dto.profiles?.username ?? "Friend",
                    message: dto.message,
                    hasVoice: dto.voice_url != nil && !(dto.voice_url?.isEmpty ?? true),
                    createdAt: parseISO8601(dto.created_at) ?? Date()
                )
            }
            
            // Save to App Group for offline
            WidgetDataProvider.shared.savePosts(widgetPosts)
            
            // Download image for the first post that has one
            var firstImage: UIImage? = nil
            for dto in dtos {
                guard let imagePath = dto.image_path, !imagePath.isEmpty else { continue }
                guard let postId = UUID(uuidString: dto.id) else { continue }
                
                // Try cache first
                if let cached = WidgetDataProvider.shared.loadImage(postId: postId) {
                    let resized = downsizedForWidget(cached)
                    firstImage = resized
                    break
                }
                
                // Download via signed URL
                if let img = await downloadImageViaSignedURL(storagePath: imagePath, token: token) {
                    let resized = downsizedForWidget(img)
                    if let jpegData = resized.jpegData(compressionQuality: 0.7) {
                        WidgetDataProvider.shared.saveImage(jpegData, postId: postId)
                    }
                    firstImage = resized
                    break
                }
            }
            
            return (widgetPosts, firstImage)
            
        } catch {
            print("⚠️ Widget: Error: \(error)")
            return ([], nil)
        }
    }
    
    // MARK: - Download Image via Signed URL
    
    /// Creates a signed URL for the `photos` bucket then downloads the image to disk
    /// and thumbnails it via CGImageSource to stay under widget memory limits.
    private static func downloadImageViaSignedURL(storagePath: String, token: String) async -> UIImage? {
        // Step 1: Create signed URL
        let signEndpoint = "\(supabaseURL)/storage/v1/object/sign/photos/\(storagePath)"
        guard let signURL = URL(string: signEndpoint) else { return nil }
        
        var signRequest = URLRequest(url: signURL)
        signRequest.httpMethod = "POST"
        signRequest.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        signRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        signRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        signRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["expiresIn": 3600])
        
        do {
            let (signData, signResponse) = try await URLSession.shared.data(for: signRequest)
            let signStatus = (signResponse as? HTTPURLResponse)?.statusCode ?? 0
            
            if signStatus != 200 {
                return await downloadImageDirect(storagePath: storagePath, token: token)
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: signData) as? [String: Any],
                  let signedToken = json["signedURL"] as? String else {
                return await downloadImageDirect(storagePath: storagePath, token: token)
            }
            
            let fullSignedURL = signedToken.hasPrefix("http") ? signedToken : "\(supabaseURL)/storage/v1\(signedToken)"
            guard let imageURL = URL(string: fullSignedURL) else { return nil }
            
            // Step 2: Download to temp file (NOT into memory)
            let (tempFileURL, imageResponse) = try await URLSession.shared.download(from: imageURL)
            let imgStatus = (imageResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard imgStatus == 200 else { return nil }
            
            // Step 3: Thumbnail from disk via CGImageSource — never fully decodes
            return thumbnailFromFile(at: tempFileURL)
            
        } catch {
            return await downloadImageDirect(storagePath: storagePath, token: token)
        }
    }
    
    /// Fallback: direct authenticated download to disk
    private static func downloadImageDirect(storagePath: String, token: String) async -> UIImage? {
        let urlString = "\(supabaseURL)/storage/v1/object/authenticated/photos/\(storagePath)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            // Download to temp file
            let (tempFileURL, response) = try await URLSession.shared.download(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return nil }
            return thumbnailFromFile(at: tempFileURL)
        } catch {
            return nil
        }
    }
    
    // MARK: - Memory-Safe Image Thumbnailing
    
    /// Creates a 360px thumbnail directly from a file on disk using ImageIO.
    /// Never loads the full-resolution bitmap into memory.
    private static func thumbnailFromFile(at fileURL: URL) -> UIImage? {
        let maxPixelSize = 360
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// Downscale a UIImage that's already in memory (used for cached images).
    private static func downsizedForWidget(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 360
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    // MARK: - ISO8601 Parser
    
    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - DTO

private struct WidgetPostDTO: Decodable {
    let id: String
    let message: String?
    let voice_url: String?
    let image_path: String?
    let created_at: String
    let profiles: ProfileDTO?
    
    struct ProfileDTO: Decodable {
        let username: String?
    }
}
