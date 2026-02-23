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
    
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showSocialHub = false
    @State private var dragOffset: CGFloat = 0
    @State private var globalSafeArea: EdgeInsets = .init()
    
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
                let fullScreenSize = geometry.size
                let safeArea = globalSafeArea // Use captured safe area
                let currentOffset = (showProfile ? 0 : -fullScreenSize.width) + dragOffset
            
            HStack(spacing: 0) {
                // LEFT: Profile Panel
                ProfileView(safeArea: safeArea, onClose: { withAnimation(.spring()) { showProfile = false } })
                    .frame(width: fullScreenSize.width)
                    .background(Color.black)
                
                // RIGHT: Main Content Stack
                ZStack {
                    // A. Seamless Global Background
                    CiraMeshBackground()
                        .ignoresSafeArea(.all)
                    
                    // B. Vertical Paging Scroll
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
                                    PostControlsView(post: post) { postId in
                                        viewModel.toggleLike(for: postId)
                                    }
                                }
                                .containerRelativeFrame(.vertical)
                                .id(post.id.uuidString)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollBounceBehavior(.basedOnSize)
                    .ignoresSafeArea(.all)
                    
                    // C. Fixed Overlays
                    VStack(spacing: 0) {
                        HomeTopBar(showProfile: $showProfile, showNotifications: $showNotifications, showSocialHub: $showSocialHub)
                            .padding(.top, safeArea.top)
                            .padding(.horizontal, 4)
                            .frame(height: CardDimensions.topAreaHeight(safeArea: safeArea))
                        
                        Spacer()
                    }
                    .allowsHitTesting(true)
                }
                .frame(width: fullScreenSize.width)
            }
            .frame(width: fullScreenSize.width * 2, alignment: .leading)
            .offset(x: currentOffset)
            .animation(.interactiveSpring(), value: currentOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        if showProfile {
                            if translation < 0 { dragOffset = translation }
                        } else {
                            if translation > 0 { dragOffset = translation }
                        }
                    }
                    .onEnded { value in
                        let threshold = fullScreenSize.width * 0.3
                        if showProfile {
                            if value.translation.width < -threshold {
                                withAnimation { showProfile = false }
                            }
                        } else {
                            if value.translation.width > threshold {
                                withAnimation { showProfile = true }
                            }
                        }
                        dragOffset = 0
                    }
            )
            }
            .ignoresSafeArea()
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
            .sheet(isPresented: $showSocialHub) {
                SocialHubView()
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
    
    var body: some View {
        HStack {
            Button(action: { withAnimation(.spring()) { showProfile = true } }) {
                Circle().fill(.ultraThinMaterial).frame(width: 44, height: 44)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.black.opacity(0.7)))
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
            Button(action: { showNotifications = true }) {
                Circle().fill(.ultraThinMaterial).frame(width: 44, height: 44)
                    .overlay(ZStack(alignment: .topTrailing) {
                        Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(.black.opacity(0.7))
                        Circle().fill(Color.orange).frame(width: 10, height: 10).offset(x: 2, y: -2)
                    })
            }
        }
        .padding(.horizontal, 16)
    }
}
