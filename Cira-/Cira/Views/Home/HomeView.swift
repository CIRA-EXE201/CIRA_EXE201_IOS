//
//  HomeView.swift
//  Cira
//
//  Home Feed - Camera First, Vertical Scroll
//
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HomeViewModel()
    
    // Scroll state
    @State private var scrollPosition: String? = "camera" // Default to camera
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var dragOffset: CGFloat = 0 // Interactive drag state
    
    // Top bar moved to HomeTopBar struct
    
    var body: some View {
        GeometryReader { geometry in
            let fullHeight = geometry.size.height
            let safeArea = geometry.safeAreaInsets
            
            // Offset State for interactive drag
            let currentOffset = (showProfile ? 0 : -geometry.size.width) + dragOffset
            
            HStack(spacing: 0) {
                // Left Panel: Profile View (Width = Screen Width)
                ProfileView(onClose: { withAnimation { showProfile = false } })
                    .frame(width: geometry.size.width)
                    .background(Color.black)
                
                // Right Panel: Main Content (Width = Screen Width)
                ZStack {
                    // Background - White with gradient and noise
                    GradientNoiseBackground()
                    
                    // Vertical Paging Scroll
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) { // Changed to VStack for tighter physics calculation
                            // 1. Camera (Page 1)
                            CameraView(topSafeArea: safeArea.top, bottomSafeArea: safeArea.bottom)
                                .frame(width: geometry.size.width, height: fullHeight)
                                .id("camera")
                            
                            // 2. Feed Posts (Pages 2..N) - Combined local + social feed
                            if !viewModel.combinedPosts.isEmpty {
                                ForEach(viewModel.combinedPosts) { post in
                                    FeedPostContainer(post: post, safeArea: safeArea, size: geometry.size)
                                        .frame(width: geometry.size.width, height: fullHeight)
                                        .id(post.id.uuidString)
                                }
                            } else {
                                // Empty State Page if no posts
                                emptyStateView
                                    .frame(width: geometry.size.width, height: fullHeight)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging) // Strict single-page snapping
                    
                    // Overlay Top Bar
                    VStack {
                        HomeTopBar(showProfile: $showProfile, showNotifications: $showNotifications)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 8)
                        Spacer()
                    }
                }
                .frame(width: geometry.size.width) // Explicit width for Main Content
            }
            .frame(width: geometry.size.width * 2, alignment: .leading) // Total width is 2x Screen
            .offset(x: currentOffset) // Apply sliding offset
            .animation(.interactiveSpring(), value: currentOffset) // Smooth animation for drag
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        if showProfile {
                            // Can only drag LEFT (negative) to close
                            if translation < 0 {
                                dragOffset = translation
                            }
                        } else {
                            // Can only drag RIGHT (positive) to open
                            if translation > 0 {
                                dragOffset = translation
                            }
                        }
                    }
                    .onEnded { value in
                        let threshold = geometry.size.width * 0.3
                        
                        if showProfile {
                            // Closing: If dragged left sufficiently
                            if value.translation.width < -threshold {
                                withAnimation {
                                    showProfile = false
                                }
                            } else {
                                // Snap back to open
                                withAnimation {
                                    // No state change needed, just reset dragOffset
                                }
                            }
                        } else {
                            // Opening: If dragged right sufficiently
                            if value.translation.width > threshold {
                                withAnimation {
                                    showProfile = true
                                }
                            }
                        }
                        dragOffset = 0 // Key: reset drag offset so base state takes over
                    }
            )
        }
        // Removed .ignoresSafeArea() to respect safe area for content
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
    }
    
    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
            .font(.system(size: 60))
            .foregroundStyle(.gray)
            
            Text("Scroll up to see memories")
            .font(.headline)
            .foregroundStyle(.gray)
            
            Text("Take a photo to start your journey!")
            .font(.subheadline)
            .foregroundStyle(.gray.opacity(0.7))
        }
    }
}

// MARK: - Feed Post Container
// Wraps PostCardView with User Info & Interactions
struct FeedPostContainer: View {
    let post: Post
    let safeArea: EdgeInsets
    let size: CGSize // Accept trusted size from HomeView
    
    // Layout constants
    private let horizontalPadding: CGFloat = 0
    private let topPadding: CGFloat = 0 
    
    // Check if current post has voice note
    private var hasVoice: Bool {
        guard let firstPhoto = post.photos.first else { return false }
        return firstPhoto.voiceNote != nil
    }
    
    var body: some View {
        let screenWidth = size.width
        let screenHeight = size.height
        
        // MARK: - Post Page Layout
        // Standardized Page: Fills exactly 1 Screen
        
        // 1. Defined Page Margins (Internal)
        let headerInset: CGFloat = safeArea.top + 60 // Space for Floating Header
        let footerInset: CGFloat = safeArea.bottom + 10 // Space for Home Indicator
        
        // 2. Component Heights
        let controlsHeight: CGFloat = 110 // Fixed height for Controls
        let gapHeight: CGFloat = 16 // Standard Gap
        
        // 3. Voice bar height if applicable - this goes BELOW the card, not inside
        let voiceBarTotal: CGFloat = hasVoice ? (PostCardView.voiceBarHeight + PostCardView.voiceBarSpacing) : 0
        
        // 4. Dynamic Calculation
        // Image card gets FIXED height regardless of voice bar
        // Available for Image Card = Screen - Header - Gap - Controls - Footer
        let cardHeight = max(screenHeight - headerInset - gapHeight - controlsHeight - footerInset, 100)
        
        // When voice exists, we need to scroll or overlap - for now, reduce controls slightly
        let adjustedControlsHeight = hasVoice ? max(controlsHeight - voiceBarTotal, 60) : controlsHeight
        
        let cardWidth = screenWidth
        
        VStack(spacing: 0) {
            // A. Header Spacer (Push content down)
            Spacer()
                .frame(height: headerInset)
            
            // B. Image Frame + Voice Bar (Dynamic)
            PostCardView(
                post: post,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                safeAreaTop: safeArea.top
            )
            
            // C. Gap
            Spacer()
                .frame(height: gapHeight)
            
            // D. Controls (Adjusted when voice exists)
            PostControlsView(post: post)
                .frame(height: adjustedControlsHeight, alignment: .top)
            
            // E. Footer Spacer (Bottom Safe Area)
            Spacer()
                .frame(height: footerInset)
        }
        .frame(width: screenWidth, height: screenHeight) // STRICT PAGE SIZE
    }
    }
    
// Mark: - Home Top Bar
struct HomeTopBar: View {
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    
    var body: some View {
        HStack {
            // Avatar (Left)
            Button(action: { withAnimation { showProfile = true } }) {
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.black.opacity(0.7))
                    }
            }
            
            Spacer()
            
            // "11 người bạn" / Friends Pill (Center)
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.8))
                    Text("11 người bạn")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.08)))
            }
            
            Spacer()
            
            // Chat/Notification (Right)
            Button(action: { showNotifications = true }) {
                ZStack {
                    Image(systemName: "bubble.right.fill") // Chat bubble look
                        .font(.system(size: 24))
                        .foregroundStyle(.black.opacity(0.6))
                    
                    // Badge
                    Circle()
                        .fill(Color.orange) // Matches golden theme
                        .frame(width: 12, height: 12)
                        .offset(x: 10, y: -10)
                        .overlay {
                            Text("1")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: 10, y: -10)
                        }
                }
                .frame(width: 40, height: 40)
            }
        }
    }
}

#Preview {
    HomeView()
}
