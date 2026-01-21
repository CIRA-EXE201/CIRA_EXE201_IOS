//
//  HomeView.swift
//  Cira
//
//  Home Feed - Clean white background with card-style posts
//  Like Locket/Memory web UI style
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HomeViewModel()
    @State private var currentPostIndex = 0
    @State private var showNotifications = false
    @State private var showAddOptions = false
    @State private var showProfile = false
    @State private var showAddFriends = false
    @State private var profileDragOffset: CGFloat = 0
    @State private var cardDragOffset: CGFloat = 0 // For card swipe animation
    @State private var selectedWallId: UUID? = nil // nil = "All posts"
    @State private var expandedCategory: WallCategory? = nil // Which category is expanded
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Profile View (slides from left) - full screen
                ProfileView(onClose: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showProfile = false
                    }
                })
                    .frame(width: geometry.size.width)
                    .offset(x: showProfile ? 0 : -geometry.size.width)
                
                // Main Home View
                mainHomeContent
                    .offset(x: showProfile ? geometry.size.width : profileDragOffset)
                    .shadow(color: showProfile ? .black.opacity(0.15) : .clear, radius: 20, x: -10, y: 0)
                
                // Left edge gesture area - only detect swipe from left edge
                if !showProfile {
                    Color.clear
                        .frame(width: 30)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow right swipe from left edge
                                    if value.translation.width > 0 {
                                        profileDragOffset = min(value.translation.width * 0.6, geometry.size.width * 0.5)
                                    }
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 100
                                    
                                    if value.translation.width > threshold {
                                        // Open profile - full screen
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            showProfile = true
                                            profileDragOffset = 0
                                        }
                                    } else {
                                        // Snap back
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            profileDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Right edge gesture area to close profile - only on the right edge
                if showProfile {
                    Color.clear
                        .frame(width: 40)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.width < 0 {
                                        profileDragOffset = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 100
                                    
                                    if value.translation.width < -threshold {
                                        // Close profile
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            showProfile = false
                                            profileDragOffset = 0
                                        }
                                    } else {
                                        // Snap back
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            profileDragOffset = 0
                                        }
                                    }
                                }
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPostSaved)) { _ in
            // Refresh posts when new post is saved
            viewModel.loadPosts()
            currentPostIndex = 0
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet()
        }
        .sheet(isPresented: $showAddOptions) {
            AddOptionsSheet()
        }
    }
    
    // MARK: - Main Home Content
    private var mainHomeContent: some View {
        ZStack {
            // Pure white background - extend to edges
            Color.white
                .ignoresSafeArea()
            
            // Soft radial blur effects behind card
            blurBackgroundView
                .ignoresSafeArea()
            
            // Main content with safe area
            VStack(spacing: 0) {
                // Header - at top edge
                headerView
                    .padding(.top, 8)
                
                // Friends' walls row - with spacing from header and card
                friendsWallsRow
                    .padding(.top, 12)
                    .padding(.bottom, 24) // More space before card
                    .zIndex(2) // Above card shadow
                
                // Card area - full width
                if viewModel.posts.isEmpty {
                    Spacer()
                    EmptyFeedView(onAddTap: { showAddOptions = true })
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    // Full screen card with voice bar
                    fullScreenCardArea
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    // Only handle vertical swipes, ignore horizontal (for chapter swipe)
                    if abs(value.translation.height) > abs(value.translation.width) * 1.5 {
                        // Allow drag with resistance at edges
                        if (currentPostIndex == 0 && value.translation.height > 0) ||
                           (currentPostIndex == viewModel.posts.count - 1 && value.translation.height < 0) {
                            // Resistance at edges
                            cardDragOffset = value.translation.height * 0.3
                        } else {
                            cardDragOffset = value.translation.height
                        }
                    }
                }
                .onEnded { value in
                    // Only handle vertical swipes - require more vertical than horizontal
                    guard abs(value.translation.height) > abs(value.translation.width) * 1.5 else {
                        cardDragOffset = 0
                        return
                    }
                    
                    let threshold: CGFloat = 60
                    let velocity = value.predictedEndTranslation.height
                    
                    // Swipe up = next post
                    if (value.translation.height < -threshold || velocity < -300) && currentPostIndex < viewModel.posts.count - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentPostIndex += 1
                            cardDragOffset = 0
                        }
                    }
                    // Swipe down = previous post
                    else if (value.translation.height > threshold || velocity > 300) && currentPostIndex > 0 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentPostIndex -= 1
                            cardDragOffset = 0
                        }
                    }
                    // Snap back
                    else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            cardDragOffset = 0
                        }
                    }
                }
        )
    }
    
    // MARK: - Current Post
    private var currentPost: Post? {
        guard !viewModel.posts.isEmpty else { return nil }
        return viewModel.posts[currentPostIndex]
    }
    
    // MARK: - Compact Voice Bar
    private var compactVoiceBar: some View {
        HStack(spacing: 10) {
            // Play button
            Button(action: {}) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
            }
            
            // Waveform bars
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 3, height: CGFloat.random(in: 8...24))
                }
            }
            
            Spacer()
            
            // Duration
            Text("0:15")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Blur Background
    private var blurBackgroundView: some View {
        ZStack {
            // Top-left soft gray blur
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gray.opacity(0.08),
                            Color.gray.opacity(0.02),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -150)
                .blur(radius: 60)
            
            // Bottom-right soft gray blur
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gray.opacity(0.06),
                            Color.gray.opacity(0.02),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: 120, y: 200)
                .blur(radius: 50)
            
            // Center soft glow behind card
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gray.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 40)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            // User avatar - Liquid Glass style
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showProfile = true
                }
            }) {
                ZStack {
                    // Glass background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                    
                    // Subtle border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 40, height: 40)
                    
                    // Icon
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
            
            Spacer()
            
            // Expand button - Liquid Glass style
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
    
    // MARK: - Friends' Walls Row
    private var friendsWallsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Family category
                categoryTabView(category: .family, members: viewModel.familyWalls)
                
                // Friends category
                categoryTabView(category: .friends, members: viewModel.friendWalls)
                
                // Add Friends button
                Button(action: { showAddFriends = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                                .background(Circle().fill(Color.white))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled() // Don't clip content
        .background(Color.clear)
        .sheet(isPresented: $showAddFriends) {
            AddFriendsView()
        }
    }
    
    // MARK: - Category Tab View
    private func categoryTabView(category: WallCategory, members: [FriendWall]) -> some View {
        let isExpanded = expandedCategory == category
        let hasNewPost = members.contains { $0.hasNewPost }
        let isAnyMemberSelected = members.contains { $0.id == selectedWallId }
        
        return HStack(spacing: 6) {
            // Main category tab
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if isExpanded {
                        // Collapse and deselect
                        expandedCategory = nil
                        if isAnyMemberSelected {
                            selectedWallId = nil
                        }
                    } else {
                        // Expand this category
                        expandedCategory = category
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .medium))
                    
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: isExpanded || isAnyMemberSelected ? .semibold : .medium))
                    
                    // Chevron indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isExpanded || isAnyMemberSelected ? .white.opacity(0.7) : .secondary)
                }
                .foregroundStyle(isExpanded || isAnyMemberSelected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isExpanded || isAnyMemberSelected ? Color.black : Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    // New post indicator
                    if hasNewPost && !isExpanded {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Expanded members
            if isExpanded {
                HStack(spacing: 4) {
                    ForEach(members) { member in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedWallId = member.id
                            }
                        }) {
                            memberTab(member: member, category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
    
    // MARK: - Member Tab
    private func memberTab(member: FriendWall, category: WallCategory) -> some View {
        let isSelected = selectedWallId == member.id
        
        return HStack(spacing: 5) {
            // Small avatar
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white : Color.white)
                    .frame(width: 22, height: 22)
                
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.8))
                
                // New post dot
                if member.hasNewPost {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: -8)
                }
            }
            
            Text(member.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .white : .black.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isSelected ? Color.black : Color.white)
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
        )
    }
    
    // MARK: - Category Color
    private func categoryColor(_ category: WallCategory) -> Color {
        switch category {
        case .family: return Color.orange
        case .friends: return Color.blue
        }
    }
    
    // MARK: - Full Screen Card Area
    private var fullScreenCardArea: some View {
        GeometryReader { geometry in
            // Match CameraView dimensions exactly
            // CameraView uses: cardHeight = availableHeight - controlsHeight(90) - tabBarSpace(70) - topSpace(8)
            let tabBarSpace: CGFloat = 70
            let controlsHeight: CGFloat = 90  // Same as camera preview controls
            let topSpace: CGFloat = 8
            let cardHeight = geometry.size.height - controlsHeight - tabBarSpace - topSpace
            let cardWidth = geometry.size.width - CardDimensions.horizontalPadding
            
            // Fixed content area height for each post
            let postAreaHeight = geometry.size.height
            // Fixed top position for card (consistent spacing from header)
            let cardTopOffset: CGFloat = 0
            
            ZStack(alignment: .top) {
                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                    // Only show current card and adjacent cards during drag
                    let isDragging = cardDragOffset != 0
                    let shouldShow = index == currentPostIndex || (isDragging && abs(index - currentPostIndex) == 1)
                    
                    if shouldShow {
                        VStack(spacing: 16) {
                            PostCardView(post: post, cardWidth: cardWidth, cardHeight: cardHeight)
                            
                            // Voice waveform bar for this post (or invisible spacer to keep consistent layout)
                            if let voiceNote = post.photos.first?.voiceNote {
                                VoiceBarView(voiceNote: voiceNote)
                            } else {
                                // Invisible spacer to maintain consistent card position
                                Color.clear
                                    .frame(height: 64)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .frame(width: geometry.size.width)
                        .offset(y: cardTopOffset + CGFloat(index - currentPostIndex) * postAreaHeight + cardDragOffset)
                        .zIndex(index == currentPostIndex ? 1 : 0)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .clipped()
        }
    }
    
    // Calculate offset for full screen slide - each post slides by content height
    private func calculateFullScreenOffset(for index: Int, contentHeight: CGFloat) -> CGFloat {
        let difference = index - currentPostIndex
        let baseOffset = CGFloat(difference) * contentHeight
        return baseOffset + cardDragOffset
    }
    
    // Old function kept for reference
    private func calculateCardOffset(for index: Int, cardHeight: CGFloat) -> CGFloat {
        let difference = index - currentPostIndex
        let baseOffset = CGFloat(difference) * (cardHeight + 20)
        return baseOffset + cardDragOffset
    }
    
    // MARK: - Card Content View (swipe navigation only)
    private var cardContentView: some View {
        mainCardView
    }
    
    // MARK: - Main Card
    private var mainCardView: some View {
        ZStack {
            if !viewModel.posts.isEmpty {
                let post = viewModel.posts[currentPostIndex]
                PostCardView(post: post, cardWidth: 260, cardHeight: 320)
            }
        }
    }
}

// MARK: - Empty Feed View
struct EmptyFeedView: View {
    let onAddTap: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Empty card placeholder
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.08))
                .frame(width: 280, height: 360)
                .overlay {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.5))
                        
                        Text("No memories yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Take photos and record your voice")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            
            Button(action: onAddTap) {
                Label("Create new", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Notifications Sheet
struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Text("No new notifications")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add Options Sheet
struct AddOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button(action: {}) {
                    Label("Take photo", systemImage: "camera")
                }
                
                Button(action: {}) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                }
                
                Button(action: {}) {
                    Label("Create new Chapter", systemImage: "book.closed")
                }
            }
            .navigationTitle("Create new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    HomeView()
}
