//
//  VoiceOverlayBar.swift
//  Cira
//
//  Compact voice player with waveform visualization
//  Overlay usage on post cards
//

import SwiftUI

struct VoiceOverlayBar: View {
    let voiceNote: Post.VoiceItem
    @Binding var isPlaying: Bool
    @StateObject private var player = VoicePlayer()
    
    private let barCount = 50
    
    var body: some View {
        HStack(spacing: 8) {
            // Play/Pause button
            Button(action: { 
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    player.toggle()
                }
            }) {
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                    }
            }
            .accessibilityLabel(player.isPlaying ? "Tạm dừng" : "Phát")
            
            // Waveform
            GeometryReader { geo in
                let interpolatedLevels = interpolateWaveform(
                    source: voiceNote.waveformLevels,
                    targetCount: barCount
                )
                
                HStack(spacing: 1) {
                    ForEach(0..<interpolatedLevels.count, id: \.self) { index in
                        let barProgress = Double(index) / Double(interpolatedLevels.count)
                        let isActive = barProgress <= player.playbackProgress
                        
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(isActive ? Color.white : Color.white.opacity(0.35))
                            .frame(width: 1, height: geo.size.height * CGFloat(max(0.15, interpolatedLevels[index])))
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
            .frame(height: 18)
            
            // Duration
            Text(player.isPlaying ? formatTime(player.playbackProgress * voiceNote.duration) : voiceNote.formattedDuration)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.black.opacity(0.45))
                .overlay(
                    Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
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
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    /// Interpolates source waveform levels to fill exactly `targetCount` bars
    private func interpolateWaveform(source: [Float], targetCount: Int) -> [Float] {
        guard !source.isEmpty else {
            return Array(repeating: 0.3, count: targetCount)
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
                    
                    RoundedRectangle(cornerRadius: 2)
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: 40 * CGFloat(max(0.2, level)))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        
        VoiceOverlayBar(
            voiceNote: Post.VoiceItem(
                duration: 15,
                audioURL: nil,
                waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.5, 0.3, 0.6, 0.8, 0.5, 0.4, 0.7]
            ),
            isPlaying: .constant(false)
        )
        .padding()
    }
}
