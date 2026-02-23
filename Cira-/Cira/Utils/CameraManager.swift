//
//  CameraManager.swift
//  Cira
//
//  Camera manager with Live Photo support - Based on Apple Documentation
//  Reference: https://developer.apple.com/documentation/avfoundation/capturing-and-saving-live-photos
//

import SwiftUI
import AVFoundation
import Photos
import PhotosUI
import Combine

// MARK: - Camera Manager
@MainActor
class CameraManager: NSObject, ObservableObject {
    // Published properties
    @Published var capturedImage: UIImage?
    @Published var capturedPhotoData: Data?
    @Published var livePhotoMovieURL: URL?
    @Published var livePhoto: PHLivePhoto?
    @Published var isFlashOn = false
    @Published var isFrontCamera = false
    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var audioPermissionGranted = false
    @Published var error: CameraError?
    @Published var isLivePhotoEnabled = true
    @Published var isCapturingLivePhoto = false
    @Published var debugMessage: String = ""
    
    // AVFoundation components
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    
    // Live Photo capture tracking
    private var inProgressLivePhotoCapturesCount = 0
    
    // Temporary storage for Live Photo creation
    private var pendingLivePhotoMovieURL: URL?
    private var pendingPhotoData: Data?
    
    // Check if Live Photo is supported
    var isLivePhotoSupported: Bool {
        photoOutput.isLivePhotoCaptureSupported
    }
    
