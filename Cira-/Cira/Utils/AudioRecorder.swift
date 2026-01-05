//
//  AudioRecorder.swift
//  Cira
//
//  Audio recorder for voice notes
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    // Published properties
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordedURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var permissionGranted = false
    @Published var errorMessage: String?
    
    // Audio components
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Check Permission
    func checkPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            permissionGranted = true
        case .denied:
            permissionGranted = false
            errorMessage = "Microphone permission not granted"
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.permissionGranted = granted
                    if !granted {
                        self?.errorMessage = "Microphone permission not granted"
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Start Recording
    func startRecording() {
        guard permissionGranted else {
            errorMessage = "Microphone permission required to record"
            return
        }
        
        // Stop any existing playback
        stopPlaying()
        
        // Configure audio session for recording
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
            errorMessage = "Cannot initialize audio session"
            return
        }
        
        // Create recording URL
        let fileName = UUID().uuidString + ".m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            recordedURL = url
            recordingDuration = 0
            
            // Start timer to track duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDuration = self?.audioRecorder?.currentTime ?? 0
                }
            }
            
            print("🎙️ Recording started: \(url)")
        } catch {
            print("❌ Recording error: \(error)")
            errorMessage = "Cannot start recording"
        }
    }
    
    // MARK: - Stop Recording
    func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("⚠️ Could not deactivate audio session: \(error)")
        }
        
        print("🎙️ Recording stopped. Duration: \(String(format: "%.1f", recordingDuration))s")
    }
    
    // MARK: - Start Playing
    func startPlaying() {
        guard let url = recordedURL else {
            errorMessage = "No recording available"
            return
        }
        
        // Stop recording if still recording
        if isRecording {
            stopRecording()
        }
        
        // Configure audio session for playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("❌ Audio session error: \(error)")
            errorMessage = "Cannot initialize audio session"
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            isPlaying = true
            playbackProgress = 0
            
            // Start timer to track progress
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let player = self?.audioPlayer, player.duration > 0 else { return }
                    self?.playbackProgress = player.currentTime / player.duration
                }
            }
            
            print("▶️ Playback started")
        } catch {
            print("❌ Playback error: \(error)")
            errorMessage = "Cannot play recording"
        }
    }
    
    // MARK: - Stop Playing
    func stopPlaying() {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackProgress = 0
        
        print("⏹️ Playback stopped")
    }
    
    // MARK: - Toggle Recording
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - Toggle Playback
    func togglePlayback() {
        if isPlaying {
            stopPlaying()
        } else {
            startPlaying()
        }
    }
    
    // MARK: - Delete Recording
    func deleteRecording() {
        stopPlaying()
        stopRecording()
        
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ Recording deleted")
        }
        
        recordedURL = nil
        recordingDuration = 0
        playbackProgress = 0
    }
    
    // MARK: - Format Duration
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d.%d", seconds, milliseconds)
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                print("✅ Recording finished successfully")
            } else {
                print("❌ Recording failed")
                self.errorMessage = "Recording failed"
            }
            self.isRecording = false
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("❌ Recording encode error: \(error?.localizedDescription ?? "unknown")")
            self.errorMessage = "Recording encode error"
            self.isRecording = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            print("✅ Playback finished")
            self.isPlaying = false
            self.playbackProgress = 0
            self.playbackTimer?.invalidate()
            self.playbackTimer = nil
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ Playback decode error: \(error?.localizedDescription ?? "unknown")")
            self.errorMessage = "Audio playback error"
            self.isPlaying = false
        }
    }
}
