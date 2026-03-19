//
//  CiraWidgetEntryView.swift
//  CiraWidget
//
//  SwiftUI view for the CIRA small widget.
//  Layout: Image background → username header (top-left) → caption (bottom-left) → play icon (bottom-right)
//

import SwiftUI
import WidgetKit

struct CiraWidgetEntryView: View {
    let entry: CiraWidgetEntry
    
    var body: some View {
        if let post = entry.post {
            postView(post: post)
        } else {
            emptyView
        }
    }
    
    // MARK: - Post View
    
    private func postView(post: WidgetPost) -> some View {
        GeometryReader { geo in
            ZStack {
                // Background Image
                imageBackground(size: geo.size)
                
                // Gradient overlays for readability
                VStack(spacing: 0) {
                    // Top gradient
                    LinearGradient(
                        colors: [.black.opacity(0.55), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.35)
                    
                    Spacer()
                    
                    // Bottom gradient
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.45)
                }
                
                // Content overlay
                VStack(alignment: .leading, spacing: 0) {
                    // HEADER — Username
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                        
                        Text(post.authorUsername)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
                    
                    Spacer()
                    
                    // FOOTER — Caption + Play button
                    HStack(alignment: .bottom, spacing: 6) {
                        // Caption
                        if let message = post.message, !message.isEmpty {
                            Text(message)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        } else {
                            // Time ago fallback
                            Text(timeAgo(from: post.createdAt))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Spacer(minLength: 4)
                        
                        // Play button (if voice)
                        if post.hasVoice {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                                    .frame(width: 30, height: 30)
                                
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }
                        }
                    }
                }
                .padding(12)
            }
            // Deep link — tap opens this post in the app
            .widgetURL(URL(string: "cira://post/\(post.id.uuidString)"))
        }
    }
    
    // MARK: - Image Background
    
    private func imageBackground(size: CGSize) -> some View {
        Group {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                // Placeholder gradient when no image
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.2),
                            Color(red: 0.08, green: 0.08, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
        }
    }
    
    // MARK: - Empty View (No Posts)
    
    private var emptyView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.18),
                    Color(red: 0.06, green: 0.06, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.3))
                
                Text("Mở CIRA")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("để xem bài post mới")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
    
    // MARK: - Time Ago Helper
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
