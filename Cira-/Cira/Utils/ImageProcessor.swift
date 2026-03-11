//
//  ImageProcessor.swift
//  Cira
//
//  High-performance image processing actor with downsampling and caching.
//  Based on swiftui-expert-skill/references/image-optimization.md
//

import UIKit
import ImageIO

/// Actor that handles off-main-thread image decoding with downsampling and caching.
///
/// Usage in SwiftUI views:
/// ```
/// @State private var processedImage: UIImage?
/// .task(id: photo.id) {
///     processedImage = await ImageProcessor.shared.downsample(data: data, targetSize: size)
/// }
/// ```
actor ImageProcessor {
    static let shared = ImageProcessor()
    
    private let cache = NSCache<NSString, UIImage>()
    
    init(countLimit: Int = 100) {
        cache.countLimit = countLimit
    }
    
    /// Downsample image data to target size, with caching.
    /// Uses `CGImageSourceCreateThumbnailAtIndex` to decode directly at the target resolution,
    /// avoiding full-resolution decode + resize.
    func downsample(data: Data, targetSize: CGSize) -> UIImage? {
        let cacheKey = "\(data.count)_\(targetSize.width)x\(targetSize.height)" as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        // Scale factor for Retina displays
        let scale: CGFloat = 3.0 // iPhone Pro Max
        let maxPixel = max(targetSize.width, targetSize.height) * scale
        
        // Don't cache the full-resolution source in memory
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Force decode at creation time rather than at first render
            kCGImageSourceShouldCacheImmediately: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        
        let result = UIImage(cgImage: cgImage)
        cache.setObject(result, forKey: cacheKey)
        return result
    }
    
    /// Decode a base64-encoded avatar string into a small UIImage.
    func decodeAvatar(base64String: String, size: CGFloat = 40) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return downsample(data: data, targetSize: CGSize(width: size, height: size))
    }
    
    /// Clear the in-memory image cache.
    func clearCache() {
        cache.removeAllObjects()
    }
}
