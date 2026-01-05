//
//  CameraView.swift
//  Cira
//
//  Camera tab - Capture photos and record voice
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
    
    // Mock chapters data
    private let chapters: [ChapterPreview] = [
        ChapterPreview(id: UUID(), name: "All", icon: "person.2.fill", isNew: false),
        ChapterPreview(id: UUID(), name: "Family", icon: nil, isNew: false),
        ChapterPreview(id: UUID(), name: "Friends", icon: nil, isNew: false),
        ChapterPreview(id: UUID(), name: "New", icon: "plus", isNew: true)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar - changes based on state
                topBar
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                
                Spacer().frame(height: 8)
                
                // Main content area
                mainContentArea
            }
            
            // Permission denied overlay
            if !cameraManager.permissionGranted && cameraManager.error == .permissionDenied {
                permissionDeniedView
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
        .onChange(of: cameraManager.livePhotoMovieURL) { _, newURL in
            // Create PHLivePhoto for playback when movie URL is ready
            // Both photo data and movie URL must be available
            if newURL != nil && cameraManager.capturedPhotoData != nil {
                print("📷 Both photo and movie ready - creating PHLivePhoto...")
                cameraManager.createLivePhotoForPlayback()
            }
        }
        .onChange(of: cameraManager.capturedPhotoData) { _, newData in
            // Also check when photo data arrives (in case movie was ready first)
            if newData != nil && cameraManager.livePhotoMovieURL != nil {
                print("📷 Photo data arrived - creating PHLivePhoto...")
                cameraManager.createLivePhotoForPlayback()
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
    
    // MARK: - Computed properties for layout
    private var hasVoiceNote: Bool {
        audioRecorder.recordedURL != nil || audioRecorder.isRecording
    }
    
    private var controlsHeight: CGFloat {
        if cameraState == .preview {
            return 90
        } else {
            return hasVoiceNote ? 200 : 160
        }
    }
    
    private var cardSpacing: CGFloat {
        cameraState == .preview ? 56 : 20
    }
    
    // MARK: - Main Content Area
    private var mainContentArea: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let tabBarSpace: CGFloat = 70
            let topSpace: CGFloat = 8
            let cardHeight = availableHeight - controlsHeight - tabBarSpace - topSpace
            let cardWidth = geometry.size.width - CardDimensions.horizontalPadding
            
            VStack(spacing: cardSpacing) {
                // Image/Camera frame
                if cameraState == .preview {
                    cameraPreviewFrame(width: cardWidth, height: cardHeight)
                } else {
                    capturedPhotoFrame(width: cardWidth, height: cardHeight)
                }
                
                // Controls
                if cameraState == .preview {
                    captureControls
                } else {
                    postCaptureControls
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            if cameraState == .captured {
                // "Send to..." text
                Text("Send to...")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                // Download/Save button
                Button(action: { saveToPhotos() }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(8)
                }
            } else {
                // Live Photo toggle
                if cameraManager.isLivePhotoSupported {
                    Button(action: { cameraManager.toggleLivePhoto() }) {
                        Image(systemName: cameraManager.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
                            .font(.title2)
                            .foregroundStyle(cameraManager.isLivePhotoEnabled ? .yellow : .white)
                            .padding(12)
                            .background(Circle().fill(Color.gray.opacity(0.4)))
                    }
                }
                
                Spacer()
                
                // Flash toggle
                Button(action: { cameraManager.toggleFlash() }) {
                    Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                        .font(.title2)
                        .foregroundStyle(cameraManager.isFlashOn ? .yellow : .white)
                        .padding(12)
                        .background(Circle().fill(Color.gray.opacity(0.4)))
                }
                
                // Flip camera
                Button(action: { cameraManager.toggleCamera() }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Circle().fill(Color.gray.opacity(0.4)))
                }
            }
        }
    }
    
    // MARK: - Camera Preview Frame (State: preview)
    private func cameraPreviewFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Real camera preview
            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.session)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius))
                    .onAppear {
                        cameraManager.startSession()
                    }
            } else {
                // Placeholder when no permission
                RoundedRectangle(cornerRadius: CardDimensions.cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text("Camera Preview")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
            }
            
            // Border overlay
            RoundedRectangle(cornerRadius: CardDimensions.cornerRadius)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: width, height: height)
        }
    }
    
    // MARK: - Captured Photo Frame (State: captured)
    private func capturedPhotoFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Always show captured image as base layer
            if let image = cameraManager.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius))
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: CardDimensions.cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
            
            // Show video when playing Live Photo
            if let movieURL = cameraManager.livePhotoMovieURL, isPlayingLivePhoto {
                LivePhotoVideoPlayer(videoURL: movieURL, isPlaying: $isPlayingLivePhoto)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: CardDimensions.cornerRadius))
            }
            
            // Gesture area for Live Photo playback
            if cameraManager.livePhotoMovieURL != nil {
                Color.clear
                    .frame(width: width, height: height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPlayingLivePhoto {
                                    print("👆 Press detected - starting video playback")
                                    isPlayingLivePhoto = true
                                }
                            }
                            .onEnded { _ in
                                print("👆 Release detected - stopping video playback")
                                isPlayingLivePhoto = false
                            }
                    )
            }
            
            // Border overlay
            RoundedRectangle(cornerRadius: CardDimensions.cornerRadius)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: width, height: height)
            
            // Live Photo badge with hint (show when we have movie URL)
            if cameraManager.livePhotoMovieURL != nil {
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: isPlayingLivePhoto ? "livephoto" : "livephoto")
                                .font(.caption.weight(.bold))
                            Text(isPlayingLivePhoto ? "LIVE" : "Hold to view")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isPlayingLivePhoto ? Color.yellow.opacity(0.8) : Color.black.opacity(0.6)))
                        .padding(16)
                        
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: width, height: height)
                .allowsHitTesting(false)
            }
            
            // Message input overlay (only when not playing)
            if !isPlayingLivePhoto {
                VStack {
                    Spacer()
                    
                    messageInputOverlay
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .frame(width: width, height: height)
            }
        }
    }
    
    // MARK: - Message Input Overlay
    private var messageInputOverlay: some View {
        HStack {
            TextField("Add a message", text: $messageText)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.6))
                )
        }
    }
    
    // MARK: - Capture Controls (State: preview)
    private var captureControls: some View {
        HStack(alignment: .center, spacing: 40) {
                // Gallery button - PhotosPicker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                }
                
                // Capture button with Live Photo indicator
                Button(action: { capturePhoto() }) {
                    ZStack {
                        // Outer ring - yellow when Live Photo enabled
                        Circle()
                            .stroke(cameraManager.isLivePhotoEnabled && cameraManager.isLivePhotoSupported ? Color.yellow : .white, lineWidth: 5)
                            .frame(width: 80, height: 80)
                        
                        // Inner circle
                        Circle()
                            .fill(.white)
                            .frame(width: 66, height: 66)
                        
                        // Live Photo capturing indicator
                        if cameraManager.isCapturingLivePhoto {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 3)
                                .frame(width: 90, height: 90)
                                .opacity(0.8)
                        }
                    }
                }
                .disabled(cameraManager.isCapturingLivePhoto)
                
                // Effects button
                Button(action: {}) {
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                }
            }
    }
    
    // MARK: - Post Capture Controls (State: captured)
    private var postCaptureControls: some View {
        VStack(spacing: 12) {
            // Voice recording indicator / playback controls
            if audioRecorder.recordedURL != nil || audioRecorder.isRecording {
                voiceNoteControls
            }
            
            // Main action buttons row
            HStack(alignment: .center, spacing: 16) {
                // Cancel button with label inside
                Button(action: { cancelCapture() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                        Text("Cancel")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.gray.opacity(0.4)))
                }
                
                // Send/Save button (main action) - opens chapter picker
                Button(action: { showChapterPicker = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 64, height: 64)
                        
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
                .disabled(isSaving)
                
                // Voice record button with label inside
                Button(action: { audioRecorder.toggleRecording() }) {
                    HStack(spacing: 4) {
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.footnote.weight(.semibold))
                        Text(audioRecorder.isRecording ? "Stop" : "Record")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(audioRecorder.isRecording ? .red : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(audioRecorder.isRecording ? Color.red.opacity(0.3) : Color.gray.opacity(0.4)))
                }
            }
            
            // Chapter selection row
            chapterSelectionRow
        }
    }
    
    // MARK: - Voice Note Controls
    private var voiceNoteControls: some View {
        HStack(spacing: 10) {
            // Recording indicator or playback button
            if audioRecorder.isRecording {
                // Recording animation - compact
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(audioRecorder.formatDuration(audioRecorder.recordingDuration))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            } else if audioRecorder.recordedURL != nil {
                // Playback controls - compact
                HStack(spacing: 8) {
                    // Play/Pause button
                    Button(action: { audioRecorder.togglePlayback() }) {
                        Image(systemName: audioRecorder.isPlaying ? "pause.fill" : "play.fill")
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.gray.opacity(0.5)))
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 3)
                            
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * audioRecorder.playbackProgress, height: 3)
                        }
                        .frame(height: geometry.size.height)
                    }
                    .frame(height: 28)
                    
                    // Duration
                    Text(audioRecorder.formatDuration(audioRecorder.recordingDuration))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                    
                    // Delete button
                    Button(action: { audioRecorder.deleteRecording() }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.gray.opacity(0.4)))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.3))
        )
        .padding(.horizontal, 40)
        .padding(.vertical, 10)
    }
    
    // MARK: - Chapter Selection Row
    private var chapterSelectionRow: some View {
        let itemWidth: CGFloat = 56 // Width of each chapter button - smaller
        let spacing: CGFloat = 12
        
        return GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let sidePadding = (screenWidth - itemWidth) / 2
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                            chapterButton(chapter: chapter, index: index)
                                .frame(width: itemWidth)
                                .id(index)
                        }
                    }
                    .padding(.leading, sidePadding)
                    .padding(.trailing, sidePadding)
                }
                .onChange(of: selectedChapterIndex) { _, newValue in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(selectedChapterIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 64)
    }
    
    private func chapterButton(chapter: ChapterPreview, index: Int) -> some View {
        let isSelected = selectedChapterIndex == index
        
        return Button(action: { selectedChapterIndex = index }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.yellow : Color.white.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                        .frame(width: 44, height: 44)
                    
                    if let icon = chapter.icon {
                        if chapter.isNew {
                            Image(systemName: icon)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            Image(systemName: icon)
                                .font(.subheadline)
                                .foregroundStyle(isSelected ? .yellow : .white)
                        }
                    } else {
                        // Chapter thumbnail placeholder
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }
                }
                
                Text(chapter.name)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .yellow : .white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Actions
    private func capturePhoto() {
        cameraManager.capturePhoto()
    }
    
    private func cancelCapture() {
        // Stop and clear audio recording
        audioRecorder.deleteRecording()
        
        // Clear camera data
        cameraManager.clearCapturedImage()
        messageText = ""
        isPlayingLivePhoto = false
        selectedPhotoItem = nil
        
        // Then switch state (will trigger camera restart via onChange)
        withAnimation(.easeInOut(duration: 0.2)) {
            cameraState = .preview
        }
    }
    
    private func saveToChapter(_ chapter: Chapter? = nil) {
        guard let image = cameraManager.capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ No image to save")
            return
        }
        
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
                
                if let chapter = chapter {
                    print("✅ Saved to chapter: \(chapter.name)")
                } else {
                    print("✅ Saved as single post")
                }
                
                // Post notification to refresh Home feed
                NotificationCenter.default.post(name: .newPostSaved, object: nil)
                
                // Clear and go back to preview
                cancelCapture()
                
            } catch {
                print("❌ Failed to save post: \(error)")
            }
            
            isSaving = false
        }
    }
    
    private func saveToPhotos() {
        guard cameraManager.capturedImage != nil else { return }
        
        // Check if it's a Live Photo
        if cameraManager.livePhotoMovieURL != nil {
            cameraManager.saveLivePhotoToLibrary { success in
                if success {
                    showSavedAlert = true
                }
            }
        } else {
            cameraManager.saveToPhotos(cameraManager.capturedImage!) { success in
                if success {
                    showSavedAlert = true
                }
            }
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
