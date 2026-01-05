//
//  SplashView.swift
//  Cira
//
//  Loading screen with animated logo
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showApp = false
    
    var body: some View {
        if showApp {
            ContentView()
        } else {
            ZStack {
                // Background - pure white
                Color.white
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
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
                }
            }
            .onAppear {
                // Animate logo appearance
                withAnimation(.easeOut(duration: 0.8)) {
                    isAnimating = true
                }
                
                // Transition to main app after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showApp = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
