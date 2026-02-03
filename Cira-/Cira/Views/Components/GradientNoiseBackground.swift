//
//  GradientNoiseBackground.swift
//  Cira
//
//  White background with gradient, blur and noise effect
//

import SwiftUI

struct GradientNoiseBackground: View {
    var body: some View {
        ZStack {
            // Base white color
            Color.white
            
            // Gradient overlay - soft pastel colors
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 1.0),    // Soft lavender
                    Color(red: 1.0, green: 0.98, blue: 0.95),    // Warm cream
                    Color(red: 0.95, green: 0.98, blue: 1.0),    // Light blue
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.8)
            
            // Secondary gradient for depth
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.85).opacity(0.4),  // Peach glow
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )
            
            // Noise/grain texture overlay
            NoiseView()
                .opacity(0.03)
                .blendMode(.multiply)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Noise Texture View
struct NoiseView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Generate noise pattern
                for _ in 0..<Int(size.width * size.height * 0.05) {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let gray = CGFloat.random(in: 0...1)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(Color(white: gray))
                    )
                }
            }
        }
    }
}

// MARK: - Alternative: Blur Glass Background
struct BlurGlassBackground: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.98),
                    Color(red: 0.98, green: 0.96, blue: 0.94),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Blur effect circles
            Circle()
                .fill(Color(red: 1.0, green: 0.85, blue: 0.75).opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color(red: 0.85, green: 0.9, blue: 1.0).opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 100)
            
            Circle()
                .fill(Color(red: 0.95, green: 0.85, blue: 0.95).opacity(0.25))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -50, y: 300)
        }
        .ignoresSafeArea()
    }
}

#Preview("Gradient Noise") {
    GradientNoiseBackground()
}

#Preview("Blur Glass") {
    BlurGlassBackground()
}
