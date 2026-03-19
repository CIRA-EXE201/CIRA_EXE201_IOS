//
//  CiraTimelineProvider.swift
//  CiraWidget
//
//  Provides timeline entries for the CIRA widget.
//  Fetches posts directly from Supabase, with App Group cache as fallback.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct CiraWidgetEntry: TimelineEntry {
    let date: Date
    let post: WidgetPost?
    let image: UIImage?
}

// MARK: - Timeline Provider

struct CiraTimelineProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> CiraWidgetEntry {
        CiraWidgetEntry(
            date: Date(),
            post: WidgetPost(
                id: UUID(),
                authorUsername: "friend",
                message: "Một khoảnh khắc đẹp ✨",
                hasVoice: false,
                createdAt: Date()
            ),
            image: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CiraWidgetEntry) -> Void) {
        // For snapshot (widget gallery), use cached data
        let entry = createCachedEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CiraWidgetEntry>) -> Void) {
        // Fetch fresh data from Supabase
        Task {
            let entry = await createNetworkEntry()
            
            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    // MARK: - Network Entry (Primary)
    
    private func createNetworkEntry() async -> CiraWidgetEntry {
        let result = await WidgetNetworkService.fetchAndCachePosts()
        
        guard let latestPost = result.posts.first else {
            // Fallback to cached data
            return createCachedEntry()
        }
        
        // Use downloaded image or try cached
        let image = result.firstImage ?? WidgetDataProvider.shared.loadImage(postId: latestPost.id)
        
        return CiraWidgetEntry(
            date: Date(),
            post: latestPost,
            image: image
        )
    }
    
    // MARK: - Cached Entry (Fallback)
    
    private func createCachedEntry() -> CiraWidgetEntry {
        let provider = WidgetDataProvider.shared
        let posts = provider.loadPosts()
        
        guard let latestPost = posts.first else {
            return CiraWidgetEntry(date: Date(), post: nil, image: nil)
        }
        
        // Downscale image to fit widget limits
        var image = provider.loadImage(postId: latestPost.id)
        if let img = image {
            let maxDim: CGFloat = 360
            if img.size.width > maxDim || img.size.height > maxDim {
                let scale = min(maxDim / img.size.width, maxDim / img.size.height)
                let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                image = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
            }
        }
        
        return CiraWidgetEntry(
            date: Date(),
            post: latestPost,
            image: image
        )
    }
}
