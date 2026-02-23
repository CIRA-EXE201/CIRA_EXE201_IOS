//
//  SplashView.swift
//  Cira
//
//  Login screen with logo and Google Sign-In
//

import SwiftUI
import Supabase

enum AppDestination {
    case loading
    case login
    case profileSetup
    case home
}

struct SplashView: View {
    @State private var isAnimating = false
    @State private var destination: AppDestination = .loading
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        switch destination {
        case .loading:
            loadingView
        case .login:
            loginView
        case .profileSetup:
            ProfileSetupView()
        case .home:
            ContentView()
        }
    }
    
    private var loadingView: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                Text("Preserve memories with your voice")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                
                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            checkAuthState()
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private var loginView: some View {
        ZStack {
            // Background - pure white
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                // App tagline
                Text("Preserve memories with your voice")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                Spacer()
                
                // Google Sign-In Button
                Button {
                    signInWithGoogle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("Continue with Google")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                    )
                }
                .disabled(isLoading)
                .opacity(isAnimating ? 1.0 : 0.0)
                .padding(.horizontal, 32)
                
                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                
                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            // Animate logo appearance
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private func checkAuthState() {
        Task {
            // Check for existing session
            guard SupabaseManager.shared.isAuthenticated,
                  let userId = SupabaseManager.shared.currentUser?.id else {
                withAnimation {
                    destination = .login
                }
                return
            }
            
            // Check if profile has username
            do {
                let profile: Profile? = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("username")
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                withAnimation {
                    if let profile, profile.username != nil {
                        destination = .home
                    } else {
                        destination = .profileSetup
                    }
                }
            } catch {
                // Profile doesn't exist yet, go to setup
                withAnimation {
                    destination = .profileSetup
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.signInWithGoogle()
                // After sign in, check profile
                await checkProfileAndNavigate()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func checkProfileAndNavigate() async {
        guard let userId = SupabaseManager.shared.currentUser?.id else {
            destination = .profileSetup
            return
        }
        
        do {
            let profile: Profile? = try await SupabaseManager.shared.client
                .from("profiles")
                .select("username")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            withAnimation {
                if let profile, profile.username != nil {
                    destination = .home
                } else {
                    destination = .profileSetup
                }
            }
        } catch {
            // Profile doesn't exist, go to setup
            withAnimation {
                destination = .profileSetup
            }
        }
    }
}

// MARK: - Profile Model for Decoding
struct Profile: Decodable {
    let username: String?
}

#Preview {
    SplashView()
}
