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
    @State private var zoomLevel: CGFloat = 1.0
    
    // Post destination (replaces ChapterPickerSheet)
    @State private var selectedDestination: PostDestination = .singlePost
    @State private var showCreateChapter = false
    @State private var isSending = false
    
    var showCloseButton: Bool = false
    
    let screenSize: CGSize
    let safeArea: EdgeInsets
    var scrollState: HomeScrollState? = nil
    
    var body: some View {
        Group {
            if cameraState == .captured {
                // === CAPTURED STATE: custom layout with slider between image & buttons ===
                CapturedStateLayout(
                    cameraManager: cameraManager,
                    audioRecorder: audioRecorder,
                    cameraState: $cameraState,
                    messageText: $messageText,
                    selectedDestination: $selectedDestination,
                    isSending: $isSending,
                    screenSize: screenSize,
                    safeArea: safeArea,
                    onSend: { handleSend() }
                )
            } else {
                // === PREVIEW STATE: normal ContentPageWrapper ===
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
                    VStack(spacing: 8) {
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
                        
                        ScrollDownHint()
                    }
                }
            }
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
        .sheet(isPresented: $showCreateChapter) {
            CreateChapterSheet { chapter in
                selectedDestination = .existingChapter(chapter)
                handleSend()
            }
        }
        .onChange(of: cameraState) { _, newState in
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollState?.isCameraCaptured = (newState == .captured)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem = newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        cameraManager.capturedImage = uiImage
                        selectedPhotoItem = nil
                    }
                } else {
                    print("❌ Failed to load image from photo picker")
                    await MainActor.run { selectedPhotoItem = nil }
                }
            }
        }
    }
    
    private let goldenOrange = Color(red: 1.0, green: 0.75, blue: 0.0)
    
    private func handleSend() {
        switch selectedDestination {
        case .singlePost:
            savePost(chapter: nil)
        case .newChapter:
            showCreateChapter = true
        case .existingChapter(let chapter):
            savePost(chapter: chapter)
        }
    }
    
    private func savePost(chapter: Chapter? = nil) {
        guard let image = cameraManager.capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ No image to save")
            return
        }
        
        isSending = true
        
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
                selectedDestination = .singlePost
                isSending = false
                withAnimation { cameraState = .preview }
                
            } catch {
                print("❌ Failed to save post: \(error)")
                isSending = false
            }
        }
    }
}

// MARK: - Captured State Layout (image smaller + slider + buttons)
private struct CapturedStateLayout: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var audioRecorder: AudioRecorder
    @Binding var cameraState: CameraState
    @Binding var messageText: String
    @Binding var selectedDestination: PostDestination
    @Binding var isSending: Bool
    
    let screenSize: CGSize
    let safeArea: EdgeInsets
    let onSend: () -> Void
    
    @Query(sort: \Chapter.updatedAt, order: .reverse) private var chapters: [Chapter]
    
    private let goldenOrange = Color(red: 1.0, green: 0.75, blue: 0.0)
    
    private var topAreaH: CGFloat { CardDimensions.topAreaHeight(safeArea: safeArea) }
    
    private var cardWidth: CGFloat { screenSize.width }
    // Same card height as normal preview — no shrinking
    private var cardH: CGFloat {
        CardDimensions.calculateCardHeight(screenHeight: screenSize.height, safeArea: safeArea)
    }
    
    private var centeringSpacerH: CGFloat {
        let totalContentH = cardH + CardDimensions.standardGap + CardDimensions.interactionHeight
        let availableH = screenSize.height - topAreaH - CardDimensions.bottomAreaHeight(safeArea: safeArea)
        let centerPadding = max((availableH - totalContentH) / 2, 0)
        return centerPadding + CardDimensions.verticalShift
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Same top spacing as ContentPageWrapper
            Color.clear.frame(height: topAreaH)
            Color.clear.frame(height: centeringSpacerH)
            
            // Image card — full size, same as preview
            capturedImageCard
                .frame(width: cardWidth, height: cardH)
            
            Color.clear.frame(height: CardDimensions.standardGap)
            
            // Action buttons
            VStack(spacing: 4) {
                actionButtons
                voiceInfoBar
            }
            .frame(height: CardDimensions.interactionHeight, alignment: .top)
            
            // Slider — sits right after buttons, in freed tab bar space
            PostDestinationSlider(
                chapters: chapters,
                selectedDestination: $selectedDestination
            )
            .frame(height: 76)
            .padding(.horizontal, 16)
            .padding(.top, -8)
            .zIndex(10)
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Captured Image Card
    private var capturedImageCard: some View {
        ZStack(alignment: .bottom) {
            if let image = cameraManager.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardH)
                    .clipped()
                
                // Message input at bottom of card
                TextField("Thêm lời nhắn", text: $messageText)
                    .padding(12)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CardDimensions.cornerRadius, style: .continuous)
                .stroke(Color.black, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, 0)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 36) {
            // Trash / cancel
            Button(action: {
                audioRecorder.deleteRecording()
                cameraManager.clearCapturedImage()
                withAnimation { cameraState = .preview }
            }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }
            
            // Send button
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Group {
                                if isSending {
                                    ProgressView().tint(goldenOrange)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(goldenOrange)
                                }
                            }
                        )
                        .padding(4)
                        .overlay(Circle().stroke(goldenOrange, lineWidth: 3))
                }
            }
            .disabled(isSending)
            
            // Voice button
            voiceButton
        }
    }
    
    // MARK: - Voice Button
    @ViewBuilder
    private var voiceButton: some View {
        if audioRecorder.isRecording {
            Button(action: { audioRecorder.stopRecording() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.red))
            }
        } else if audioRecorder.recordedURL != nil {
            Button(action: { audioRecorder.togglePlayback() }) {
                Image(systemName: audioRecorder.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.black))
            }
        } else {
            Button(action: { audioRecorder.startRecording() }) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }
        }
    }
    
    // MARK: - Voice Info Bar
    @ViewBuilder
    private var voiceInfoBar: some View {
        if audioRecorder.isRecording {
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("Đang ghi \(audioRecorder.formatDuration(audioRecorder.recordingDuration))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
                    .monospacedDigit()
            }
            .padding(.top, 6)
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
            .padding(.top, 6)
            .transition(.opacity)
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
