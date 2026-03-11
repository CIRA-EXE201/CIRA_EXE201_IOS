//
//  ContentView.swift
//  Cira-
//
//  Custom tab navigation with frosted noise background
//  Tabs: Profile, Home, My Story
//

import SwiftUI
import Supabase

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showProfile = false
    @State private var userAvatarData: String? = nil
    
    enum Tab: Int, CaseIterable {
        case profile = 0
        case home = 1
        case myStory = 2
        
        var title: String {
            switch self {
            case .profile: return "Hồ sơ"
            case .home: return "Trang chủ"
            case .myStory: return "Chương"
            }
        }
        
        var icon: String {
            switch self {
            case .profile: return "person.fill"
            case .home: return "house.fill"
            case .myStory: return "book.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area — swap views based on selected tab
            Group {
                switch selectedTab {
                case .profile:
                    ProfileView(safeArea: .init()) {
                        selectedTab = .home
                    }
                case .home:
                    HomeView(showProfile: $showProfile, avatarData: userAvatarData)
                case .myStory:
                    MyStoryView(showProfile: $showProfile, avatarData: userAvatarData)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            await fetchUserAvatar()
        }
    }
    
    // MARK: - Fetch User Avatar
    private func fetchUserAvatar() async {
        guard let userId = SupabaseManager.shared.currentUser?.id else { return }
        do {
            struct SimpleProfile: Decodable { let avatar_data: String? }
            let profile: SimpleProfile = try await SupabaseManager.shared.client
                .from("profiles")
                .select("avatar_data")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.userAvatarData = profile.avatar_data
        } catch {
            print("Failed to fetch user avatar in ContentView: \(error)")
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            // Frosted white background with noise
            ZStack {
                // Base: semi-transparent white
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.75))
                
                // Noise overlay for texture/roughness
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        ShaderLibrary.default.noiseShader
                    )
                    .opacity(0.06)
                
                // Subtle top border
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
        }
        .padding(.horizontal, 100)
        .padding(.bottom, 2)
    }
    
    @ViewBuilder
    private func tabButton(_ tab: ContentView.Tab) -> some View {
        let isSelected = selectedTab == tab
        
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .black.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    // Selected pill: dark gray with inner shadow
                    Capsule()
                        .fill(Color(white: 0.25))
                        .overlay {
                            // Inner shadow (inset effect)
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            
                            Capsule()
                                .fill(
                                    .shadow(.inner(color: .black.opacity(0.4), radius: 4, x: 0, y: 3))
                                    .shadow(.inner(color: .white.opacity(0.15), radius: 2, x: 0, y: -1))
                                )
                                .foregroundStyle(Color(white: 0.25))
                        }
                        .padding(.horizontal, 4)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Noise Shader Fallback
// Since Metal ShaderLibrary may not be available, use a Canvas-based noise pattern
private extension ShaderLibrary {
    static var `default`: NoiseShaderProvider { NoiseShaderProvider() }
}

struct NoiseShaderProvider {
    var noiseShader: some ShapeStyle {
        // Generate a static noise image as a pattern fill
        ImagePaint(image: NoiseGenerator.shared.noiseImage, scale: 1.0)
    }
}

// MARK: - Noise Pattern Generator
final class NoiseGenerator {
    static let shared = NoiseGenerator()
    
    let noiseImage: Image
    
    private init() {
        let size = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let uiImage = renderer.image { ctx in
            // Fill with clear
            UIColor.clear.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            
            // Draw random noise pixels
            for x in stride(from: 0, to: size, by: 2) {
                for y in stride(from: 0, to: size, by: 2) {
                    let gray = CGFloat.random(in: 0...1)
                    UIColor(white: gray, alpha: 0.3).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
        }
        noiseImage = Image(uiImage: uiImage)
    }
}

#Preview {
    ContentView()
}
