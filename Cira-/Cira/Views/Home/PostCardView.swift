//
//  PostCardView.swift
//  Cira
//
//  Card displaying a single post - Stories-style with rounded corners
//

import SwiftUI
import AVKit
import Supabase

struct PostCardView: View {
    let post: Post
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let safeAreaTop: CGFloat
    
    @State private var currentPhotoIndex = 0
    @State private var isPlayingLivePhoto = false
    @State private var isPlayingVoice = false
    
    // Off-thread decoded image (Issue #2 fix)
    @State private var processedImage: UIImage?
    
    // Signed URL fallback (only for posts without pre-signed URLs)
    @State private var signedImageURLs: [UUID: URL] = [:]
    @State private var fetchingImageIDs = Set<UUID>()
    @State private var signedURLRetryCount: [UUID: Int] = [:]
    
    // Voice player
    @StateObject private var voicePlayer = VoicePlayer()
    
    // Corner radius constant
    private let cornerRadius: CGFloat = 36
    
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
    
    // Check if current photo has voice note
    var hasVoice: Bool {
        currentVoiceNote != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Card with rounded corners
            ZStack(alignment: .bottomTrailing) {
                // Background Image
                imageLayer
                
                // Overlays (Progress bar, Live badge, Message)
                overlayContent
                
                // Voice play button - bottom right corner
                if let voiceNote = currentVoiceNote {
                    voicePlayButton(voiceNote: voiceNote)
                        .padding(16)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
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
        }
        // Decode image off main thread when photo changes
        .task(id: currentPhoto?.id) {
            guard let photo = currentPhoto, let imageData = photo.imageData else {
                processedImage = nil
                return
            }
            processedImage = await ImageProcessor.shared.downsample(
                data: imageData,
                targetSize: CGSize(width: cardWidth, height: cardHeight)
            )
        }
    }
    
    // MARK: - Voice Play Button
    @ViewBuilder
    private func voicePlayButton(voiceNote: Post.VoiceItem) -> some View {
        Button {
            if voicePlayer.isPlaying {
                voicePlayer.pause()
            } else {
                if let url = voiceNote.audioURL {
                    voicePlayer.load(url: url)
                    voicePlayer.play()
                }
            }
        } label: {
            ZStack {
                // Pulse ring when playing
                if voicePlayer.isPlaying {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 52, height: 52)
                        .scaleEffect(voicePlayer.isPlaying ? 1.3 : 1.0)
                        .opacity(voicePlayer.isPlaying ? 0 : 1)
                        .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: voicePlayer.isPlaying)
                }
                
                // Glassmorphism button
                Circle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .overlay(
                        Image(systemName: voicePlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: voicePlayer.isPlaying ? 0 : 1.5)
                            .contentTransition(.symbolEffect(.replace))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Image Layer
    @ViewBuilder
    private var imageLayer: some View {
        if let photo = currentPhoto {
            if photo.imageData != nil {
                // Local image — off-thread decoded via ImageProcessor actor
                if let processedImage {
                    Image(uiImage: processedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                    
                    // Live Photo overlay
                    if let movieURL = photo.livePhotoMovieURL, isPlayingLivePhoto {
                        LivePhotoVideoPlayer(videoURL: movieURL, isPlaying: $isPlayingLivePhoto)
                            .frame(width: cardWidth, height: cardHeight)
                    }
                } else {
                    ShimmerPlaceholder()
                        .frame(width: cardWidth, height: cardHeight)
                }
            } else if let imageURL = (photo.imageURL ?? signedImageURLs[photo.id]) {
                // Remote image with disk caching + retry (URL already pre-signed)
                CachedRemoteImage(url: imageURL, width: cardWidth, height: cardHeight)
            } else if let remotePath = photo.remoteImagePath {
                // Fallback: need to generate signed URL (shouldn't happen with prefetch)
                ZStack {
                    if let cachedImage = ImageCacheManager.shared.cachedImage(forStoragePath: remotePath) {
                        Image(uiImage: cachedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardWidth, height: cardHeight)
                    } else if (signedURLRetryCount[photo.id] ?? 0) >= 3 && signedImageURLs[photo.id] == nil {
                        signedURLErrorView(photoId: photo.id)
                    } else {
                        ShimmerPlaceholder()
                            .frame(width: cardWidth, height: cardHeight)
                    }
                }
                .task(id: "\(photo.id)_\(signedURLRetryCount[photo.id] ?? 0)") {
                    guard signedImageURLs[photo.id] == nil else { return }
                    guard !fetchingImageIDs.contains(photo.id) else { return }
                    
                    fetchingImageIDs.insert(photo.id)
                    do {
                        let url = try await SupabaseManager.shared.client.storage
                            .from("photos")
                            .createSignedURL(path: remotePath, expiresIn: 3600)
                        self.signedImageURLs[photo.id] = url
                    } catch {
                        fetchingImageIDs.remove(photo.id)
                        let currentRetry = signedURLRetryCount[photo.id] ?? 0
                        if currentRetry < 3 {
                            let delay = pow(2.0, Double(currentRetry)) * 0.5
                            try? await Task.sleep(for: .seconds(delay))
                            signedURLRetryCount[photo.id] = currentRetry + 1
                        }
                    }
                }
            } else {
                placeholderLayer
            }
        } else {
            placeholderLayer
        }
    }
    
    // MARK: - Signed URL Error View
    private func signedURLErrorView(photoId: UUID) -> some View {
        ZStack {
            Color.black.opacity(0.1)
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.5))
                
                Button {
                    signedURLRetryCount[photoId] = 0
                    fetchingImageIDs.remove(photoId)
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
        .frame(width: cardWidth, height: cardHeight)
    }
    
    private var placeholderLayer: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(white: 0.15))
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.3))
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
                Capsule()
                    .fill(index == currentPhotoIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.1), radius: 2)
            }
        }
    }
}

// MARK: - Scale Button Style
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
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
