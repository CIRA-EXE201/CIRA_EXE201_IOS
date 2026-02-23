//
//  CiraTheme.swift
//  Cira
//
//  Modern Design System for Cira (Liquid Glass, Mesh Gradients, Noise)
//

import SwiftUI
import Combine

/// Cira's Master Theme Configuration
enum CiraTheme {
    // MARK: - Colors
    enum Colors {
        static let primary = Color(red: 0.1, green: 0.1, blue: 0.1) // Deep Charcoal
        static let accent = Color.blue
        
        // Mesh Gradient Palette
        static let meshPalette: [Color] = [
            Color(red: 0.98, green: 0.95, blue: 1.0),    // soft lavender
            Color(red: 1.0, green: 0.98, blue: 0.95),    // warm cream
            Color(red: 0.95, green: 0.98, blue: 1.0),    // light blue
            Color(red: 0.90, green: 0.90, blue: 1.0),    // sky
            Color(red: 1.0, green: 0.92, blue: 0.85),    // peach
            Color.white
        ]
    }
    
    // MARK: - Layout
    enum Layout {
        static let cornerRadius: CGFloat = 24
        static let cardPadding: CGFloat = 16
        static let glassBorderWidth: CGFloat = 0.5
    }
}

// MARK: - Components

/// Modern Dynamic Mesh Background
struct CiraMeshBackground: View {
    @State private var t: Float = 0.0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.5, 0.5], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        .white, .white, .white,
                        CiraTheme.Colors.meshPalette[0], CiraTheme.Colors.meshPalette[1], CiraTheme.Colors.meshPalette[2],
                        CiraTheme.Colors.meshPalette[3], CiraTheme.Colors.meshPalette[4], .white
                    ]
                )
                .ignoresSafeArea()
            } else {
                GradientNoiseBackground()
            }
            
            // Subtle Noise Overlay
            CiraNoiseOverlay()
                .opacity(0.04)
                .blendMode(.overlay)
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.1)) {
                t += 0.01
            }
        }
    }
}

/// Optimized Noise Overlay
struct CiraNoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            // Use a pre-rendered small tile if possible, or just draw
            // For now, simpler drawing
            for x in stride(from: 0, to: size.width, by: 2) {
                for y in stride(from: 0, to: size.height, by: 2) {
                    let white = Double.random(in: 0...1)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(Color(white: white))
                    )
                }
            }
        }
    }
}

/// Liquid Glass Surface
struct CiraGlassSurface<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = CiraTheme.Layout.cornerRadius
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: CiraTheme.Layout.glassBorderWidth)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - View Modifiers

extension View {
    func ciraGlassStyle(cornerRadius: CGFloat = CiraTheme.Layout.cornerRadius) -> some View {
        self.modifier(CiraGlassModifier(cornerRadius: cornerRadius))
    }
}

struct CiraGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.4), lineWidth: 0.5)
            )
    }
}
