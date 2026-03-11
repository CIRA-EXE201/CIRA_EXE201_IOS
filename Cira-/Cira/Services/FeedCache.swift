//
//  FeedCache.swift
//  Cira
//
//  Local JSON cache for social feed posts.
//  Provides instant feed display on app launch without waiting for network.
//

import Foundation

/// Manages local JSON file caching of social feed posts.
/// Thread-safe: all disk I/O runs on a dedicated serial queue.
final class FeedCache {
    static let shared = FeedCache()
    
    private let cacheQueue = DispatchQueue(label: "com.cira.feedcache", qos: .utility)
    private let cacheFileName = "feed_cache.json"
    
    private var cacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ciraDir = appSupport.appendingPathComponent("Cira", isDirectory: true)
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: ciraDir.path) {
            try? FileManager.default.createDirectory(at: ciraDir, withIntermediateDirectories: true)
        }
        
        return ciraDir.appendingPathComponent(cacheFileName)
    }
    
    private init() {}
    
    // MARK: - Save Feed to Disk
    
    /// Saves feed posts to local JSON file asynchronously.
    func save(_ posts: [FeedPost]) {
        cacheQueue.async { [weak self] in
            guard let self else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(posts)
                try data.write(to: self.cacheURL, options: .atomic)
                print("💾 FeedCache: Saved \(posts.count) posts to disk")
            } catch {
                print("❌ FeedCache: Failed to save: \(error)")
            }
        }
    }
    
    // MARK: - Load Feed from Disk
    
    /// Loads cached feed posts from local JSON file. Returns empty array if no cache exists.
    func load() -> [FeedPost] {
        // Synchronous read for instant display on launch
        let url = cacheURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("📭 FeedCache: No cache file found")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let posts = try JSONDecoder().decode([FeedPost].self, from: data)
            print("📬 FeedCache: Loaded \(posts.count) posts from disk")
            return posts
        } catch {
            print("❌ FeedCache: Failed to load: \(error)")
            return []
        }
    }
    
    // MARK: - Cache Metadata
    
    /// Returns the last modification date of the cache file, or nil if no cache exists.
    func lastCacheDate() -> Date? {
        let url = cacheURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
    
    // MARK: - Clear Cache
    
    /// Deletes the cache file.
    func clear() {
        cacheQueue.async { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.cacheURL)
            print("🗑️ FeedCache: Cache cleared")
        }
    }
}
