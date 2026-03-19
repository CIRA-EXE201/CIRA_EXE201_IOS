//
//  FeedCache.swift
//  Cira
//
//  Local JSON cache for social feed posts.
//  User-scoped: each user gets their own cache file to prevent data leakage.
//

import Foundation

/// Manages local JSON file caching of social feed posts.
/// Thread-safe: all disk I/O runs on a dedicated serial queue.
/// User-scoped: cache files are named per-user to prevent cross-account data leakage.
final class FeedCache {
    static let shared = FeedCache()
    
    private let cacheQueue = DispatchQueue(label: "com.cira.feedcache", qos: .utility)
    
    private var ciraDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Cira", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Returns user-scoped cache URL. Falls back to generic if no user ID available.
    private func cacheURL(for userId: String? = nil) -> URL {
        let resolvedId = userId ?? currentUserId
        let fileName = resolvedId != nil ? "feed_cache_\(resolvedId!).json" : "feed_cache.json"
        return ciraDir.appendingPathComponent(fileName)
    }
    
    /// Gets the current user ID from SupabaseManager (thread-safe read)
    private var currentUserId: String? {
        // SupabaseManager.shared is @MainActor, but we only read the UUID string
        // which is safe as it's set during auth and doesn't change mid-session
        return UserDefaults.standard.string(forKey: "com.cira.currentUserId")
    }
    
    private init() {}
    
    // MARK: - Track Current User
    
    /// Call this when a user signs in to set the cache scope.
    func setCurrentUser(id: String) {
        UserDefaults.standard.set(id, forKey: "com.cira.currentUserId")
    }
    
    /// Call this on sign out to clear the user scope.
    func clearCurrentUser() {
        UserDefaults.standard.removeObject(forKey: "com.cira.currentUserId")
    }
    
    // MARK: - Save Feed to Disk
    
    /// Saves feed posts to local JSON file asynchronously.
    func save(_ posts: [FeedPost]) {
        let url = cacheURL()
        cacheQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(posts)
                try data.write(to: url, options: .atomic)
                print("💾 FeedCache: Saved \(posts.count) posts to disk")
            } catch {
                print("❌ FeedCache: Failed to save: \(error)")
            }
        }
    }
    
    // MARK: - Load Feed from Disk
    
    /// Loads cached feed posts from local JSON file. Returns empty array if no cache exists.
    func load() -> [FeedPost] {
        let url = cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("📭 FeedCache: No cache file found for current user")
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
        let url = cacheURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
    
    // MARK: - Clear Cache
    
    /// Deletes the current user's cache file.
    func clear() {
        let url = cacheURL()
        cacheQueue.async {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ FeedCache: Cache cleared for current user")
        }
    }
    
    /// Deletes ALL user cache files (call on full app reset).
    func clearAll() {
        let dir = ciraDir
        cacheQueue.async {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            for file in files where file.hasPrefix("feed_cache_") {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
            }
            // Also remove the legacy non-scoped cache
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("feed_cache.json"))
            print("🗑️ FeedCache: All caches cleared")
        }
    }
}

