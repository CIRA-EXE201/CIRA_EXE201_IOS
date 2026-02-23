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
                cardHeight: CardDimensions.calculateCardHeight(screenHeight: screenSize.height, safeArea: safeArea)
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous))
                
                VStack {
                    Spacer()
                    TextField("Add a message", text: $messageText)
                        .padding(12)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(16)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .overlay(
            RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }
    
    private var previewTopOverlay: some View {
        HStack {
            Button(action: { cameraManager.toggleFlash() }) {
                Circle().fill(Color.black.opacity(0.4)).frame(width: 44, height: 44)
                    .overlay(Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .foregroundStyle(cameraManager.isFlashOn ? goldenOrange : .white))
            }
            Spacer()
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
                        Image(systemName: "photo.stack").font(.title2).foregroundStyle(.primary)
                    }
                    
                    Button(action: { cameraManager.capturePhoto() }) {
                        Circle().stroke(goldenOrange, lineWidth: 4).frame(width: 80, height: 80)
                            .overlay(Circle().fill(goldenOrange.opacity(0.2)).frame(width: 68, height: 68))
                    }
                    
                    Button(action: { cameraManager.toggleCamera() }) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.title2).foregroundStyle(.primary)
                    }
                }
            } else {
                HStack(spacing: 40) {
                    Button(action: { 
                        cameraManager.clearCapturedImage()
                        withAnimation { cameraState = .preview }
                    }) {
                        Image(systemName: "xmark").font(.title2).frame(width: 56, height: 56).background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    Button(action: { showChapterPicker = true }) {
                        Circle().fill(goldenOrange).frame(width: 80, height: 80)
                            .overlay(Image(systemName: "paperplane.fill").font(.title).foregroundStyle(.white))
                    }
                    
                    Button(action: { audioRecorder.toggleRecording() }) {
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title2).frame(width: 56, height: 56)
                            .background(Circle().fill(audioRecorder.isRecording ? Color.red : Color.gray.opacity(0.2)))
                    }
                }
            }
        }
    }
}

