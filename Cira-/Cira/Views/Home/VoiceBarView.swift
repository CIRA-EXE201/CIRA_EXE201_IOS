//
//  VoiceBarView.swift
//  Cira
//
//  Voice playback bar for posts
//

import SwiftUI

struct VoiceBarView: View {
    let voiceNote: Post.VoiceItem
    @StateObject private var player = VoicePlayer()
    
    var body: some View {
        HStack(spacing: 10) {
            // Play/Pause button
            Button(action: { player.toggle() }) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
            }
            
            // Progress bar with waveform
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background waveform
                    HStack(spacing: 2) {
                        ForEach(0..<min(voiceNote.waveformLevels.count, 30), id: \.self) { index in
                            let level = index < voiceNote.waveformLevels.count ? voiceNote.waveformLevels[index] : 0.5
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 3, height: max(8, CGFloat(level) * 24))
                        }
                        
                        // Fill remaining space with random bars if needed
                        if voiceNote.waveformLevels.count < 30 {
                            ForEach(voiceNote.waveformLevels.count..<30, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 3, height: CGFloat.random(in: 8...20))
                            }
                        }
                    }
                    
                    // Progress overlay
                    HStack(spacing: 2) {
                        ForEach(0..<min(voiceNote.waveformLevels.count, 30), id: \.self) { index in
                            let level = index < voiceNote.waveformLevels.count ? voiceNote.waveformLevels[index] : 0.5
                            let barProgress = Double(index) / 30.0
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(barProgress < player.playbackProgress ? Color.black : Color.clear)
                                .frame(width: 3, height: max(8, CGFloat(level) * 24))
                        }
                        
                        if voiceNote.waveformLevels.count < 30 {
                            ForEach(voiceNote.waveformLevels.count..<30, id: \.self) { index in
                                let barProgress = Double(index) / 30.0
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(barProgress < player.playbackProgress ? Color.black : Color.clear)
                                    .frame(width: 3, height: CGFloat.random(in: 8...20))
                            }
                        }
                    }
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            player.seek(to: progress)
                        }
                )
            }
            .frame(height: 24)
            
            Spacer()
            
            // Duration
            Text(voiceNote.formattedDuration)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
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
}

#Preview {
    VoiceBarView(voiceNote: Post.VoiceItem(
        duration: 15,
        audioURL: nil,
        waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.5, 0.3, 0.6, 0.8, 0.5]
    ))
    .padding()
}
