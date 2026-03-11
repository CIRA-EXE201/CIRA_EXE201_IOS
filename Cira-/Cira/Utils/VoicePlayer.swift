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
        
        // Validate URL - must be either a real local file or an HTTP URL
        if url.isFileURL {
            // Local file — check existence
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⚠️ Audio file not found at: \(url.path)")
                return
            }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                setupPlayer()
            } catch {
                print("❌ Failed to load local audio: \(error)")
                self.errorMessage = "Cannot load local audio"
            }
        } else if let scheme = url.scheme, (scheme == "http" || scheme == "https") {
            // Download audio data and save to temp file (AVAudioPlayer needs file extension for format detection)
            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
                    // Debug: log download info
                    let httpResponse = response as? HTTPURLResponse
                    let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
                    let statusCode = httpResponse?.statusCode ?? -1
                    let preview = String(data: data.prefix(100), encoding: .utf8) ?? "binary"
                    print("🔊 Audio download: \(data.count) bytes, status: \(statusCode), type: \(contentType)")
                    print("🔊 First bytes: \(preview)")
                    
                    // Save to temp file with .m4a extension so AVAudioPlayer can detect format
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("voice_\(UUID().uuidString).m4a")
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        guard self.currentURL == url else {
                            try? FileManager.default.removeItem(at: tempURL)
                            return
                        }
                        
                        do {
                            self.audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
                            self.setupPlayer()
                            
                            if self.isPlaying {
                                self.playFromSession()
                            }
                        } catch {
                            print("❌ Failed to play downloaded audio: \(error)")
                            self.errorMessage = "Cannot play audio"
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
        } else {
            // Invalid URL (e.g. relative storage path without scheme)
            print("⚠️ Skipping invalid audio URL (not file/http): \(url)")
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
        
        // Configure audio session - use .playAndRecord to avoid conflict with camera
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
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
