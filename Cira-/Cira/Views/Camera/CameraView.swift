//
//  CameraView.swift
//  Cira
//

import SwiftUI
import PhotosUI
import SwiftData
import AVFoundation
import AVKit

// Standardize Camera State
enum CameraState {
    case preview
    case captured
}

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var cameraState: CameraState = .preview
    @State private var messageText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showChapterPicker = false
    @State private var zoomLevel: CGFloat = 1.0
    
    var showCloseButton: Bool = false
    
    let screenSize: CGSize
    let safeArea: EdgeInsets
    
    var body: some View {
        // Standard Page Content
        ContentPageWrapper(screenSize: screenSize, safeArea: safeArea) {
            CameraPageContent(
                cameraManager: cameraManager,
                cameraState: $cameraState,
                messageText: $messageText,
                zoomLevel: $zoomLevel,
                cardWidth: screenSize.width,
                cardHeight: CardDimensions.calculateCardHeight(screenHeight: screenSize.height, safeArea: safeArea),
                showCloseButton: showCloseButton
            )
        } controls: {
            CameraControlsView(
                cameraManager: cameraManager,
                audioRecorder: audioRecorder,
                cameraState: $cameraState,
                selectedPhotoItem: $selectedPhotoItem,
                showChapterPicker: $showChapterPicker
            )
        }
        .onAppear { cameraManager.checkPermission(); cameraManager.startSession() }
        .onDisappear { cameraManager.stopSession() }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if newImage != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    cameraState = .captured
                }
            }
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet { chapter in
                saveToChapter(chapter)
            }
        }
    }
    
    private func saveToChapter(_ chapter: Chapter? = nil) {
        guard let image = cameraManager.capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ No image to save")
            return
        }
        
        Task {
            do {
                _ = try await PostService.shared.savePost(
                    imageData: imageData,
                    livePhotoMovieURL: cameraManager.livePhotoMovieURL,
                    voiceNoteURL: audioRecorder.recordedURL,
                    voiceDuration: audioRecorder.recordedURL != nil ? audioRecorder.recordingDuration : nil,
                    message: messageText.isEmpty ? nil : messageText,
                    chapter: chapter,
                    modelContext: modelContext
                )
                
                NotificationCenter.default.post(name: .newPostSaved, object: nil)
                
                // Clear and go back to preview
                audioRecorder.deleteRecording()
                cameraManager.clearCapturedImage()
                messageText = ""
                withAnimation { cameraState = .preview }
                
            } catch {
                print("❌ Failed to save post: \(error)")
            }
        }
    }
}

// MARK: - Camera Page Content
struct CameraPageContent: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var cameraState: CameraState
    @Binding var messageText: String
    @Binding var zoomLevel: CGFloat
    
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var showCloseButton: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    private let goldenOrange = Color(red: 1.0, green: 0.75, blue: 0.0)
    
    var body: some View {
        ZStack {
            if cameraState == .preview {
                ZStack {
                    if cameraManager.permissionGranted {
                        CameraPreviewView(session: cameraManager.session)
                            .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous))
                            .overlay(alignment: .top) { previewTopOverlay }
                    } else {
                        RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.1))
                    }
                }
            } else if let image = cameraManager.capturedImage {
                // Captured state: image contained within card + black border
                ZStack(alignment: .bottom) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                    
                    // Message input at bottom of card
                    TextField("Thêm lời nhắn", text: $messageText)
                        .padding(12)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous)
                        .stroke(Color.black, lineWidth: 3)
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .overlay(
            Group {
                if cameraState == .preview {
                    RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 0.5)
                }
            }
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }
    
    private var previewTopOverlay: some View {
        HStack {
            if showCloseButton {
                Button(action: { dismiss() }) {
                    Circle().fill(Color.black.opacity(0.4)).frame(width: 44, height: 44)
                        .overlay(Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white))
                }
            }
            Spacer()
            Button(action: { cameraManager.toggleFlash() }) {
                Circle().fill(Color.black.opacity(0.4)).frame(width: 44, height: 44)
                    .overlay(Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .foregroundStyle(cameraManager.isFlashOn ? goldenOrange : .white))
            }
            Button(action: { zoomLevel = zoomLevel == 1.0 ? 2.0 : 1.0; cameraManager.setZoom(level: zoomLevel) }) {
                Circle().fill(Color.black.opacity(0.4)).frame(width: 44, height: 44)
                    .overlay(Text("\(Int(zoomLevel))x").font(.system(size: 14, weight: .bold)).foregroundStyle(.white))
            }
        }
        .padding(16)
    }
}

// MARK: - Camera Controls
struct CameraControlsView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var audioRecorder: AudioRecorder
    @Binding var cameraState: CameraState
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showChapterPicker: Bool
    
    private let goldenOrange = Color(red: 1.0, green: 0.75, blue: 0.0)
    
    var body: some View {
        Group {
            if cameraState == .preview {
                HStack(spacing: 60) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo.stack").font(.title2).foregroundStyle(.black)
                    }
                    .tint(.black)
                    
                    Button(action: { cameraManager.capturePhoto() }) {
                        Circle().stroke(goldenOrange, lineWidth: 4).frame(width: 80, height: 80)
                            .overlay(Circle().fill(goldenOrange.opacity(0.2)).frame(width: 68, height: 68))
                    }
                    
                    Button(action: { cameraManager.toggleCamera() }) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.title2).foregroundStyle(.black)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    // Main action buttons
                    HStack(spacing: 40) {
                        // Close button - bold black icon
                        Button(action: { 
                            audioRecorder.deleteRecording()
                            cameraManager.clearCapturedImage()
                            withAnimation { cameraState = .preview }
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Color.gray.opacity(0.1)))
                        }
                        
                        // Send button - white fill, gold icon, gold border with gap
                        Button(action: { showChapterPicker = true }) {
                            Circle()
                                .fill(.white)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(goldenOrange)
                                )
                                .padding(6)
                                .overlay(
                                    Circle().stroke(goldenOrange, lineWidth: 3)
                                )
                        }
                        
                        // Voice button — changes based on recording state
                        if audioRecorder.isRecording {
                            // STATE 2: Recording — show stop
                            Button(action: { audioRecorder.stopRecording() }) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(Color.red))
                            }
                        } else if audioRecorder.recordedURL != nil {
                            // STATE 3: Has recording — show play button
                            Button(action: { audioRecorder.togglePlayback() }) {
                                Image(systemName: audioRecorder.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(.black))
                            }
                        } else {
                            // STATE 1: No recording — show mic
                            Button(action: { audioRecorder.startRecording() }) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(Color.gray.opacity(0.1)))
                            }
                        }
                    }
                    
                    // Mini voice info bar (shown when has recording or recording)
                    if audioRecorder.isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 8, height: 8)
                            Text("Đang ghi \(audioRecorder.formatDuration(audioRecorder.recordingDuration))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red)
                                .monospacedDigit()
                        }
                        .transition(.opacity)
                    } else if audioRecorder.recordedURL != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(audioRecorder.formatDuration(audioRecorder.recordingDuration))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            
                            Button(action: { audioRecorder.deleteRecording() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: audioRecorder.isRecording)
                .animation(.easeInOut(duration: 0.2), value: audioRecorder.recordedURL != nil)
            }
        }
    }
}

