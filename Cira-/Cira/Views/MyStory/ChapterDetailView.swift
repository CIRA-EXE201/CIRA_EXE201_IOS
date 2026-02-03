//
//  ChapterDetailView.swift
//  Cira
//
//  Detail view for a chapter - shows posts like HomeView
//  Full-screen card swipe navigation with dark cards
//

import SwiftUI
import SwiftData

struct ChapterDetailView: View {
    let chapter: Chapter
    @Environment(\.dismiss) private var dismiss
    @State private var currentPostIndex = 0
    @State private var cardDragOffset: CGFloat = 0
    @State private var showLiveSheet = false
    @State private var showInvitePopup = false
    
    // Posts generated from chapter photos
    @State private var posts: [Post] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Pure white background
                Color.white
                    .ignoresSafeArea()
                
                // Soft radial blur effects behind card
                blurBackgroundView
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with back button
                    headerView
                    
                    Spacer()
                        .frame(height: 8)
                    
                    // Posts area
                    if posts.isEmpty {
                        Spacer()
                        emptyView
                        Spacer()
                    } else {
                        // Full screen card with voice bar - copy from HomeView
                        fullScreenCardArea
                    }
                }
                .padding(.top, 8)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        if abs(value.translation.height) > abs(value.translation.width) * 1.5 {
                            if (currentPostIndex == 0 && value.translation.height > 0) ||
                               (currentPostIndex == posts.count - 1 && value.translation.height < 0) {
                                cardDragOffset = value.translation.height * 0.3
                            } else {
                                cardDragOffset = value.translation.height
                            }
                        }
                    }
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width) * 1.5 else {
                            cardDragOffset = 0
                            return
                        }
                        
                        let threshold: CGFloat = 60
                        let velocity = value.predictedEndTranslation.height
                        
                        if (value.translation.height < -threshold || velocity < -300) && currentPostIndex < posts.count - 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentPostIndex += 1
                                cardDragOffset = 0
                            }
                        } else if (value.translation.height > threshold || velocity > 300) && currentPostIndex > 0 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentPostIndex -= 1
                                cardDragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                cardDragOffset = 0
                            }
                        }
                    }
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            // Generate sample posts for this chapter
            posts = generateSamplePosts()
        }
        .fullScreenCover(isPresented: $showLiveSheet) {
            LiveChapterView(chapterName: chapter.name, posts: posts)
        }
        .fullScreenCover(isPresented: $showInvitePopup) {
            InviteFamilyPopup(
                isPresented: $showInvitePopup,
                onStartLive: {
                    showInvitePopup = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLiveSheet = true
                    }
                }
            )
            .presentationBackground(.clear)
        }
    }
    
    // MARK: - Generate Posts from Chapter Photos
    private func generateSamplePosts() -> [Post] {
        return chapter.photos.map { photo in
            // Check if photo has voice note
            let voiceItem: Post.VoiceItem? = if let voice = photo.voiceNote {
                Post.VoiceItem(
                    duration: voice.duration,
                    audioURL: voice.audioFileURL,
                    waveformLevels: voice.waveformData ?? []
                )
            } else {
                nil
            }
            
            return Post(
                id: photo.id,
                type: .single,
                photos: [
                    Post.PhotoItem(
                        id: photo.id,
                        imageURL: nil,
                        imageData: photo.imageData,
                        livePhotoMoviePath: photo.livePhotoMoviePath,
                        voiceNote: voiceItem
                    )
                ],
                author: Post.Author(id: UUID(), username: "me", avatarURL: nil),
                createdAt: photo.createdAt,
                likeCount: 0,
                commentCount: 0,
                isLiked: false,
                message: photo.message
            )
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 16) {
            // Back button - Liquid Glass style
            Button(action: { dismiss() }) {
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
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(posts.count) memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Live button - for family slideshow
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showInvitePopup = true
                }
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                    
                    Text("Live")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            
            // More options button
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
    
    // MARK: - Full Screen Card Area (copied from HomeView)
    private var fullScreenCardArea: some View {
        GeometryReader { geometry in
            // Use standardized calculation
            let cardSize = CardDimensions.calculateMainCardSize(screenSize: geometry.size, safeArea: geometry.safeAreaInsets)
            
            // Adjust card dimensions directly from calculation
            let cardWidth = cardSize.width
            let cardHeight = cardSize.height
            
            let postAreaHeight = geometry.size.height
            let cardTopOffset: CGFloat = 0
            
            ZStack(alignment: .top) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    let isDragging = cardDragOffset != 0
                    let shouldShow = index == currentPostIndex || (isDragging && abs(index - currentPostIndex) == 1)
                    
                    if shouldShow {
                        VStack(spacing: 16) {
                            PostCardView(post: post, cardWidth: cardWidth, cardHeight: cardHeight, safeAreaTop: geometry.safeAreaInsets.top)
                            
                            // Voice waveform bar for this post
                            if post.photos.first?.hasVoice == true {
                                compactVoiceBar
                            } else {
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
    
    // MARK: - Compact Voice Bar (copied from HomeView)
    private var compactVoiceBar: some View {
        HStack(spacing: 10) {
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
            
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 3, height: CGFloat.random(in: 8...24))
                }
            }
            
            Spacer()
            
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
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 24) {
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
                        
                        Text("Add photos and recordings to this chapter")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            
            Button(action: {}) {
                Label("Add memory", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Blur Background (copied from HomeView)
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
}

// MARK: - Invite Family Popup
struct InviteFamilyPopup: View {
    @Binding var isPresented: Bool
    var onStartLive: () -> Void
    
    // Sample family members
    private let familyMembers: [FamilyMember] = [
        FamilyMember(name: "Mom", avatar: "person.circle.fill", isSelected: true),
        FamilyMember(name: "Dad", avatar: "person.circle.fill", isSelected: true),
        FamilyMember(name: "Sister", avatar: "person.circle.fill", isSelected: false),
        FamilyMember(name: "Grandpa", avatar: "person.circle.fill", isSelected: false),
        FamilyMember(name: "Grandma", avatar: "person.circle.fill", isSelected: false),
    ]
    
    @State private var selectedMembers: Set<UUID> = []
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            VStack {
                Spacer()
                
                // Bottom sheet popup
                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invite to watch Live")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Select family members to watch together")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.gray.opacity(0.1)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    // Family members list
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(familyMembers) { member in
                                FamilyMemberRow(
                                    member: member,
                                    isSelected: selectedMembers.contains(member.id),
                                    onToggle: {
                                        if selectedMembers.contains(member.id) {
                                            selectedMembers.remove(member.id)
                                        } else {
                                            selectedMembers.insert(member.id)
                                        }
                                    }
                                )
                            }
                            
                            // Add new member button
                            Button(action: {}) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text("Add family member")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: 300)
                    
                    Divider()
                    
                    // Action button
                    VStack(spacing: 12) {
                        Button(action: onStartLive) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 8, height: 8)
                                
                                Text(selectedMembers.isEmpty ? "Start Live" : "Send invite & Start")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
                )
            }
            .ignoresSafeArea()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            // Pre-select first two members
            for member in familyMembers.prefix(2) {
                selectedMembers.insert(member.id)
            }
        }
    }
}

// MARK: - Family Member Model
struct FamilyMember: Identifiable {
    let id = UUID()
    let name: String
    let avatar: String
    var isSelected: Bool
}

// MARK: - Family Member Row
struct FamilyMemberRow: View {
    let member: FamilyMember
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Text(String(member.name.prefix(1)))
                        .font(.headline)
                        .foregroundStyle(.black)
                }
                
                // Name
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.gray.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ChapterDetailView(chapter: Chapter(name: "Sample Chapter", description: "Preview chapter"))
        .modelContainer(for: [Chapter.self, Photo.self, VoiceNote.self], inMemory: true)
}