    var canCaptureLivePhoto: Bool {
        isLivePhotoEnabled &&
        photoOutput.isLivePhotoCaptureSupported &&
        photoOutput.isLivePhotoCaptureEnabled &&
        audioDeviceInput != nil
    }
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case permissionDenied
        case audioPermissionDenied
        case saveFailed
        case livePhotoNotSupported
        case configurationFailed
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "Camera unavailable"
            case .cannotAddInput: return "Cannot add camera input"
            case .cannotAddOutput: return "Cannot add photo output"
            case .permissionDenied: return "Camera permission not granted"
            case .audioPermissionDenied: return "Microphone permission not granted"
            case .saveFailed: return "Cannot save photo"
            case .livePhotoNotSupported: return "Live Photo not supported"
            case .configurationFailed: return "Cannot configure camera"
            }
        }
    }
    
    override init() {
        super.init()
        print("📷 CameraManager initialized")
    }
    
    // MARK: - Check Permissions
    func checkPermission() {
        print("📷 Checking camera permission...")
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("✅ Camera permission granted")
            permissionGranted = true
            checkAudioPermission()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    print("📷 Camera permission response: \(granted)")
                    self?.permissionGranted = granted
                    if granted {
                        self?.checkAudioPermission()
                    } else {
                        self?.error = .permissionDenied
                    }
                }
            }
            
        case .denied, .restricted:
            print("❌ Camera permission denied")
            permissionGranted = false
            error = .permissionDenied
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Check Audio Permission (REQUIRED for Live Photo)
    private func checkAudioPermission() {
        print("📷 Checking audio permission (required for Live Photo)...")
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("✅ Audio permission granted")
            audioPermissionGranted = true
            configureSession()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    print("📷 Audio permission response: \(granted)")
                    self?.audioPermissionGranted = granted
                    if !granted {
                        self?.debugMessage = "⚠️ Microphone permission denied - Live Photo disabled"
                        self?.isLivePhotoEnabled = false
                    }
                    self?.configureSession()
                }
            }
            
        case .denied, .restricted:
            print("⚠️ Audio permission denied - Live Photo will be disabled")
            audioPermissionGranted = false
            debugMessage = "⚠️ Microphone permission required for Live Photo"
            isLivePhotoEnabled = false
            configureSession()
            
        @unknown default:
            configureSession()
        }
    }
    
    // MARK: - Configure Capture Session (Apple Documentation)
    private func configureSession() {
        print("📷 Configuring capture session...")
        
        session.beginConfiguration()
        
        // 1. Set session preset to .photo for best quality
        session.sessionPreset = .photo
        
        // 2. Add VIDEO input first
        do {
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ No video device available")
                error = .cameraUnavailable
                session.commitConfiguration()
                return
            }
            
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
                print("✅ Video input added")
            } else {
                print("❌ Cannot add video input")
                error = .cannotAddInput
                session.commitConfiguration()
                return
            }
        } catch {
            print("❌ Video input error: \(error)")
            self.error = .cameraUnavailable
            session.commitConfiguration()
            return
        }
        
        // 3. Add AUDIO input (REQUIRED for Live Photo per Apple docs)
        if audioPermissionGranted {
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if session.canAddInput(audioInput) {
                        session.addInput(audioInput)
                        audioDeviceInput = audioInput
                        print("✅ Audio input added (required for Live Photo)")
                    } else {
                        print("⚠️ Cannot add audio input")
                    }
                } catch {
                    print("⚠️ Audio input error: \(error)")
                }
            }
        } else {
            print("⚠️ Audio permission not granted - Live Photo will be disabled")
        }
        
        // 4. Add Photo Output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            // Configure photo output for best quality
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // 5. Enable Live Photo capture if supported (per Apple docs)
            print("📷 Live Photo supported: \(photoOutput.isLivePhotoCaptureSupported)")
            print("📷 Audio input available: \(audioDeviceInput != nil)")
            
            if photoOutput.isLivePhotoCaptureSupported && audioDeviceInput != nil {
                photoOutput.isLivePhotoCaptureEnabled = true
                print("✅ Live Photo capture ENABLED")
                debugMessage = "✅ Live Photo enabled"
            } else {
                isLivePhotoEnabled = false
                print("❌ Live Photo capture NOT available")
                if audioDeviceInput == nil {
                    debugMessage = "⚠️ Microphone required for Live Photo"
                } else {
                    debugMessage = "❌ Device doesn't support Live Photo"
                }
            }
            
            print("✅ Photo output added")
        } else {
            print("❌ Cannot add photo output")
            error = .cannotAddOutput
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        print("✅ Session configuration complete")
    }
    
    // MARK: - Start Session
    func startSession() {
        guard permissionGranted, !session.isRunning else { return }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.startRunning()
            await MainActor.run {
                self?.isSessionRunning = self?.session.isRunning ?? false
                print("📷 Session running: \(self?.isSessionRunning ?? false)")
            }
        }
    }
    
    // MARK: - Stop Session
    func stopSession() {
        guard session.isRunning else { return }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.stopRunning()
            await MainActor.run {
                self?.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Capture Photo (with Live Photo support per Apple docs)
    func capturePhoto() {
        #if targetEnvironment(simulator)
        print("📷 Simulator detected: Mocking photo capture")
        Task { @MainActor in
            let size = CGSize(width: 1080, height: 1920)
            let renderer = UIGraphicsImageRenderer(size: size)
            let mockImage = renderer.image { ctx in
                UIColor.darkGray.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 60),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraphStyle
                ]
                
                let string = "Simulator\nPhoto" as NSString
                string.draw(in: CGRect(x: 0, y: size.height/2 - 80, width: size.width, height: 160),
                           withAttributes: attrs)
            }
            
            self.capturedImage = mockImage
            self.capturedPhotoData = mockImage.jpegData(compressionQuality: 0.9)
            print("✅ Simulator: Mock photo captured")
        }
        return
        #endif

        // Create photo settings with HEVC format (best for Live Photo)
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        
        // Configure flash
        if photoOutput.supportedFlashModes.contains(.on) {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        // Check if we can capture Live Photo
        let willCaptureLive = canCaptureLivePhoto
        
        print("📷 ========== CAPTURE START ==========")
        print("📷 Live Photo enabled setting: \(isLivePhotoEnabled)")
        print("📷 Live Photo supported: \(photoOutput.isLivePhotoCaptureSupported)")
        print("📷 Live Photo output enabled: \(photoOutput.isLivePhotoCaptureEnabled)")
        print("📷 Audio input available: \(audioDeviceInput != nil)")
        print("📷 Will capture Live Photo: \(willCaptureLive)")
        
        if willCaptureLive {
            // Create unique file URL for Live Photo movie (per Apple docs)
            let livePhotoMovieFileName = NSUUID().uuidString
            let livePhotoMoviePath = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("\(livePhotoMovieFileName).mov")
            let movieURL = URL(fileURLWithPath: livePhotoMoviePath)
            
            // Set Live Photo movie URL in settings
            settings.livePhotoMovieFileURL = movieURL
            
            inProgressLivePhotoCapturesCount += 1
            isCapturingLivePhoto = true
            
            print("📷 Live Photo movie will be saved to: \(movieURL.path)")
        }
        
        // Capture the photo
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Toggle Camera
    func toggleCamera() {
        guard let currentInput = videoDeviceInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
                isFrontCamera.toggle()
            } else {
                session.addInput(currentInput)
            }
        } catch {
            session.addInput(currentInput)
        }
        
        session.commitConfiguration()
    }
    
    // MARK: - Toggle Flash
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    // MARK: - Toggle Live Photo
    func toggleLivePhoto() {
        guard photoOutput.isLivePhotoCaptureSupported else {
            error = .livePhotoNotSupported
            return
        }
        guard audioDeviceInput != nil else {
            debugMessage = "Microphone permission required for Live Photo"
            return
        }
        isLivePhotoEnabled.toggle()
        print("📷 Live Photo toggled: \(isLivePhotoEnabled)")
    }
    
    // MARK: - Set Zoom
    func setZoom(level: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(device.minAvailableVideoZoomFactor, min(level, device.maxAvailableVideoZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("Zoom error: \(error)")
        }
    }
    
    // MARK: - Save Live Photo to Library (per Apple docs)
    func saveLivePhotoToLibrary(completion: @escaping (Bool) -> Void) {
        guard let photoData = capturedPhotoData ?? capturedImage?.jpegData(compressionQuality: 1.0),
              let movieURL = livePhotoMovieURL else {
            print("⚠️ Missing data for Live Photo save, saving as regular photo")
            if let image = capturedImage {
                saveToPhotos(image, completion: completion)
            } else {
                completion(false)
            }
            return
        }
        
        let fileExists = FileManager.default.fileExists(atPath: movieURL.path)
        print("📷 ========== SAVING LIVE PHOTO ==========")
        print("📷 Photo data size: \(photoData.count) bytes")
        print("📷 Movie URL: \(movieURL)")
        print("📷 Movie file exists: \(fileExists)")
        
        if !fileExists {
            print("❌ Movie file doesn't exist!")
            if let image = capturedImage {
                saveToPhotos(image, completion: completion)
            } else {
                completion(false)
            }
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                print("❌ Photo library permission denied")
                Task { @MainActor in
                    completion(false)
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                // Create asset request (per Apple docs)
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // Add the photo data (with Live Photo metadata embedded)
                creationRequest.addResource(with: .photo, data: photoData, options: nil)
                
                // Add the paired video (the Live Photo movie)
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true // Move instead of copy for efficiency
                creationRequest.addResource(with: .pairedVideo, fileURL: movieURL, options: options)
                
            } completionHandler: { success, error in
                if let error = error {
                    print("❌ Error saving Live Photo: \(error)")
                } else if success {
                    print("✅ Live Photo saved successfully!")
                }
                Task { @MainActor in
                    completion(success)
                }
            }
        }
    }
    
    // MARK: - Save Regular Photo to Library
    func saveToPhotos(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                Task { @MainActor in
                    completion(false)
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error = error {
                    print("❌ Error saving photo: \(error)")
                } else if success {
                    print("✅ Photo saved successfully!")
                }
                Task { @MainActor in
                    completion(success)
                }
            }
        }
    }
    
    // MARK: - Clear Captured Content
    func clearCapturedImage() {
        capturedImage = nil
        capturedPhotoData = nil
        livePhotoMovieURL = nil
        livePhoto = nil
        pendingPhotoData = nil
        pendingLivePhotoMovieURL = nil
    }
    
    // MARK: - Create PHLivePhoto for In-App Playback
    func createLivePhotoForPlayback() {
        guard let photoData = capturedPhotoData,
              let movieURL = livePhotoMovieURL,
              let image = capturedImage else {
            print("⚠️ Cannot create PHLivePhoto - missing data")
            print("   Photo data: \(capturedPhotoData != nil)")
            print("   Movie URL: \(livePhotoMovieURL != nil)")
            print("   Image: \(capturedImage != nil)")
            return
        }
        
        let fileExists = FileManager.default.fileExists(atPath: movieURL.path)
        print("📷 ========== CREATING PHLivePhoto ==========")
        print("📷 Movie file exists: \(fileExists)")
        
        if !fileExists {
            print("❌ Movie file doesn't exist at: \(movieURL.path)")
            return
        }
        
        // Save photo data to temp file for PHLivePhoto.request
        let photoURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString).jpg")
        
        do {
            try photoData.write(to: photoURL)
            print("✅ Photo saved to temp: \(photoURL.path)")
        } catch {
            print("❌ Error saving temp photo: \(error)")
            return
        }
        
        // Request PHLivePhoto from the photo and movie files
        PHLivePhoto.request(
            withResourceFileURLs: [photoURL, movieURL],
            placeholderImage: image,
            targetSize: CGSize(width: image.size.width, height: image.size.height),
            contentMode: .aspectFit
        ) { [weak self] livePhoto, info in
            // Clean up temp photo file
            try? FileManager.default.removeItem(at: photoURL)
            
            Task { @MainActor in
                if let livePhoto = livePhoto {
                    self?.livePhoto = livePhoto
                    print("✅ PHLivePhoto created successfully!")
                    
                    // Check for degraded version
                    let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
                    print("   Is degraded: \(isDegraded)")
                } else {
                    print("❌ Failed to create PHLivePhoto")
                    if let error = info[PHLivePhotoInfoErrorKey] as? Error {
                        print("   Error: \(error)")
                    }
                    print("   Info: \(info)")
                }
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate (Apple Documentation)
extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    // Step 1: Capture is about to begin
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Check if this capture includes Live Photo
        let isLivePhoto = resolvedSettings.livePhotoMovieDimensions.width > 0 &&
                          resolvedSettings.livePhotoMovieDimensions.height > 0
        
        print("📷 [1] willBeginCapture - Live Photo: \(isLivePhoto)")
        print("   Live Photo dimensions: \(resolvedSettings.livePhotoMovieDimensions)")
        
        Task { @MainActor in
            if isLivePhoto {
                self.isCapturingLivePhoto = true
            }
        }
    }
    
    // Step 2: Photo capture completed
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ [2] Photo processing error: \(error)")
            return
        }
        
        // Get photo data WITH Live Photo metadata (important!)
        guard let photoData = photo.fileDataRepresentation() else {
            print("❌ [2] Could not get photo data")
            return
        }
        
        guard let image = UIImage(data: photoData) else {
            print("❌ [2] Could not create UIImage from data")
            return
        }
        
        print("✅ [2] Photo captured successfully!")
        print("   Photo data size: \(photoData.count) bytes")
        print("   Image size: \(image.size)")
        
        Task { @MainActor in
            // Store BOTH the raw photo data (with metadata) and UIImage
            self.capturedPhotoData = photoData
            self.capturedImage = image
        }
    }
    
    // Step 3: Live Photo movie recording finished
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("📷 [3] Live Photo recording finished at: \(outputFileURL)")
        
        // Movie is no longer recording - can hide "Live" indicator
        Task { @MainActor in
            // Still processing, but recording done
        }
    }
    
    // Step 4: Live Photo movie file is ready
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("❌ [4] Live Photo movie error: \(error)")
            Task { @MainActor in
                self.inProgressLivePhotoCapturesCount -= 1
                if self.inProgressLivePhotoCapturesCount == 0 {
                    self.isCapturingLivePhoto = false
                }
            }
            return
        }
        
        let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
        
        print("✅ [4] Live Photo movie ready!")
        print("   URL: \(outputFileURL)")
        print("   Duration: \(CMTimeGetSeconds(duration))s")
        print("   Photo display time: \(CMTimeGetSeconds(photoDisplayTime))s")
        print("   File exists: \(fileExists)")
        
        Task { @MainActor in
            // Store the movie URL
            self.livePhotoMovieURL = outputFileURL
            
            self.inProgressLivePhotoCapturesCount -= 1
            if self.inProgressLivePhotoCapturesCount == 0 {
                self.isCapturingLivePhoto = false
            }
        }
    }
    
    // Step 5: Entire capture process complete
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("❌ [5] Capture finished with error: \(error)")
            Task { @MainActor in
                self.inProgressLivePhotoCapturesCount = max(0, self.inProgressLivePhotoCapturesCount - 1)
                if self.inProgressLivePhotoCapturesCount == 0 {
                    self.isCapturingLivePhoto = false
                }
            }
        } else {
            print("✅ [5] Capture completed successfully!")
            print("📷 ========== CAPTURE END ==========")
        }
    }
}

