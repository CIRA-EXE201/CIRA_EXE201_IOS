//
//  HomeView.swift
//  Cira
//

import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HomeViewModel()
    
    @Binding var showProfile: Bool
    var avatarData: String?
    var scrollState: HomeScrollState
    
    @State private var showNotifications = false
    @State private var showSocialHub = false
    @State private var globalSafeArea: EdgeInsets = .init()
    
    // Quick Reply State
    @State private var quickReplyPost: Post?
    @State private var quickReplyText: String = ""
    @FocusState private var isQuickReplyFocused: Bool
    @State private var isSendingReply = false
    
    @State private var currentScrollID: String?
    
    var body: some View {
        ZStack {
            // Probe for Safe Area
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SafeAreaPreferenceKey.self, value: proxy.safeAreaInsets)
            }
            .onPreferenceChange(SafeAreaPreferenceKey.self) { insets in
                print("👉 Global Safe Area Recieved: \(insets)")
                self.globalSafeArea = insets
            }
            
            GeometryReader { geometry in
                // Fix: freeze size to screen bounds so keyboard doesn't shrink the feed
                let fullScreenSize = UIScreen.main.bounds.size
                let safeArea = globalSafeArea // Use captured safe area
                
                // RIGHT: Main Content Stack
                ZStack {
                    // A. Seamless Global Background
                    CiraMeshBackground()
                        .ignoresSafeArea(.all)
                    
                    // B. Vertical Paging Scroll
                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                // 1. Camera Page
                                CameraView(screenSize: fullScreenSize, safeArea: safeArea)
                                    .containerRelativeFrame(.vertical)
                                    .id("camera")
                                
                                // 2. Post Pages
                                ForEach(viewModel.combinedPosts) { post in
                                    ContentPageWrapper(screenSize: fullScreenSize, safeArea: safeArea) {
                                        PostCardView(
                                            post: post,
                                            cardWidth: fullScreenSize.width,
                                            cardHeight: CardDimensions.calculateCardHeight(screenHeight: fullScreenSize.height, safeArea: safeArea),
                                            safeAreaTop: safeArea.top
                                        )
                                    } controls: {
                                        PostControlsView(
                                            post: post,
                                            isQuickReplyFocused: isQuickReplyFocused && quickReplyPost?.id == post.id,
                                            onLikeToggle: { postId in
                                                viewModel.toggleLike(for: postId)
                                            },
                                            onReplyTap: {
                                                quickReplyText = ""
                                                quickReplyPost = post
                                                isQuickReplyFocused = true
                                            }
                                        )
                                    }
                                    .containerRelativeFrame(.vertical)
                                    .id(post.id.uuidString)
                                    .onAppear {
                                        viewModel.loadMoreIfNeeded(currentPost: post)
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollPosition(id: $currentScrollID)
                        .scrollTargetBehavior(.paging)
                        .scrollBounceBehavior(.basedOnSize)
                        .ignoresSafeArea(.all)
                        .onChange(of: currentScrollID) { _, newID in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scrollState.isViewingPosts = (newID != nil && newID != "camera")
                            }
                        }
                        .onAppear {
                            // Register the scroll-to-camera action
                            scrollState.scrollToCameraAction = {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    scrollProxy.scrollTo("camera", anchor: .top)
                                }
                            }
                        }
                    }
                    
                    // C. Fixed Overlays
                    VStack(spacing: 0) {
                        HomeTopBar(showProfile: $showProfile, showNotifications: $showNotifications, showSocialHub: $showSocialHub, avatarData: avatarData)
                            .padding(.top, safeArea.top)
                            .padding(.horizontal, 4)
                            .frame(height: CardDimensions.topAreaHeight(safeArea: safeArea))
                        
                        Spacer()
                    }
                    .allowsHitTesting(true)
                }
                .frame(width: fullScreenSize.width, height: fullScreenSize.height, alignment: .top)
            }
            .ignoresSafeArea(.all, edges: .all)
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
            .fullScreenCover(isPresented: $showNotifications) {
                MessageInboxView()
            }
            .sheet(isPresented: $showSocialHub) {
                SocialHubView()
            }
            
            // Loading overlay removed — SplashView already handles initial loading.
            // HomeView content appears progressively as data loads.
            
            // D. Quick Reply Overlay
            if let post = quickReplyPost {
                ZStack {
                    // Dark ambient gradient background
                    LinearGradient(
                        colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                    .ignoresSafeArea()
                    .onTapGesture {
                        isQuickReplyFocused = false
                        quickReplyPost = nil
                    }
                    
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            TextField("Trả lời \(post.author.username)...", text: $quickReplyText)
                                .focused($isQuickReplyFocused)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .tint(.white)
                                .submitLabel(.send)
                                .onSubmit {
                                    sendQuickReply()
                                }
                            
                            Button(action: {
                                sendQuickReply()
                            }) {
                                if isSendingReply {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(quickReplyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.3) : .white)
                                }
                            }
                            .disabled(quickReplyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingReply)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color(white: 0.15))) // Dark gray / xám đen
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
                .ignoresSafeArea(.keyboard, edges: []) // Let this ZStack be pushed up by keyboard
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isQuickReplyFocused)
            }
        }
        .onChange(of: isQuickReplyFocused) { _, isFocused in
            if !isFocused {
                // Slight delay to allow keyboard animation to finish before removing view
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    if !self.isQuickReplyFocused {
                        self.quickReplyPost = nil
                    }
                }
            }
        }
    }
    
    private func sendQuickReply() {
        guard let post = quickReplyPost else { return }
        let sentText = quickReplyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentText.isEmpty else { return }
        
        isSendingReply = true
        
        Task {
            do {
                _ = try await MessageService.shared.sendMessage(
                    to: post.author.id,
                    postId: post.id,
                    content: sentText
                )
                
                await MainActor.run {
                    isSendingReply = false
                    isQuickReplyFocused = false
                    quickReplyPost = nil
                    quickReplyText = ""
                }
            } catch {
                print("Failed to send quick reply: \(error)")
                await MainActor.run {
                    isSendingReply = false
                }
            }
        }
    }
}

