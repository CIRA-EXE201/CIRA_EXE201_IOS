//
//  PostCardView.swift
//  Cira
//
//  Card displaying a single post - Stories-style with rounded corners
//

import SwiftUI
import AVKit

struct PostCardView: View {
    let post: Post
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let safeAreaTop: CGFloat
    
    @State private var currentPhotoIndex = 0
    @State private var isPlayingLivePhoto = false
    @State private var isPlayingVoice = false
    
    // Corner radius constant
    private let cornerRadius: CGFloat = 32
    
    // Current photo helper
    private var currentPhoto: Post.PhotoItem? {
        let photoIndex = post.isChapter ? currentPhotoIndex : 0
        guard photoIndex < post.photos.count else { return nil }
        return post.photos[photoIndex]
    }
    
    // Current voice note helper
    private var currentVoiceNote: Post.VoiceItem? {
        currentPhoto?.voiceNote
    }
    
    // Voice bar height constant
    static let voiceBarHeight: CGFloat = 56
    static let voiceBarSpacing: CGFloat = 12
    
    // Check if current photo has voice note
    var hasVoice: Bool {
        currentVoiceNote != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Card with rounded corners - keeps full cardHeight
            ZStack(alignment: .top) {
                // Background Image
                imageLayer
                
                // Overlays (Progress bar, Live badge, Message)
                overlayContent
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Long press for Live Photo
            .onLongPressGesture(minimumDuration: 0.5, pressing: { isPressing in
                if currentPhoto?.hasLivePhoto == true {
                    isPlayingLivePhoto = isPressing
                }
            }, perform: {})
            // Swipe for chapter photos
            .highPriorityGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard post.isChapter && post.photos.count > 1 else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        
                        if value.translation.width < -50 && currentPhotoIndex < post.photos.count - 1 {
                            withAnimation(.easeInOut(duration: 0.25)) { currentPhotoIndex += 1 }
                        } else if value.translation.width > 50 && currentPhotoIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.25)) { currentPhotoIndex -= 1 }
                        }
                    }
            )
            
            // Voice waveform bar - below image
            if let voiceNote = currentVoiceNote {
                VoiceOverlayBar(voiceNote: voiceNote, isPlaying: $isPlayingVoice)
                    .padding(.horizontal, 16)
                    .padding(.top, Self.voiceBarSpacing)
            }
        }
    }
    
    // MARK: - Image Layer
    @ViewBuilder
    private var imageLayer: some View {
        if let photo = currentPhoto,
           let imageData = photo.imageData,
           let uiImage = UIImage(data: imageData) {
            
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: cardHeight)
            
            // Live Photo overlay
            if let movieURL = photo.livePhotoMovieURL, isPlayingLivePhoto {
                LivePhotoVideoPlayer(videoURL: movieURL, isPlaying: $isPlayingLivePhoto)
                    .frame(width: cardWidth, height: cardHeight)
            }
        } else {
            // Placeholder
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(white: 0.15))
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                }
        }
    }
    
    // MARK: - Overlay Content
    private var overlayContent: some View {
        VStack(spacing: 0) {
            // Top section: Live badge + Progress bar
            VStack(spacing: 8) {
                // Live Photo badge
                if currentPhoto?.hasLivePhoto == true {
                    HStack {
                        livePhotoBadge
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
                
                // Progress bar (for chapters)
                if post.isChapter && post.photos.count > 1 {
                    progressBar
                        .padding(.horizontal, 8)
                        .padding(.top, currentPhoto?.hasLivePhoto == true ? 0 : 12)
                }
            }
            
            Spacer()
            
            // Message caption
            if let message = post.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Live Photo Badge
    private var livePhotoBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "livephoto")
                .font(.system(size: 12, weight: .bold))
            Text(isPlayingLivePhoto ? "LIVE" : "Hold")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(isPlayingLivePhoto ? Color.yellow.opacity(0.9) : Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 4) {
            let count = post.photos.count
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6)
                    .fill(index == currentPhotoIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(height: 12)
                    .frame(maxWidth: .infinity) // Flexibly fill available space
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PostCardView(
            post: Post.mockPosts[0],
            cardWidth: 350,
            cardHeight: 500,
            safeAreaTop: 59
        )
    }
}
