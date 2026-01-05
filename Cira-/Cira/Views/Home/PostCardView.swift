//
//  PostCardView.swift
//  Cira
//
//  Card displaying a single post - Full image card style
//

import SwiftUI
import AVKit

struct PostCardView: View {
    let post: Post
    var cardWidth: CGFloat = 260
    var cardHeight: CGFloat = 320
    @State private var currentPhotoIndex = 0
    @State private var isPlayingLivePhoto = false
    
    // Current photo helper
    private var currentPhoto: Post.PhotoItem? {
        let photoIndex = post.isChapter ? currentPhotoIndex : 0
        guard photoIndex < post.photos.count else { return nil }
        return post.photos[photoIndex]
    }
    
    var body: some View {
        // Main Card - Image fills entire card
        ZStack {
            // Get current photo (for chapter) or first photo (for single)
            if let photo = currentPhoto {
                if let imageData = photo.imageData,
                   let uiImage = UIImage(data: imageData) {
                    // Has image - show full card image
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                    
                    // Live Photo video overlay when playing
                    if let movieURL = photo.livePhotoMovieURL, isPlayingLivePhoto {
                        LivePhotoVideoPlayer(videoURL: movieURL, isPlaying: $isPlayingLivePhoto)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                    }
                } else {
                    // Placeholder
                    placeholderView
                }
            } else {
                placeholderView
            }
            
            // Overlay content
            VStack(spacing: 0) {
                // Live Photo badge
                if currentPhoto?.hasLivePhoto == true {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "livephoto")
                                .font(.caption.weight(.bold))
                            Text(isPlayingLivePhoto ? "LIVE" : "Hold")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isPlayingLivePhoto ? Color.yellow.opacity(0.8) : Color.black.opacity(0.6)))
                        .padding(16)
                        
                        Spacer()
                    }
                }
                
                // Progress bar at top (if chapter with multiple photos)
                if post.isChapter && post.photos.count > 1 {
                    progressBar
                        .padding(.top, currentPhoto?.hasLivePhoto == true ? 0 : 16)
                        .padding(.horizontal, 16)
                }
                
                Spacer()
                
                // Message/Caption at center with dark background
                // Shows the message user typed when capturing
                if let message = post.message, !message.isEmpty {
                    Text(message)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
        .contentShape(Rectangle())
        // Long press gesture for Live Photo playback
        .onLongPressGesture(minimumDuration: 1.0, pressing: { isPressing in
            if currentPhoto?.hasLivePhoto == true {
                if isPressing && !isPlayingLivePhoto {
                    print("📱 Live Photo: Starting playback")
                    isPlayingLivePhoto = true
                } else if !isPressing && isPlayingLivePhoto {
                    print("📱 Live Photo: Stopping playback")
                    isPlayingLivePhoto = false
                }
            }
        }, perform: {})
        // Horizontal swipe for chapter photos only - high priority to override parent gesture
        .highPriorityGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Only handle horizontal swipes for chapters
                    guard post.isChapter && post.photos.count > 1 else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    
                    let threshold: CGFloat = 40
                    // Swipe left = next photo
                    if value.translation.width < -threshold && currentPhotoIndex < post.photos.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPhotoIndex += 1
                        }
                    }
                    // Swipe right = previous photo
                    else if value.translation.width > threshold && currentPhotoIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPhotoIndex -= 1
                        }
                    }
                }
        )
    }
    
    // MARK: - Placeholder View
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 32)
            .fill(Color(white: 0.12))
            .frame(width: cardWidth, height: cardHeight)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: cardWidth * 0.15))
                    .foregroundStyle(.white.opacity(0.3))
            }
    }
    
    // MARK: - Progress Bar (at top of card)
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<post.photos.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index == currentPhotoIndex ? .white : .white.opacity(0.3))
                    .frame(height: 3)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.white.ignoresSafeArea()
        PostCardView(post: Post.mockPosts[0])
    }
}
