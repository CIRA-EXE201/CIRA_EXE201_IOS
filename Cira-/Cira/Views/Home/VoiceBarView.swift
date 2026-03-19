//
//  VoiceBarView.swift
//  Cira
//
//  Compact voice playback bar for posts
//  Modern waveform design with smooth animations
//

import SwiftUI

struct VoiceBarView: View {
    let voiceNote: Post.VoiceItem
    @StateObject private var player = VoicePlayer()
    
    // Waveform config
    private let barCount = 36
    private let barWidth: CGFloat = 3
    private let maxBarHeight: CGFloat = 28
    private let minBarHeight: CGFloat = 4
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            playButton
            
            // Waveform
            waveformView
            
            // Time display
            timeLabel
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        )
        .padding(.horizontal, 20)
        .onAppear {
            if let url = voiceNote.audioURL {
                player.load(url: url)
            }
        }
        .onDisappear {
            player.stop()
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
                    .fill(Color.black)
                    .frame(width: 38, height: 38)
                
                // Subtle pulse ring when playing
                if player.isPlaying {
                    Circle()
                        .stroke(Color.black.opacity(0.15), lineWidth: 2)
                        .frame(width: 38, height: 38)
                        .scaleEffect(player.isPlaying ? 1.35 : 1.0)
                        .opacity(player.isPlaying ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false),
                            value: player.isPlaying
                        )
                }
                
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: player.isPlaying ? 0 : 1) // Optical center for play icon
                    .contentTransition(.symbolEffect(.replace.downUp))
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(player.isPlaying ? "Tạm dừng" : "Phát giọng nói")
    }
    
    // MARK: - Waveform
    private var waveformView: some View {
        GeometryReader { geometry in
            let bars = interpolatedWaveform(targetCount: barCount)
            let totalBarWidth = CGFloat(barCount) * barWidth
            let totalSpacing = geometry.size.width - totalBarWidth
            let spacing = max(1.5, totalSpacing / CGFloat(barCount - 1))
            
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let level = bars[index]
                    let barProgress = Double(index) / Double(barCount)
                    let isPlayed = barProgress < player.playbackProgress
                    
                    Capsule()
                        .fill(isPlayed
                              ? Color.black
                              : Color(.systemGray4))
                        .frame(
                            width: barWidth,
                            height: max(minBarHeight, CGFloat(level) * maxBarHeight)
                        )
                        .animation(
                            .easeInOut(duration: 0.15),
                            value: isPlayed
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
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
                    .foregroundStyle(.primary)
            } else {
                Text(voiceNote.formattedDuration)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .frame(minWidth: 32, alignment: .trailing)
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.2), value: player.isPlaying)
    }
    
    // MARK: - Interpolate waveform
    private func interpolatedWaveform(targetCount: Int) -> [Float] {
        let source = voiceNote.waveformLevels
        guard !source.isEmpty else {
            // No waveform data: generate organic-looking bars
            return (0..<targetCount).map { i in
                let base = sin(Float(i) * 0.4) * 0.3 + 0.35
                return base + Float.random(in: -0.08...0.08)
            }
        }
        
        if source.count == 1 {
            return Array(repeating: source[0], count: targetCount)
        }
        
        var result: [Float] = []
        for i in 0..<targetCount {
            let position = Float(i) / Float(targetCount - 1) * Float(source.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, source.count - 1)
            let fraction = position - Float(lower)
            let value = source[lower] * (1 - fraction) + source[upper] * fraction
            result.append(value)
        }
        return result
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Scale Button Style
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceBarView(voiceNote: Post.VoiceItem(
            duration: 15,
            audioURL: nil,
            waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.5, 0.3, 0.6, 0.8, 0.5]
        ))
        
        VoiceBarView(voiceNote: Post.VoiceItem(
            duration: 5,
            audioURL: nil,
            waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9]
        ))
        
        // No waveform data
        VoiceBarView(voiceNote: Post.VoiceItem(
            duration: 8,
            audioURL: nil,
            waveformLevels: []
        ))
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
