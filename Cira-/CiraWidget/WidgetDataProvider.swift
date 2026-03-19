//
//  WidgetDataProvider.swift
//  Cira
//
//  Manages shared data between main app and widget extension via App Group container.
//  This file must be added to BOTH targets (Cira + CiraWidget).
//  Contains ONLY Foundation + UIKit code — no Supabase or SwiftData dependencies.
//

import Foundation
import UIKit

/// Provides read/write access to widget data stored in the App Group container.
/// Safe to use from both the main app and widget extension.
final class WidgetDataProvider: Sendable {
    static let shared = WidgetDataProvider()
    
    /// App Group identifier — must match in both targets' entitlements.
    static let appGroupID = "group.com.cira.app"
    private static let postsFileName = "widget_posts.json"
    private static let imagesDirName = "widget_images"
    
    private init() {}
    
    // MARK: - Container URLs
    
    var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
    }
    
    private var postsFileURL: URL? {
        containerURL?.appendingPathComponent(Self.postsFileName)
    }
    
    var imagesDirURL: URL? {
        guard let url = containerURL?.appendingPathComponent(Self.imagesDirName, isDirectory: true) else {
            return nil
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    // MARK: - Write Posts
    
    /// Saves widget posts to the shared container.
    func savePosts(_ posts: [WidgetPost]) {
        guard let url = postsFileURL else {
            print("❌ WidgetDataProvider: App Group container not available")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(posts)
            try data.write(to: url, options: .atomic)
            print("✅ WidgetDataProvider: Saved \(posts.count) posts for widget")
        } catch {
            print("❌ WidgetDataProvider: Failed to save posts: \(error)")
        }
    }
    
    /// Saves a thumbnail image for a post to the shared container.
    func saveImage(_ imageData: Data, postId: UUID) {
        guard let dirURL = imagesDirURL else { return }
        let fileURL = dirURL.appendingPathComponent("\(postId.uuidString).jpg")
        
        do {
            try imageData.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ WidgetDataProvider: Failed to save image for \(postId): \(error)")
        }
    }
    
    // MARK: - Read Posts
    
    /// Loads cached widget posts from the shared container.
    func loadPosts() -> [WidgetPost] {
        guard let url = postsFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WidgetPost].self, from: data)
        } catch {
            print("❌ WidgetDataProvider: Failed to load posts: \(error)")
            return []
        }
    }
    
    /// Loads a cached thumbnail image for a post, downsampled to widget size.
    /// Uses CGImageSource to avoid fully loading large images into memory.
    func loadImage(postId: UUID) -> UIImage? {
        guard let dirURL = imagesDirURL else { return nil }
        let fileURL = dirURL.appendingPathComponent("\(postId.uuidString).jpg")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Use ImageIO to downsample at load time — avoids full decode of large images
        let maxPixelSize = 360
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Checks if image already cached for a post.
    func hasImage(postId: UUID) -> Bool {
        guard let dirURL = imagesDirURL else { return false }
        let fileURL = dirURL.appendingPathComponent("\(postId.uuidString).jpg")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
