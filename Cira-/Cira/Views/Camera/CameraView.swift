//
//  CameraView.swift
//  Cira
//
//  Camera tab - Capture photos and record voice
//  Dark Theme Redesign
//

import SwiftUI
import PhotosUI
import SwiftData

// MARK: - Camera State
enum CameraState {
    case preview      // Camera preview - before capture
    case captured     // Photo captured - showing captured image
}

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var cameraState: CameraState = .preview
    @State private var showPhotoLibrary = false
    @State private var messageText = ""
    @State private var selectedChapterIndex: Int = 0
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showSavedAlert = false
    @State private var isPlayingLivePhoto = false
    @State private var isSaving = false
    @State private var showChapterPicker = false
    @State private var selectedChapter: Chapter? = nil
    @State private var zoomLevel: CGFloat = 1.0
    
    // Safe area spacing passed from parent
    var topSafeArea: CGFloat = 0
    var bottomSafeArea: CGFloat = 0
    
    // Mock chapters data
    private let chapters: [ChapterPreview] = [
        ChapterPreview(id: UUID(), name: "All", icon: "person.2.fill", isNew: false),
        ChapterPreview(id: UUID(), name: "Family", icon: nil, isNew: false),
        ChapterPreview(id: UUID(), name: "Friends", icon: nil, isNew: false),
        ChapterPreview(id: UUID(), name: "New", icon: "plus", isNew: true)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate sizes based on FULL screen size (just like FeedPostContainer)
            let safeArea = EdgeInsets(top: topSafeArea, leading: 0, bottom: bottomSafeArea, trailing: 0)
            let cardSize = CardDimensions.calculateMainCardSize(screenSize: geometry.size, safeArea: safeArea)
            // Use standardized topSpacing
            let topSpacing = CardDimensions.topSpacing(safeArea: safeArea)
            
            // MARK: - Layout Constants (MUST match FeedPostContainer)
            // 1. Defined Page Margins
            let headerInset: CGFloat = topSafeArea + 60 // Space for Floating Header
            let footerInset: CGFloat = bottomSafeArea + 10 // Space for Home Indicator
            
            // 2. Component Heights
            let controlsHeight: CGFloat = 110 // Fixed height for Controls (same as FeedPostContainer)
            let gapHeight: CGFloat = 16 // Standard Gap
            
            // 3. Dynamic Calculation - Same as FeedPostContainer
            // Available for Image Card = Screen - Header - Gap - Controls - Footer
            let cardHeight = max(geometry.size.height - headerInset - gapHeight - controlsHeight - footerInset, 100)
            let cardWidth = geometry.size.width
            
            ZStack {
                // Background - White with gradient and noise
                GradientNoiseBackground()
                
                VStack(spacing: 0) {
                    // A. Header Spacer (Push content down) - Same as FeedPostContainer
                    Spacer()
                        .frame(height: headerInset)
                    
                    // B. Camera/Photo Frame - Same size as PostCardView
                    Group {
                        if cameraState == .preview {
                            cameraPreviewFrame(width: cardWidth, height: cardHeight)
                        } else {
                            capturedPhotoFrame(width: cardWidth, height: cardHeight)
                        }
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    
                    // C. Gap - Same as FeedPostContainer
                    Spacer()
                        .frame(height: gapHeight)
                    
                    // D. Controls Area
                    VStack {
                        if cameraState == .preview {
                            captureControls
                        } else {
                            postCaptureControls
                        }
                    }
                    .frame(height: controlsHeight, alignment: .top)
                    
                    // E. Footer Spacer - Same as FeedPostContainer
                    Spacer()
                        .frame(height: footerInset)
                }
                
                // Permission denied overlay
                if !cameraManager.permissionGranted && cameraManager.error == .permissionDenied {
                    permissionDeniedView
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if newImage != nil {
                // Stop camera when photo is captured
                cameraManager.stopSession()
                withAnimation(.easeInOut(duration: 0.2)) {
                    cameraState = .captured
                }
            }
        }
        .onChange(of: cameraState) { _, newState in
            // Restart camera when returning to preview
            if newState == .preview && cameraManager.permissionGranted {
                cameraManager.startSession()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    cameraManager.capturedImage = image
                }
            }
        }
        .alert("Saved!", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cameraManager.livePhoto != nil ? "Live Photo saved to library" : "Photo saved to library")
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet { chapter in
                saveToChapter(chapter)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
            .font(.system(size: 50))
            .foregroundStyle(.white.opacity(0.5))
            
            Text("Camera Access Required")
            .font(.headline)
            .foregroundStyle(.white)
            
            Text("Please enable camera access in Settings to capture photos")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Computed properties
    private var hasVoiceNote: Bool {
        audioRecorder.recordedURL != nil || audioRecorder.isRecording
    }
    
    private var cardSpacing: CGFloat {
        cameraState == .preview ? 20 : 20
    }
    
    // MARK: - Main Content Area
    private func mainContentArea(safeAreaBottom: CGFloat) -> some View {
        return VStack { } // Placeholder not needed if we refactored Body. 
        // Wait, "mainContentArea" is NOT called in my NEW body refactor!
        // IN STEP 1010 REFACTOR:
        /*
        VStack(spacing: 0) {
                    // Top Spacer...
                    Spacer().frame(height: topSpacing)
                    
                    // Main content area (Camera or Photo)
                    VStack(spacing: cardSpacing) { ... }
        }
        */
        // I INLINED mainContentArea logic into body!
        // So I don't need to restore mainContentArea function if I removed the call.
        // BUT WAIT.
        // Did I remove the call?
        // Let's check the body I wrote in step 1010.
        // Yes, I wrote the content explicitly inside body.
        
        // HOWEVER, "cameraPreviewFrame" and "capturedPhotoFrame" use "cardSpacing".
        // "cardSpacing" IS MISSING.
        // "permissionDeniedView" IS MISSING (referenced in body).
        
        // So I need to restore "permissionDeniedView", "hasVoiceNote", "cardSpacing".
        // I DO NOT need "mainContentArea" because I inlined it.
    }
    
    // Redoing the replacement to just add the missing properties/views.
    private let goldenOrange = Color(red: 1.0, green: 0.75, blue: 0.0) // Cam Vàng (Amber)
    private let cornerRadius: CGFloat = CardDimensions.cornerRadius
    
    // Top Bar is now handled by HomeView (Global Header)
    
    // MARK: - Camera Preview Frame (State: preview)
    private func cameraPreviewFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Real camera preview
            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.session)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    )
                    .onAppear {
                        cameraManager.startSession()
                    }
                    .overlay(alignment: .top) {
                        // In-Preview Controls (Flash, Zoom)
                        HStack {
                            // Flash Button (Top Left)
                            Button(action: { cameraManager.toggleFlash() }) {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                            .foregroundStyle(cameraManager.isFlashOn ? goldenOrange : .white)
                                            .font(.system(size: 18))
                                    }
                            }
                            
                            Spacer()
                            
                            // Zoom Button (Top Right)
                            Button(action: {
                                // Toggle zoom mock
                                withAnimation {
                                    zoomLevel = zoomLevel == 1.0 ? 2.0 : 1.0
                                    cameraManager.setZoom(level: zoomLevel)
                                }
                            }) {
                                Circle()
                                    .fill(Color(red: 0.7, green: 0.6, blue: 0.4).opacity(0.8)) // Goldish brown bg
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text("\(Int(zoomLevel))x")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                            }
                        }
                        .padding(20)
                    }
            } else {
                // Placeholder - same size and shape as PostCardView
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: width, height: height)
                    .overlay {
                         Text("Camera Preview")
                            .foregroundStyle(.gray)
                    }
            }
        }
    }
    
    // MARK: - Captured Photo Frame (State: captured)
    private func capturedPhotoFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let image = cameraManager.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            
            // Live Photo Player
            if let movieURL = cameraManager.livePhotoMovieURL, isPlayingLivePhoto {
                LivePhotoVideoPlayer(videoURL: movieURL, isPlaying: $isPlayingLivePhoto)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            
            // Live Photo Badge
            if cameraManager.livePhotoMovieURL != nil {
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "livephoto")
                                .font(.system(size: 12, weight: .bold))
                            Text(isPlayingLivePhoto ? "LIVE" : "Hold")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isPlayingLivePhoto ? goldenOrange : Color.black.opacity(0.6)))
                        .padding(16)
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            
            // Message Input
            if !isPlayingLivePhoto {
                VStack {
                    Spacer()
                    messageInputOverlay
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(width: width, height: height)
        // Add press to play
        .simultaneousGesture(
             DragGesture(minimumDistance: 0)
                .onChanged { _ in
                     if cameraManager.livePhotoMovieURL != nil && !isPlayingLivePhoto {
                         isPlayingLivePhoto = true
                     }
                }
                .onEnded { _ in
                     isPlayingLivePhoto = false
                }
        )
    }
    
    // MARK: - Message Input Overlay
    private var messageInputOverlay: some View {
        HStack {
            TextField("Add a message", text: $messageText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
    
    // MARK: - Capture Controls (Bottom)
    private var captureControls: some View {
        HStack(alignment: .center, spacing: 60) {
            // Gallery (Left)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 28))
                    .foregroundStyle(.black.opacity(0.7))
            }
            
            // Shutter Button (Center)
            Button(action: { capturePhoto() }) {
                ZStack {
                    // Outer Ring
                    Circle()
                        .stroke(goldenOrange, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    // Inner Circle
                    Circle()
                        .fill(goldenOrange.opacity(0.15))
                        .frame(width: 70, height: 70)
                }
            }
            .disabled(cameraManager.isCapturingLivePhoto)
            
            // Flip Camera (Right)
            Button(action: { cameraManager.toggleCamera() }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 28))
                    .foregroundStyle(.black.opacity(0.7))
            }
        }
    }
    
    // MARK: - Post Capture Controls (Bottom)
    private var postCaptureControls: some View {
        VStack(spacing: 20) {
             // Voice Note Controls if active
             if audioRecorder.recordedURL != nil || audioRecorder.isRecording {
                 voiceNoteControls
             }
             
             // Action Row: Cancel | Send | Voice
             HStack(spacing: 40) {
                 // Cancel
                 Button(action: { cancelCapture() }) {
                     Image(systemName: "xmark")
                         .font(.system(size: 24, weight: .medium))
                         .foregroundStyle(.black.opacity(0.7))
                         .frame(width: 50, height: 50)
                         .background(Circle().fill(Color.black.opacity(0.08)))
                 }
                 
                 // Send Button
                 Button(action: { showChapterPicker = true }) {
                     ZStack {
                         Circle()
                             .fill(goldenOrange)
                             .frame(width: 70, height: 70)
                         
                         if isSaving {
                             ProgressView().tint(.white)
                         } else {
                             Image(systemName: "paperplane.fill")
                                 .font(.system(size: 28))
                                 .foregroundStyle(.white)
                                 .offset(x: -2, y: 2)
                         }
                     }
                 }
                 
                 // Voice Record
                 Button(action: { audioRecorder.toggleRecording() }) {
                     Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                         .font(.system(size: 24, weight: .medium))
                         .foregroundStyle(audioRecorder.isRecording ? .white : .black.opacity(0.7))
                         .frame(width: 50, height: 50)
                         .background(Circle().fill(audioRecorder.isRecording ? Color.red.opacity(0.8) : Color.black.opacity(0.08)))
                 }
             }
        }
    }

    // MARK: - Voice Note Controls
    private var voiceNoteControls: some View {
        HStack {
            if audioRecorder.isRecording {
                 Text("Recording... \(audioRecorder.formatDuration(audioRecorder.recordingDuration))")
                     .foregroundStyle(.red)
            } else {
                 Button(action: { audioRecorder.togglePlayback() }) {
                     Image(systemName: audioRecorder.isPlaying ? "pause.fill" : "play.fill")
                 }
                 Text(audioRecorder.formatDuration(audioRecorder.recordingDuration))
                 
                 Spacer()
                 
                 Button(action: { audioRecorder.deleteRecording() }) {
                     Image(systemName: "trash")
                 }
            }
        }
        .padding()
        .background(Capsule().fill(Color.white))
        .padding(.horizontal, 40)
    }
    
    // MARK: - Actions (Helper methods)
    private func capturePhoto() { cameraManager.capturePhoto() }
    
    private func cancelCapture() {
        audioRecorder.deleteRecording()
        cameraManager.clearCapturedImage()
        messageText = ""
        isPlayingLivePhoto = false
        selectedPhotoItem = nil
        withAnimation { cameraState = .preview }
    }
    
    private func saveToChapter(_ chapter: Chapter? = nil) {
        guard let image = cameraManager.capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        isSaving = true
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
                cancelCapture()
            } catch {
                print("Error saving: \(error)")
            }
            isSaving = false
        }
    }
}


// MARK: - Chapter Preview Model
struct ChapterPreview: Identifiable {
    let id: UUID
    let name: String
    let icon: String?
    let isNew: Bool
}

#Preview {
    CameraView()
}