// MARK: - Standard Page Wrapper
struct ContentPageWrapper<Main: View, Controls: View>: View {
    let screenSize: CGSize
    let safeArea: EdgeInsets
    let main: Main
    let controls: Controls
    
    init(
        screenSize: CGSize,
        safeArea: EdgeInsets,
        @ViewBuilder main: () -> Main,
        @ViewBuilder controls: () -> Controls
    ) {
        self.screenSize = screenSize
        self.safeArea = safeArea
        self.main = main()
        self.controls = controls()
    }
    
    var body: some View {
        let cardH = CardDimensions.calculateCardHeight(screenHeight: screenSize.height, safeArea: safeArea)
        let centeringSpacerH = CardDimensions.calculateVerticalCenteringPadding(screenHeight: screenSize.height, safeArea: safeArea)
        let topAreaH = CardDimensions.topAreaHeight(safeArea: safeArea)
        
        VStack(spacing: 0) {
            Color.clear.frame(height: topAreaH)
            Color.clear.frame(height: centeringSpacerH)
            main.frame(width: screenSize.width, height: cardH)
            Color.clear.frame(height: CardDimensions.standardGap)
            controls.frame(height: CardDimensions.interactionHeight, alignment: .top)
            Spacer() 
        }
    }
}

// MARK: - Home Top Bar
struct HomeTopBar: View {
    @Binding var showProfile: Bool
    @Binding var showNotifications: Bool
    @Binding var showSocialHub: Bool
    var avatarData: String?
    
    var body: some View {
        HStack {
            Button(action: { showNotifications = true }) {
                Circle().fill(.ultraThinMaterial).frame(width: 44, height: 44)
                    .overlay(ZStack(alignment: .topTrailing) {
                        Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(.black.opacity(0.7))
                        Circle().fill(Color.orange).frame(width: 10, height: 10).offset(x: 2, y: -2)
                    })
            }
            Spacer()
            Button(action: { showSocialHub = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                    Text("Kết nối").font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.black).padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(.ultraThinMaterial))
            }
            Spacer()
            // Empty spacer to balance layout
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
    }
}
