//
//  LiveChapterView.swift
//  Cira
//
//  Live slideshow view for family viewing
//  Auto-plays photos with voice notes in fullscreen
//

import SwiftUI

struct LiveChapterView: View {
    let chapterName: String
    let posts: [Post]
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex = 0
    @State private var isPlaying = true
    @State private var progress: CGFloat = 0
    @State private var showControls = true
    @State private var timer: Timer?
    
    // Duration for each slide (seconds)
    private let slideDuration: TimeInterval = 5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background for immersive experience
                Color.black
                    .ignoresSafeArea()
                
                // Current photo
                if posts.indices.contains(currentIndex) {
                    slideView(for: posts[currentIndex], size: geometry.size)
                        .transition(.opacity)
                        .id(currentIndex)
                }
                
                // Overlay controls
                VStack {
                    // Top bar
                    topBar
                        .padding(.top, geometry.safeAreaInsets.top + 8)
                    
                    Spacer()
                    
                    // Bottom info
                    bottomBar
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
                .opacity(showControls ? 1 : 0)
                
                // Live indicator (always visible)
                VStack {
                    HStack {
                        Spacer()
                        liveIndicator
                            .padding(.top, geometry.safeAreaInsets.top + 16)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls.toggle()
                }
            }
        }
        .onAppear {
            startSlideshow()
        }
        .onDisappear {
            stopSlideshow()
        }
    }
    
    // MARK: - Slide View
    private func slideView(for post: Post, size: CGSize) -> some View {
        ZStack {
            // Photo placeholder (would be actual image)
            RoundedRectangle(cornerRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 20) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.3))
                
                // Voice indicator if has voice
                if post.photos.first?.hasVoice == true {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.title2)
                        Text("Playing voice...")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.15)))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        VStack(spacing: 12) {
            // Progress bars
            HStack(spacing: 4) {
                ForEach(0..<posts.count, id: \.self) { index in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.3))
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.horizontal, 16)
            
            // Header
            HStack {
                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapterName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text("\(currentIndex + 1) / \(posts.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Play/Pause button
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Navigation buttons
            HStack(spacing: 40) {
                // Previous
                Button(action: previousSlide) {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.5 : 1)
                
                // Next
                Button(action: nextSlide) {
                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
                .disabled(currentIndex == posts.count - 1)
                .opacity(currentIndex == posts.count - 1 ? 0.5 : 1)
            }
            
            // Share info
            Text("Family is watching with you")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    // MARK: - Live Indicator
    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isPlaying ? 1.5 : 1)
                        .opacity(isPlaying ? 0 : 1)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: isPlaying)
                )
            
            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black))
    }
    
    // MARK: - Progress Width
    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentIndex {
            return totalWidth
        } else if index == currentIndex {
            return totalWidth * progress
        } else {
            return 0
        }
    }
    
    // MARK: - Slideshow Controls
    private func startSlideshow() {
        guard isPlaying else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                progress += CGFloat(0.05 / slideDuration)
            }
            
            if progress >= 1 {
                nextSlide()
            }
        }
    }
    
    private func stopSlideshow() {
        timer?.invalidate()
        timer = nil
    }
    
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            startSlideshow()
        } else {
            stopSlideshow()
        }
    }
    
    private func nextSlide() {
        if currentIndex < posts.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
                progress = 0
            }
        } else {
            // Loop back or stop
            stopSlideshow()
            isPlaying = false
        }
    }
    
    private func previousSlide() {
        if currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex -= 1
                progress = 0
            }
        }
    }
}

#Preview {
    LiveChapterView(chapterName: "Sample Chapter", posts: [])
}