// MARK: - Camera Preview View (UIViewRepresentable)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Live Photo View (UIViewRepresentable using PHLivePhotoView)
struct LivePhotoPlayerView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    @Binding var isPlaying: Bool
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.delegate = context.coordinator
        print("📷 LivePhotoPlayerView created")
        return view
    }
    
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        if uiView.livePhoto !== livePhoto {
            uiView.livePhoto = livePhoto
            print("📷 LivePhotoPlayerView: livePhoto updated")
        }
        
        if isPlaying && !context.coordinator.isCurrentlyPlaying {
            print("▶️ Starting Live Photo playback...")
            uiView.startPlayback(with: .full)
            context.coordinator.isCurrentlyPlaying = true
        } else if !isPlaying && context.coordinator.isCurrentlyPlaying {
            print("⏹️ Stopping Live Photo playback...")
            uiView.stopPlayback()
            context.coordinator.isCurrentlyPlaying = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHLivePhotoViewDelegate {
        var parent: LivePhotoPlayerView
        var isCurrentlyPlaying = false
        
        init(_ parent: LivePhotoPlayerView) {
            self.parent = parent
        }
        
        func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            print("▶️ PHLivePhotoView delegate: playback started (style: \(playbackStyle))")
            isCurrentlyPlaying = true
        }
        
        func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            print("⏹️ PHLivePhotoView delegate: playback ended")
            isCurrentlyPlaying = false
            Task { @MainActor in
                self.parent.isPlaying = false
            }
        }
    }
}

// MARK: - Video Player View (Alternative for Live Photo movie playback)
import AVKit

struct LivePhotoVideoPlayer: UIViewControllerRepresentable {
    let videoURL: URL
    @Binding var isPlaying: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: videoURL)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        // Observe when video ends
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        context.coordinator.player = player
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if isPlaying {
            uiViewController.player?.seek(to: .zero)
            uiViewController.player?.play()
            print("▶️ Video player: playing")
        } else {
            uiViewController.player?.pause()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: LivePhotoVideoPlayer
        var player: AVPlayer?
        
        init(_ parent: LivePhotoVideoPlayer) {
            self.parent = parent
        }
        
        @objc func playerDidFinish() {
            print("⏹️ Video player: finished")
            Task { @MainActor in
                self.parent.isPlaying = false
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
