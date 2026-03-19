//
//  CachedRemoteImage.swift
//  Cira
//
//  High-performance remote image loader with disk caching, retry, and prefetching.
//  Replaces AsyncImage for Supabase Storage images.
//

import SwiftUI
import UIKit

// MARK: - Image Cache Manager
/// Singleton that manages both memory and disk caching of remote images.
final class ImageCacheManager: @unchecked Sendable {
    static let shared = ImageCacheManager()
    
    // Memory cache (fast, volatile)
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Disk cache directory
    private let diskCacheURL: URL
    
    // URLSession with aggressive caching
    let session: URLSession
    
    private init() {
        // Configure disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDir.appendingPathComponent("CiraImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure URLSession with large cache
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,  // 100 MB memory
            diskCapacity: 500 * 1024 * 1024,      // 500 MB disk
            diskPath: "CiraImageURLCache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
        
        // Memory cache limit
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }
    
    // MARK: - Cache Key
    private func cacheKey(for url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }
    
    private func diskPath(for key: String) -> URL {
        // Use a hash for filename to avoid too-long paths
        let hash = key.hashValue
        return diskCacheURL.appendingPathComponent("\(hash).img")
    }
    
    // MARK: - Get from Cache
    func cachedImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url) as NSString
        
        // 1. Memory cache (fastest)
        if let memImage = memoryCache.object(forKey: key) {
            return memImage
        }
        
        // 2. Disk cache
        let path = diskPath(for: cacheKey(for: url))
        if let data = try? Data(contentsOf: path),
           let image = UIImage(data: data) {
            // Promote to memory cache
            memoryCache.setObject(image, forKey: key, cost: data.count)
            return image
        }
        
        return nil
    }
    
    // MARK: - Store to Cache
    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url) as NSString
        
        // Memory cache
        memoryCache.setObject(image, forKey: key)
        
        // Disk cache (async to avoid blocking)
        let path = diskPath(for: cacheKey(for: url))
        DispatchQueue.global(qos: .utility).async {
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: path, options: .atomic)
            }
        }
    }
    
    // MARK: - Cache by storage path (for Supabase remote paths)
    func cachedImage(forStoragePath path: String) -> UIImage? {
        let key = "storage_\(path)" as NSString
        if let memImage = memoryCache.object(forKey: key) {
            return memImage
        }
        
        let diskURL = diskPath(for: "storage_\(path)")
        if let data = try? Data(contentsOf: diskURL),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key, cost: data.count)
            return image
        }
        return nil
    }
    
    func store(_ image: UIImage, forStoragePath path: String) {
        let key = "storage_\(path)" as NSString
        memoryCache.setObject(image, forKey: key)
        
        let diskURL = diskPath(for: "storage_\(path)")
        DispatchQueue.global(qos: .utility).async {
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: diskURL, options: .atomic)
            }
        }
    }
    
    // MARK: - Prefetch (download + cache ahead of time)
    /// Downloads images at the given URLs and stores them in cache.
    /// Call this after generating signed URLs so images are ready before views appear.
    func prefetch(urls: [URL]) {
        for url in urls {
            // Skip if already cached
            if cachedImage(for: url) != nil { continue }
            
            // Download in background
            Task.detached(priority: .medium) {
                do {
                    let (data, _) = try await self.session.data(from: url)
                    if let image = UIImage(data: data) {
                        self.store(image, for: url)
                    }
                } catch {
                    // Silent fail — CachedRemoteImage will retry on appear
                }
            }
        }
    }
    
    // MARK: - Cleanup old cache
    func cleanOldCache(maxAge: TimeInterval = 7 * 24 * 3600) {
        DispatchQueue.global(qos: .background).async { [diskCacheURL] in
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: diskCacheURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { return }
            
            let cutoff = Date().addingTimeInterval(-maxAge)
            for file in files {
                if let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = attrs.contentModificationDate,
                   modDate < cutoff {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
}

// MARK: - CachedRemoteImage View
/// A SwiftUI view that loads a remote image with disk caching and retry support.
/// Replaces AsyncImage for better performance.
struct CachedRemoteImage: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var retryCount = 0
    
    private let maxRetries = 3
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else if loadFailed {
                // Error state with retry button
                ZStack {
                    Color.black.opacity(0.1)
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Button {
                            retryLoad()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Thử lại")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.2)))
                        }
                    }
                }
                .frame(width: width, height: height)
            } else {
                // Loading state — subtle shimmer
                ShimmerPlaceholder()
                    .frame(width: width, height: height)
            }
        }
        .task(id: "\(url.absoluteString)_\(retryCount)") {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Check cache first (instant)
        if let cached = ImageCacheManager.shared.cachedImage(for: url) {
            self.image = cached
            self.isLoading = false
            return
        }
        
        isLoading = true
        loadFailed = false
        
        do {
            let (data, _) = try await ImageCacheManager.shared.session.data(from: url)
            
            guard let uiImage = UIImage(data: data) else {
                loadFailed = true
                isLoading = false
                return
            }
            
            // Store in cache
            ImageCacheManager.shared.store(uiImage, for: url)
            
            // Show with animation
            withAnimation(.easeIn(duration: 0.15)) {
                self.image = uiImage
            }
            isLoading = false
        } catch {
            if retryCount < maxRetries {
                // Auto-retry with exponential backoff
                let delay = pow(2.0, Double(retryCount)) * 0.5
                try? await Task.sleep(for: .seconds(delay))
                retryCount += 1
            } else {
                loadFailed = true
                isLoading = false
            }
        }
    }
    
    private func retryLoad() {
        retryCount = 0
        loadFailed = false
        isLoading = true
    }
}

// MARK: - Shimmer Placeholder
struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Color.black.opacity(0.08)
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.15),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2.5)
                )
                .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
