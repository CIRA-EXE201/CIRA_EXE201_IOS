//
//  VoiceBarView.swift
//  Cira
//
//  Compact voice playback bar for posts
//  Waveform always fills the full width regardless of voice duration
//

import SwiftUI

struct VoiceBarView: View {
    let voiceNote: Post.VoiceItem
    @StateObject private var player = VoicePlayer()
    
    // Number of waveform bars to always display
    private let barCount = 40
    
    var body: some View {
        HStack(spacing: 8) {
            // Play/Pause button - compact
            Button(action: { player.toggle() }) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            
            // Waveform - always fills available width
            GeometryReader { geometry in
                let bars = interpolatedWaveform(targetCount: barCount)
                let barWidth: CGFloat = 2.5
                let totalBarWidth = CGFloat(barCount) * barWidth
                let totalSpacing = geometry.size.width - totalBarWidth
                let spacing = max(1, totalSpacing / CGFloat(barCount - 1))
                
                HStack(spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let level = bars[index]
                        let barProgress = Double(index) / Double(barCount)
                        let isPlayed = barProgress < player.playbackProgress
                        
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(isPlayed ? Color.black : Color.gray.opacity(0.3))
                            .frame(width: barWidth, height: max(4, CGFloat(level) * 18))
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
            .frame(height: 18)
            
            // Duration / Current time - compact
            Text(player.isPlaying ? formatTime(player.playbackProgress * voiceNote.duration) : voiceNote.formattedDuration)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 30, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
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
    
    // MARK: - Interpolate waveform to always fill bar count
    /// Takes the original waveform levels (any count) and produces exactly `targetCount` bars
    /// by interpolating the source data evenly across the target range.
    private func interpolatedWaveform(targetCount: Int) -> [Float] {
        let source = voiceNote.waveformLevels
        guard !source.isEmpty else {
            // No waveform data: generate subtle random bars
            return (0..<targetCount).map { _ in Float.random(in: 0.2...0.5) }
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

#Preview {
    VoiceBarView(voiceNote: Post.VoiceItem(
        duration: 5,
        audioURL: nil,
        waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9]
    ))
    .padding()
}
