//
//  VoicePlayer.swift
//  Cira
//
//  Audio player for voice notes playback
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
class VoicePlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var currentURL: URL?
    
    override init() {
        super.init()
    }
    
    // MARK: - Load Audio
    func load(url: URL) {
        stop()
        currentURL = url
        
        if url.isFileURL {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                setupPlayer()
            } catch {
                print("❌ Failed to load local audio: \(error)")
                self.errorMessage = "Cannot load local audio"
            }
        } else {
            // Download audio data asynchronously
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    await MainActor.run {
                        // Check if the URL hasn't changed while downloading
                        guard self.currentURL == url else { return }
                        
                        do {
                            self.audioPlayer = try AVAudioPlayer(data: data)
                            self.setupPlayer()
                            
                            // Auto-play if play was pressed while loading
                            if self.isPlaying {
                                self.playFromSession()
                            }
                        } catch {
                            print("❌ Failed to play downloaded audio data: \(error)")
                            self.errorMessage = "Cannot play downloaded audio"
                            self.isPlaying = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        guard self.currentURL == url else { return }
                        print("❌ Failed to download audio URL: \(error)")
                        self.errorMessage = "Cannot download audio"
                        self.isPlaying = false
                    }
                }
            }
        }
    }
    
    private func setupPlayer() {
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
    }
    
    // MARK: - Play
    func play() {
        if audioPlayer == nil {
            isPlaying = true // Indicate intent to play once loaded
            if let url = currentURL {
                load(url: url)
            }
            return
        }
        
        playFromSession()
    }
    
    private func playFromSession() {
        guard let player = audioPlayer else { return }
        
        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
            return
        }
        
        player.play()
        isPlaying = true
        
        // Start progress timer
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer, player.duration > 0 else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }
    
    // MARK: - Pause
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - Stop
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - Toggle Play/Pause
    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    // MARK: - Seek
    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = progress * player.duration
        playbackProgress = progress
    }
    
    // MARK: - Format Duration
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate
extension VoicePlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playbackProgress = 0
            self.playbackTimer?.invalidate()
            self.playbackTimer = nil
            
            // Deactivate audio session
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("⚠️ Could not deactivate audio session")
            }
        }
    }
}
