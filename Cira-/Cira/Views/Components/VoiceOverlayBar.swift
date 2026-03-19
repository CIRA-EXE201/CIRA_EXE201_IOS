//
//  VoiceOverlayBar.swift
//  Cira
//
//  Voice player overlay on post cards
//  Glassmorphism design with smooth waveform visualization
//

import SwiftUI

struct VoiceOverlayBar: View {
    let voiceNote: Post.VoiceItem
    @Binding var isPlaying: Bool
    @StateObject private var player = VoicePlayer()
    
    // Waveform config
    private let barCount = 40
    private let barWidth: CGFloat = 2.5
    private let maxBarHeight: CGFloat = 24
    private let minBarHeight: CGFloat = 3
    
    var body: some View {
        HStack(spacing: 10) {
            // Play/Pause button
            playButton
            
            // Waveform + progress
            VStack(spacing: 4) {
                waveformView
                
                // Progress track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(height: 2)
                        
                        Capsule()
                            .fill(.white.opacity(0.8))
                            .frame(
                                width: geo.size.width * player.playbackProgress,
                                height: 2
                            )
                            .animation(.easeInOut(duration: 0.1), value: player.playbackProgress)
                    }
                }
                .frame(height: 2)
            }
            
            // Time
            timeLabel
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
        .onAppear {
            if let url = voiceNote.audioURL {
                player.load(url: url)
            }
        }
        .onDisappear {
            player.stop()
        }
        .onChange(of: player.isPlaying) { newValue in
            DispatchQueue.main.async {
                self.isPlaying = newValue
            }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue != player.isPlaying {
                player.toggle()
            }
        }
        .onChange(of: voiceNote.audioURL) { newURL in
            if let url = newURL {
                player.load(url: url)
            }
        }
    }
    
    // MARK: - Play Button
    private var playButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                player.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(width: 34, height: 34)
                
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
                    .frame(width: 34, height: 34)
                
                // Pulse ring
                if player.isPlaying {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                        .scaleEffect(player.isPlaying ? 1.4 : 1.0)
                        .opacity(player.isPlaying ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false),
                            value: player.isPlaying
                        )
                }
                
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: player.isPlaying ? 0 : 1)
                    .contentTransition(.symbolEffect(.replace.downUp))
            }
        }
        .buttonStyle(OverlayScaleButtonStyle())
        .accessibilityLabel(player.isPlaying ? "Tạm dừng" : "Phát")
    }
    
    // MARK: - Waveform
    private var waveformView: some View {
        GeometryReader { geo in
            let bars = interpolateWaveform(source: voiceNote.waveformLevels, targetCount: barCount)
            let totalBarWidth = CGFloat(barCount) * barWidth
            let totalSpacing = geo.size.width - totalBarWidth
            let spacing = max(1, totalSpacing / CGFloat(barCount - 1))
            
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let level = bars[index]
                    let barProgress = Double(index) / Double(barCount)
                    let isPlayed = barProgress <= player.playbackProgress
                    
                    Capsule()
                        .fill(isPlayed
                              ? Color.white
                              : Color.white.opacity(0.25))
                        .frame(
                            width: barWidth,
                            height: max(minBarHeight, CGFloat(level) * maxBarHeight)
                        )
                        .animation(
                            .easeInOut(duration: 0.12),
                            value: isPlayed
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(0, value.location.x / geo.size.width), 1)
                        player.seek(to: progress)
                    }
            )
        }
        .frame(height: maxBarHeight)
    }
    
    // MARK: - Time Label
    private var timeLabel: some View {
        Group {
            if player.isPlaying {
                Text(formatTime(player.playbackProgress * voiceNote.duration))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text(voiceNote.formattedDuration)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .frame(minWidth: 28, alignment: .trailing)
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.2), value: player.isPlaying)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func interpolateWaveform(source: [Float], targetCount: Int) -> [Float] {
        guard !source.isEmpty else {
            return (0..<targetCount).map { i in
                let base = sin(Float(i) * 0.4) * 0.3 + 0.35
                return base + Float.random(in: -0.08...0.08)
            }
        }
        guard source.count != targetCount else { return source }
        
        var result = [Float]()
        result.reserveCapacity(targetCount)
        
        for i in 0..<targetCount {
            let srcIndex = Float(i) / Float(targetCount - 1) * Float(source.count - 1)
            let lower = Int(srcIndex)
            let upper = min(lower + 1, source.count - 1)
            let fraction = srcIndex - Float(lower)
            let value = source[lower] * (1 - fraction) + source[upper] * fraction
            result.append(value)
        }
        return result
    }
}

// MARK: - Overlay Scale Button Style
private struct OverlayScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Waveform View (kept for other usages)
struct WaveformView: View {
    let levels: [Float]
    let progress: Double
    let activeColor: Color
    let inactiveColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    let barProgress = Double(index) / Double(levels.count)
                    let isActive = barProgress <= progress
                    
                    Capsule()
                        .fill(isActive ? activeColor : inactiveColor)
                        .frame(width: 3, height: geometry.size.height * CGFloat(max(0.2, level)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Standalone Waveform (for recording)
struct RecordingWaveformView: View {
    let levels: [Float]
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(color)
                    .frame(width: 4, height: 40 * CGFloat(max(0.2, level)))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack(spacing: 16) {
            VoiceOverlayBar(
                voiceNote: Post.VoiceItem(
                    duration: 15,
                    audioURL: nil,
                    waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.5, 0.3, 0.6, 0.8, 0.5, 0.4, 0.7]
                ),
                isPlaying: .constant(false)
            )
            .padding(.horizontal)
            
            VoiceOverlayBar(
                voiceNote: Post.VoiceItem(
                    duration: 8,
                    audioURL: nil,
                    waveformLevels: []
                ),
                isPlaying: .constant(false)
            )
            .padding(.horizontal)
        }
    }
}
