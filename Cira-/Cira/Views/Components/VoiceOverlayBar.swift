//
//  VoiceOverlayBar.swift
//  Cira
//
//  Voice bar overlay - Clean white blur style
//  Like Instagram voice message or Locket
//

import SwiftUI

struct VoiceOverlayBar: View {
    let voiceNote: Post.VoiceItem
    @Binding var isPlaying: Bool
    @State private var progress: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button(action: { 
                withAnimation(.spring(response: 0.3)) {
                    isPlaying.toggle()
                }
            }) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            
            // Waveform
            WaveformView(
                levels: voiceNote.waveformLevels,
                progress: progress,
                activeColor: .black,
                inactiveColor: .gray.opacity(0.3)
            )
            .frame(height: 28)
            
            // Duration
            Text(voiceNote.formattedDuration)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }
}

// MARK: - Waveform View
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
