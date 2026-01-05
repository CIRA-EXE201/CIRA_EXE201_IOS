# Cira - Image & Voice Storage Platform

## 📱 Tổng quan dự án
Cira là ứng dụng iOS cho phép người dùng lưu trữ hình ảnh kèm theo ghi âm giọng nói, tạo ra trải nghiệm lưu giữ kỷ niệm đa phương tiện.

## 🎯 Tính năng chính
- [ ] Chụp/chọn ảnh từ thư viện
- [ ] Ghi âm giọng nói đính kèm ảnh
- [ ] Phát lại voice khi xem ảnh
- [ ] Quản lý chapters (bộ sưu tập theo chủ đề)
- [ ] Tìm kiếm và lọc ảnh
- [ ] Đồng bộ iCloud (tùy chọn)
- [ ] Chia sẻ ảnh + voice

## 📱 App Views Structure

### 🎨 Design Theme
| Thuộc tính | Giá trị |
|------------|---------|
| Primary Background | `#FFFFFF` (White) |
| Secondary Background | `#F8F9FA` (Light Gray) |
| Card Background | White với blur overlay |
| Accent Color | `#007AFF` (iOS Blue) |
| Text Primary | `#1A1A1A` |
| Text Secondary | `#8E8E93` |
| Voice Waveform | Pink gradient `#FF6B9D` → `#FF8A80` |
| Glass Effect | White blur với opacity 0.8 |

### 1. Home View (Feed Style - Locket/Instagram inspired)
Màn hình chính với feed scroll vertical, hiển thị ảnh và chapters được chia sẻ.

**Layout Concept:**
```
┌─────────────────────────────────────┐
│  ○ Cira              [+] [@]  [≡]  │  ← Header: Logo, Add, Notifications, Menu
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │                             │   │
│  │         PHOTO/VIDEO         │   │  ← Full-width image card
│  │        (Full Screen)        │   │
│  │                             │   │
│  │  ┌─────────────────────┐   │   │
│  │  │ 🎤 ▓▓▓▓░░░░ 0:15   │   │   │  ← Voice waveform overlay (bottom)
│  │  └─────────────────────┘   │   │
│  │                             │   │
│  │  ● ○ ○ ○ ○ ○               │   │  ← Page indicators (if chapter)
│  └─────────────────────────────┘   │
│                                     │
│  👤 username • 2 giờ trước         │  ← User info & timestamp
│  ❤️ 💬 ↗️                          │  ← Actions: Like, Comment, Share
│                                     │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │  ← Divider
│                                     │
│  ┌─────────────────────────────┐   │
│  │      NEXT POST (scroll)     │   │  ← Scroll down for next
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘

Swipe Gestures:
↑↓ = Scroll between posts (vertical)
←→ = Swipe between photos in chapter (horizontal)
```

| Thành phần | Mô tả |
|------------|-------|
| Header | Logo Cira, nút Add (+), Notifications, Menu |
| Feed | Vertical scroll các posts (ảnh đơn hoặc chapter) |
| Image Card | Full-width, rounded corners, aspect ratio 4:5 hoặc 1:1 |
| Voice Overlay | Glass bar ở bottom với waveform + duration |
| Page Dots | Hiển thị số ảnh trong chapter (nếu có) |
| User Info | Avatar, username, timestamp |
| Actions Bar | Like, Comment, Share buttons |

**Features:**
- [ ] Vertical scroll feed (như Instagram/Locket)
- [ ] Horizontal swipe trong chapter (như Instagram carousel)
- [ ] Auto-play voice khi post visible
- [ ] Voice waveform animation khi playing
- [ ] Pull-to-refresh
- [ ] Infinite scroll với pagination
- [ ] Double-tap to like
- [ ] Long-press for quick actions

### 2. Camera View
Màn hình chụp ảnh và ghi âm voice.

**Layout Concept:**
```
┌─────────────────────────────────────┐
│  [✕]                    [⚡] [🔄]  │  ← Close, Flash, Flip camera
├─────────────────────────────────────┤
│                                     │
│                                     │
│                                     │
│         CAMERA PREVIEW              │
│         (Full Screen)               │
│                                     │
│                                     │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  [🖼]      ( ◉ )       [Effects]   │  ← Gallery, Capture, Effects
│                                     │
└─────────────────────────────────────┘

After Capture:
┌─────────────────────────────────────┐
│  [✕]                    [Tiếp →]   │
├─────────────────────────────────────┤
│                                     │
│         CAPTURED PHOTO              │
│                                     │
├─────────────────────────────────────┤
│                                     │
│        ┌─────────────────┐         │
│        │  🎤 Ghi âm      │         │  ← Voice record button
│        │  Thêm giọng nói │         │
│        └─────────────────┘         │
│                                     │
│  ──────────── hoặc ────────────    │
│                                     │
│        [ Bỏ qua, đăng ảnh ]        │
│                                     │
└─────────────────────────────────────┘

Recording Voice:
┌─────────────────────────────────────┐
│                                     │
│         CAPTURED PHOTO              │
│         (dimmed overlay)            │
│                                     │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │   🎤  ▓▓▓▓▓▓░░░░░░░░       │   │  ← Live waveform
│  │                             │   │
│  │        00:12 / 01:00        │   │  ← Duration
│  │                             │   │
│  │   [Hủy]    (⏹)    [Xong]   │   │  ← Cancel, Stop, Done
│  │                             │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

| Thành phần | Mô tả |
|------------|-------|
| Camera Preview | Full-screen camera viewfinder |
| Capture Button | Large glass circle button |
| Flash Toggle | Bật/tắt flash |
| Camera Flip | Chuyển front/back camera |
| Gallery Access | Thumbnail góc trái, mở photo library |
| Voice Record | Popup/overlay để ghi âm sau khi chụp |
| Waveform | Real-time audio visualization |

**Features:**
- [ ] Chụp ảnh với AVFoundation
- [ ] Chọn ảnh từ Photo Library
- [ ] Ghi âm voice với waveform visualization
- [ ] Preview trước khi save
- [ ] Max voice duration: 60 giây
- [ ] Filters/Effects cơ bản (optional)

**Flow:**
```
Camera → Chụp → Preview → Ghi Voice (optional) → Select Chapter/Share → Post
```

### 3. Image View (Photo Detail)
Màn hình xem chi tiết ảnh full-screen với voice playback.

**Layout Concept:**
```
┌─────────────────────────────────────┐
│  [←]     @username      [•••]      │  ← Back, User, More options
├─────────────────────────────────────┤
│                                     │
│                                     │
│                                     │
│         FULL SCREEN PHOTO           │
│         (Pinch to zoom)             │
│                                     │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  ▶️ ▓▓▓▓▓░░░░░░░░  0:24    │   │  ← Voice player overlay
│  └─────────────────────────────┘   │
│                                     │
│  ● ○ ○ ○ ○                         │  ← Page dots (if in chapter)
├─────────────────────────────────────┤
│                                     │
│  ❤️ 2.3K  💬 144  ↗️ Share        │  ← Engagement stats
│                                     │
│  Xem 144 bình luận...              │
│  2 giờ trước                        │
│                                     │
└─────────────────────────────────────┘

Swipe trong chapter:
← Ảnh trước | Ảnh sau →
```

| Thành phần | Mô tả |
|------------|-------|
| Photo Display | Full-screen, pinch-to-zoom, double-tap zoom |
| Voice Player | Glass overlay bar với play/pause, waveform, duration |
| Page Indicators | Dots cho chapter navigation |
| Engagement | Likes count, comments count, share |
| Comments Preview | Truncated comment list |
| Swipe Navigation | Left/right để xem ảnh khác trong chapter |

**Features:**
- [ ] Zoom với pinch gestures
- [ ] Voice playback với waveform
- [ ] Swipe horizontal trong chapter
- [ ] Like với double-tap
- [ ] Comments section
- [ ] Share to friends/groups
- [ ] Download option
- [ ] Report/Block

### 4. Chapter View
Màn hình xem chi tiết một chapter (album/collection).

**Layout Concept:**
```
┌─────────────────────────────────────┐
│  [←]   Chapter Name      [Edit]    │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │      COVER IMAGE            │   │
│  │                             │   │
│  │  📸 24 ảnh • 🎤 18 voice   │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  "Mô tả chapter ở đây..."          │
│                                     │
│  👤 Created by username            │
│  📅 December 2024                   │
│                                     │
├─────────────────────────────────────┤
│  [Tất cả]  [Có voice]  [Gần đây]   │  ← Filter tabs
├─────────────────────────────────────┤
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ 🎤  │ │     │ │ 🎤  │          │  ← Photo grid (3 columns)
│  └─────┘ └─────┘ └─────┘          │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │     │ │ 🎤  │ │     │          │
│  └─────┘ └─────┘ └─────┘          │
│                                     │
└─────────────────────────────────────┘

🎤 = Voice indicator badge
```

| Thành phần | Mô tả |
|------------|-------|
| Chapter Header | Cover image, title, stats |
| Description | Mô tả chapter |
| Creator Info | Avatar, name, date |
| Filter Tabs | All, Has Voice, Recent |
| Photo Grid | 3-column masonry grid |
| Voice Badge | Indicator trên ảnh có voice |

**Features:**
- [ ] Grid view với voice indicators
- [ ] Filter: tất cả, có voice, gần đây
- [ ] Sort: mới nhất, cũ nhất
- [ ] Tap ảnh → fullscreen với swipe horizontal
- [ ] Edit chapter (nếu là owner)
- [ ] Share chapter
- [ ] Collaborative chapters (invite others)

### 5. Share View (Locket-style)
Màn hình chia sẻ ảnh/chapter đến bạn bè hoặc groups.

**Layout Concept:**
```
┌─────────────────────────────────────┐
│  Gửi đến...                    [✕] │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │      PHOTO PREVIEW          │   │
│  │                             │   │
│  │  ┌───────────────────────┐ │   │
│  │  │ Thêm một tin nhắn...  │ │   │  ← Optional message
│  │  └───────────────────────┘ │   │
│  │  ● ○ ○ ○ ○                 │   │
│  └─────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│  [✕]       [➤]        [Aa+]       │  ← Cancel, Send, Add text
├─────────────────────────────────────┤
│                                     │
│  👥 Tất cả                          │  ← Share to all friends
│                                     │
│  🔵 Su    🟢 Huynh    🟡 Quyen     │  ← Recent/frequent contacts
│                                     │
│  👨‍👩‍👧‍👦 Gia đình                      │  ← Groups
│  👥 Bạn thân                        │
│                                     │
└─────────────────────────────────────┘
```

**Features:**
- [ ] Share to individual friends
- [ ] Share to groups (family, close friends)
- [ ] Add text message overlay
- [ ] Share entire chapter
- [ ] Quick share to recent contacts

## 🛠 Tech Stack
- **Language:** Swift 6.0+
- **UI Framework:** SwiftUI with Liquid Glass
- **Minimum iOS:** iOS 26.0
- **Architecture:** MVVM + Clean Architecture
- **Data Persistence:** SwiftData
- **Audio:** AVFoundation
- **Image:** PhotosUI, Core Image
- **Design System:** Apple Liquid Glass (glassmorphism)

---

# 📐 Coding Rules & Conventions

## 1. Cấu trúc Project

```
Cira-/
├── App/
│   ├── Cira_App.swift
│   └── AppDelegate.swift (nếu cần)
├── Features/
│   ├── Home/
│   │   ├── Views/
│   │   │   ├── HomeView.swift
│   │   │   ├── FeedView.swift
│   │   │   ├── PostCardView.swift
│   │   │   ├── ChapterCarouselView.swift
│   │   │   └── VoiceOverlayBar.swift
│   │   └── ViewModels/
│   │       ├── HomeViewModel.swift
│   │       └── FeedViewModel.swift
│   ├── Camera/
│   │   ├── Views/
│   │   │   ├── CameraView.swift
│   │   │   ├── CameraPreviewLayer.swift
│   │   │   ├── CaptureButton.swift
│   │   │   ├── PhotoPreviewView.swift
│   │   │   └── VoiceRecordSheet.swift
│   │   ├── ViewModels/
│   │   │   ├── CameraViewModel.swift
│   │   │   └── VoiceRecordViewModel.swift
│   │   └── Services/
│   │       └── CameraCaptureService.swift
│   ├── ImageDetail/
│   │   ├── Views/
│   │   │   ├── ImageView.swift
│   │   │   ├── ZoomableImageView.swift
│   │   │   ├── VoicePlayerBar.swift
│   │   │   ├── EngagementBar.swift
│   │   │   └── CommentsSheet.swift
│   │   └── ViewModels/
│   │       └── ImageViewModel.swift
│   ├── Chapter/
│   │   ├── Views/
│   │   │   ├── ChapterView.swift
│   │   │   ├── ChapterListView.swift
│   │   │   ├── ChapterHeaderView.swift
│   │   │   ├── ChapterPhotoGrid.swift
│   │   │   ├── CreateChapterSheet.swift
│   │   │   └── EditChapterSheet.swift
│   │   ├── ViewModels/
│   │   │   ├── ChapterViewModel.swift
│   │   │   └── ChapterListViewModel.swift
│   │   └── Models/
│   │       └── ChapterDisplayModel.swift
│   ├── Share/
│   │   ├── Views/
│   │   │   ├── ShareView.swift
│   │   │   ├── ContactPickerView.swift
│   │   │   └── GroupPickerView.swift
│   │   └── ViewModels/
│   │       └── ShareViewModel.swift
│   └── Settings/
│       ├── Views/
│       │   └── SettingsView.swift
│       └── ViewModels/
│           └── SettingsViewModel.swift
├── Core/
│   ├── Services/
│   │   ├── AudioService/
│   │   │   ├── AudioRecorderService.swift
│   │   │   └── AudioPlayerService.swift
│   │   ├── ImageService/
│   │   │   ├── ImagePickerService.swift
│   │   │   └── ImageProcessingService.swift
│   │   └── StorageService/
│   │       ├── PhotoStorageService.swift
│   │       └── ChapterStorageService.swift
│   ├── Models/
│   │   ├── Photo.swift
│   │   ├── VoiceNote.swift
│   │   └── Chapter.swift
│   ├── Extensions/
│   │   ├── View+Extensions.swift
│   │   ├── Date+Extensions.swift
│   │   └── Color+Extensions.swift
│   └── Utilities/
│       ├── Constants.swift
│       ├── FileManager+Extensions.swift
│       └── Permissions.swift
├── UI/
│   ├── Components/
│   │   ├── Buttons/
│   │   │   ├── CiraGlassButton.swift
│   │   │   ├── CircleGlassButton.swift
│   │   │   └── FloatingRecordButton.swift
│   │   ├── Cards/
│   │   │   ├── PostCard.swift
│   │   │   ├── ChapterCard.swift
│   │   │   └── VoiceNoteCard.swift
│   │   ├── VoicePlayer/
│   │   │   ├── VoicePlayerView.swift
│   │   │   ├── WaveformView.swift
│   │   │   ├── AudioProgressBar.swift
│   │   │   └── VoiceOverlayBar.swift
│   │   ├── Feed/
│   │   │   ├── FeedItemView.swift
│   │   │   ├── PageIndicator.swift
│   │   │   └── EngagementActions.swift
│   │   └── Common/
│   │       ├── LoadingView.swift
│   │       ├── EmptyStateView.swift
│   │       ├── ErrorView.swift
│   │       └── AvatarView.swift
│   ├── Styles/
│   │   ├── GlassStyles.swift
│   │   └── Typography.swift
│   └── Modifiers/
│       ├── GlassModifiers.swift
│       └── AnimationModifiers.swift
├── Resources/
│   ├── Assets.xcassets/
│   ├── Localizable.strings
│   └── Fonts/
└── Tests/
    ├── UnitTests/
    │   ├── Services/
    │   └── ViewModels/
    └── UITests/
```

## 2. Naming Conventions

### Files & Types
```swift
// ✅ PascalCase cho Types
struct PhotoItem { }
class AudioRecorderService { }
enum MediaType { }
protocol ImageStorable { }

// ✅ Suffix theo loại
// Views: *View
struct HomeView { }
struct PhotoCardView { }

// ViewModels: *ViewModel
class HomeViewModel: ObservableObject { }

// Services: *Service
class AudioRecorderService { }

// Models: Tên rõ ràng, không suffix
struct Photo { }
struct VoiceNote { }
```

### Variables & Functions
```swift
// ✅ camelCase cho variables và functions
let photoCount = 10
var isRecording = false
func startRecording() { }
func fetchPhotos(from album: Album) -> [Photo] { }

// ✅ Boolean bắt đầu với is, has, should, can
var isPlaying: Bool
var hasVoiceNote: Bool
var shouldAutoPlay: Bool
var canRecord: Bool

// ❌ Tránh
var playing: Bool  // Thiếu prefix
var voiceNote: Bool  // Không rõ nghĩa boolean
```

### Constants
```swift
// ✅ Sử dụng enum namespace
enum Constants {
    enum Audio {
        static let maxRecordingDuration: TimeInterval = 60
        static let sampleRate: Double = 44100
    }
    
    enum Image {
        static let thumbnailSize = CGSize(width: 150, height: 150)
        static let compressionQuality: CGFloat = 0.8
    }
}

// ✅ Hoặc extension cho từng module
extension PhotoItem {
    static let maxPhotosPerAlbum = 1000
}
```

## 3. SwiftUI Guidelines

### View Structure
```swift
struct PhotoDetailView: View {
    // MARK: - Properties
    @StateObject private var viewModel: PhotoDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var isPlaying = false
    @State private var showDeleteAlert = false
    
    // MARK: - Constants
    private let cornerRadius: CGFloat = 12
    
    // MARK: - Body
    var body: some View {
        content
            .navigationTitle("Photo")
            .toolbar { toolbarContent }
            .alert("Delete?", isPresented: $showDeleteAlert) {
                alertButtons
            }
    }
    
    // MARK: - View Components
    @ViewBuilder
    private var content: some View {
        // ...
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // ...
    }
}
```

### Computed Properties cho Subviews
```swift
// ✅ Tách subviews thành computed properties
var body: some View {
    VStack {
        headerSection
        photoGrid
        controlBar
    }
}

private var headerSection: some View {
    // ...
}

private var photoGrid: some View {
    // ...
}

// ✅ Sử dụng @ViewBuilder khi cần conditional
@ViewBuilder
private var controlBar: some View {
    if isRecording {
        RecordingControlsView()
    } else {
        IdleControlsView()
    }
}
```

### Reusable Components
```swift
// ✅ Tạo components riêng cho UI dùng lại
struct CiraButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, destructive
    }
    
    var body: some View {
        Button(title, action: action)
            .buttonStyle(style.swiftUIStyle)
    }
}
```

## 3.5 Liquid Glass UI Guidelines (iOS 26+)

### Giới thiệu
Liquid Glass là design language mới của Apple từ iOS 26, mang lại hiệu ứng kính trong suốt, động và phản chiếu ánh sáng tự nhiên. Cira app sẽ sử dụng Liquid Glass để tạo UI hiện đại và đẹp mắt.

### Glass Background Effects
```swift
// ✅ Sử dụng .glassEffect cho background
struct PhotoCardView: View {
    let photo: Photo
    
    var body: some View {
        VStack {
            AsyncImage(url: photo.thumbnailURL)
            Text(photo.title)
        }
        .padding()
        .glassEffect()  // Liquid Glass background
    }
}

// ✅ Custom glass effect với tint color
struct VoiceNoteCard: View {
    var body: some View {
        HStack {
            Image(systemName: "waveform")
            Text("Voice Note")
        }
        .padding()
        .glassEffect(.regular.tint(.blue.opacity(0.3)))
    }
}
```

### Liquid Glass Button Styles
```swift
// ✅ Button với Liquid Glass effect
struct CiraGlassButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .buttonStyle(.glass)  // Built-in glass button style
    }
}

// ✅ Custom Glass Button với các variants
struct CiraButton: View {
    let title: String
    let style: GlassStyle
    let action: () -> Void
    
    enum GlassStyle {
        case primary    // Blue tint glass
        case secondary  // Clear glass
        case destructive // Red tint glass
        case recording  // Red pulsing glass (for record button)
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .buttonStyle(.glass)
        .glassEffectTint(tintColor)
    }
    
    private var tintColor: Color {
        switch style {
        case .primary: return .blue.opacity(0.4)
        case .secondary: return .clear
        case .destructive: return .red.opacity(0.4)
        case .recording: return .red.opacity(0.6)
        }
    }
}

// ✅ Circular Glass Button (cho camera, record)
struct CircleGlassButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .clipShape(Circle())
    }
}
```

### Glass Navigation & TabBar
```swift
// ✅ TabView với Liquid Glass (tự động từ iOS 26)
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            CameraView()
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
                .tag(1)
            
            ChapterListView()
                .tabItem {
                    Label("Chapters", systemImage: "book.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        // iOS 26+ tự động apply glass effect cho TabBar
    }
}

// ✅ Home Feed View với vertical scroll
struct HomeView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostCardView(post: post)
                        .containerRelativeFrame(.vertical)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)  // Snap to each post
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// ✅ Post Card với horizontal swipe cho chapter
struct PostCardView: View {
    let post: Post
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo carousel (nếu là chapter)
            TabView(selection: $currentIndex) {
                ForEach(Array(post.photos.enumerated()), id: \.offset) { index, photo in
                    ZStack(alignment: .bottom) {
                        // Photo
                        AsyncImage(url: photo.imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        
                        // Voice overlay bar
                        if let voice = photo.voiceNote {
                            VoiceOverlayBar(voiceNote: voice)
                                .padding()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: UIScreen.main.bounds.width * 1.25)  // 4:5 aspect
            
            // User info & actions
            PostFooterView(post: post)
        }
        .background(Color.white)
    }
}

// ✅ Voice Overlay Bar (như Instagram voice message)
struct VoiceOverlayBar: View {
    let voiceNote: VoiceNote
    @State private var isPlaying = false
    @State private var progress: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: { isPlaying.toggle() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Waveform
            WaveformView(
                levels: voiceNote.waveformLevels,
                progress: progress,
                activeColor: .white,
                inactiveColor: .white.opacity(0.4)
            )
            
            // Duration
            Text(voiceNote.formattedDuration)
                .font(.caption)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.pink.opacity(0.6), .orange.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
        }
    }
}

// ✅ Navigation bar với glass effect
struct GalleryView: View {
    var body: some View {
        NavigationStack {
            PhotoGridView()
                .navigationTitle("Gallery")
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {}) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.glass)
                    }
                }
        }
    }
}
```

### Glass Cards & Containers
```swift
// ✅ Photo Card với Glass overlay
struct PhotoWithVoiceCard: View {
    let photo: Photo
    @State private var isPlaying = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Photo image
            AsyncImage(url: photo.imageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            
            // Glass overlay for voice controls
            if photo.hasVoiceNote {
                HStack {
                    Button(action: { isPlaying.toggle() }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.glass)
                    
                    VoiceWaveformView(isPlaying: isPlaying)
                    
                    Text(photo.voiceNote?.formattedDuration ?? "0:00")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.tint(.black.opacity(0.2)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// ✅ Floating Action Button với Glass
struct FloatingRecordButton: View {
    @Binding var isRecording: Bool
    
    var body: some View {
        Button(action: { isRecording.toggle() }) {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.title)
                .foregroundStyle(isRecording ? .red : .primary)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.glass)
        .glassEffect(
            isRecording 
                ? .regular.tint(.red.opacity(0.4))
                : .regular
        )
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isRecording)
    }
}
```

### Glass Modals & Sheets
```swift
// ✅ Sheet với Glass background
struct VoiceRecorderSheet: View {
    @Binding var isPresented: Bool
    @StateObject var viewModel = VoiceRecorderViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            // Waveform visualization
            AudioWaveformView(levels: viewModel.audioLevels)
                .frame(height: 100)
            
            // Time display
            Text(viewModel.formattedTime)
                .font(.system(size: 48, weight: .light, design: .monospaced))
            
            // Control buttons
            HStack(spacing: 32) {
                CircleGlassButton(icon: "xmark", size: 56) {
                    isPresented = false
                }
                
                FloatingRecordButton(isRecording: $viewModel.isRecording)
                
                CircleGlassButton(icon: "checkmark", size: 56) {
                    viewModel.save()
                    isPresented = false
                }
                .disabled(!viewModel.hasRecording)
            }
        }
        .padding(32)
        .presentationBackground(.ultraThinMaterial)  // Glass sheet background
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
```

### Glass Effect Utilities
```swift
// ✅ Custom Glass Modifiers
extension View {
    /// Apply Cira's standard glass card style
    func ciraGlassCard() -> some View {
        self
            .padding()
            .glassEffect(.regular.tint(.white.opacity(0.1)))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    /// Apply glass effect with custom intensity
    func ciraGlass(intensity: GlassIntensity = .regular) -> some View {
        self.glassEffect(intensity.effect)
    }
}

enum GlassIntensity {
    case subtle     // Nhẹ, gần như trong suốt
    case regular    // Tiêu chuẩn
    case prominent  // Đậm, blur nhiều hơn
    
    var effect: some GlassEffect {
        switch self {
        case .subtle:
            return .regular.tint(.white.opacity(0.05))
        case .regular:
            return .regular
        case .prominent:
            return .regular.tint(.white.opacity(0.2))
        }
    }
}
```

### Dark Mode & Glass
```swift
// ✅ Glass tự động adapt với Dark/Light mode
struct AdaptiveGlassCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            // Content
        }
        .glassEffect(
            colorScheme == .dark
                ? .regular.tint(.white.opacity(0.1))
                : .regular.tint(.black.opacity(0.05))
        )
    }
}
```

### Animation với Glass
```swift
// ✅ Animated glass transitions
struct RecordingIndicator: View {
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 12, height: 12)
            .glassEffect(.regular.tint(.red.opacity(0.3)))
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
```

### Liquid Glass Best Practices

| ✅ Nên làm | ❌ Không nên |
|-----------|-------------|
| Sử dụng glass cho floating elements | Dùng glass cho toàn bộ background |
| Kết hợp glass với shadows nhẹ | Chồng nhiều layer glass lên nhau |
| Để content phía sau hiển thị qua glass | Sử dụng glass với low contrast text |
| Sử dụng tint color phù hợp với brand | Dùng quá nhiều màu tint khác nhau |
| Test trên cả light và dark mode | Quên kiểm tra accessibility |

## 4. MVVM Pattern

### ViewModel
```swift
@MainActor
final class PhotoGalleryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var photos: [Photo] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let photoService: PhotoServiceProtocol
    private let audioService: AudioServiceProtocol
    
    // MARK: - Init
    init(
        photoService: PhotoServiceProtocol = PhotoService(),
        audioService: AudioServiceProtocol = AudioService()
    ) {
        self.photoService = photoService
        self.audioService = audioService
    }
    
    // MARK: - Public Methods
    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            photos = try await photoService.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deletePhoto(_ photo: Photo) async {
        // ...
    }
}
```

### View-ViewModel Connection
```swift
struct PhotoGalleryView: View {
    @StateObject private var viewModel = PhotoGalleryViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                photoGrid
            }
        }
        .task {
            await viewModel.loadPhotos()
        }
    }
}
```

## 5. Error Handling

```swift
// ✅ Định nghĩa custom errors
enum AudioError: LocalizedError {
    case microphonePermissionDenied
    case recordingFailed(underlying: Error)
    case playbackFailed(underlying: Error)
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to record voice notes"
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .fileNotFound:
            return "Audio file not found"
        }
    }
}

// ✅ Sử dụng Result type hoặc async throws
func saveVoiceNote(_ data: Data) async throws -> VoiceNote {
    guard let url = try? createAudioFileURL() else {
        throw AudioError.fileNotFound
    }
    // ...
}
```

## 6. Services & Protocols

```swift
// ✅ Protocol-oriented design
protocol AudioRecordable {
    var isRecording: Bool { get }
    func startRecording() async throws
    func stopRecording() async throws -> URL
}

protocol AudioPlayable {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    func play(url: URL) async throws
    func pause()
    func stop()
}

// ✅ Service implementation
final class AudioService: AudioRecordable, AudioPlayable {
    // Implementation
}
```

## 7. SwiftData Models

```swift
import SwiftData

@Model
final class Photo {
    var id: UUID
    var createdAt: Date
    var imageData: Data?
    var thumbnailData: Data?
    
    @Relationship(deleteRule: .cascade)
    var voiceNote: VoiceNote?
    
    @Relationship(inverse: \Chapter.photos)
    var chapter: Chapter?
    
    init(imageData: Data) {
        self.id = UUID()
        self.createdAt = Date()
        self.imageData = imageData
    }
}

@Model
final class VoiceNote {
    var id: UUID
    var duration: TimeInterval
    var audioFileName: String
    var createdAt: Date
    
    var photo: Photo?
    
    init(audioFileName: String, duration: TimeInterval) {
        self.id = UUID()
        self.audioFileName = audioFileName
        self.duration = duration
        self.createdAt = Date()
    }
}

@Model
final class Chapter {
    var id: UUID
    var name: String
    var descriptionText: String?
    var coverImageData: Data?
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify)
    var photos: [Photo] = []
    
    var photoCount: Int {
        photos.count
    }
    
    var hasVoiceNotes: Bool {
        photos.contains { $0.voiceNote != nil }
    }
    
    init(name: String, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.descriptionText = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

## 7.5 Navigation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    TabView (Liquid Glass)                        │
├───────────────────┬───────────────────┬─────────────────────────┤
│      Home         │      Camera       │       My Story          │
│     (Feed)        │       Tab         │        Tab              │
└────────┬──────────┴─────────┬─────────┴────────────┬────────────┘
         │                    │                      │
         ▼                    ▼                      ▼
   ┌──────────┐        ┌──────────┐           ┌──────────────┐
   │ FeedView │        │CameraView│           │ MyStoryView  │
   │ (Scroll) │        └────┬─────┘           │  (Profile)   │
   └────┬─────┘             │                 └──────┬───────┘
        │                   │                        │
        │ tap post          │ capture                │ tap chapter
        ▼                   ▼                        ▼
   ┌──────────┐        ┌──────────┐           ┌──────────────┐
   │ImageView │        │PhotoPreview│          │ ChapterView  │
   │(Detail)  │        │  View    │           │  (Detail)    │
   │          │        └────┬─────┘           └──────┬───────┘
   │ ←→ swipe │             │                        │
   │ in chapter│            │ record voice           │ tap photo
   └────┬─────┘             ▼                        ▼
        │              ┌──────────┐           ┌──────────────┐
        │              │VoiceRecord│           │  ImageView   │
        │              │  Sheet   │           │ (←→ swipe)   │
        │              └────┬─────┘           └──────────────┘
        │ share             │
        ▼                   │ post
   ┌──────────┐             ▼
   │ShareSheet│        ┌──────────┐
   │          │        │ShareSheet│
   └──────────┘        └──────────┘
```

## 7.6 Tab Bar Structure

| Tab | Icon | Label | View |
|-----|------|-------|------|
| 1 | `house.fill` | Home | FeedView - Vertical scroll posts |
| 2 | `camera.fill` | Camera | CameraView - Capture & record |
| 3 | `book.fill` | My Story | MyStoryView - User's chapters |

## 7.7 Gesture Navigation

| Gesture | Màn hình | Action |
|---------|----------|--------|
| Swipe Up/Down | Home Feed | Scroll to next/previous post |
| Swipe Left/Right | Home Feed (chapter post) | Navigate photos in chapter |
| Swipe Left/Right | Image Detail (in chapter) | Navigate photos in chapter |
| Double Tap | Image Detail | Like photo |
| Pinch | Image Detail | Zoom in/out |
| Long Press | Any photo | Quick actions menu |
| Pull Down | Home Feed | Refresh feed |
```

## 8. Code Documentation

```swift
/// A service that handles audio recording and playback functionality.
///
/// Use this service to record voice notes and play them back.
///
/// ## Example
/// ```swift
/// let audioService = AudioService()
/// try await audioService.startRecording()
/// // ... user records
/// let url = try await audioService.stopRecording()
/// ```
final class AudioService {
    
    /// Starts recording audio from the device microphone.
    /// - Throws: `AudioError.microphonePermissionDenied` if microphone access is not granted.
    /// - Note: Call `stopRecording()` to finish and save the recording.
    func startRecording() async throws {
        // ...
    }
}
```

## 9. Testing Guidelines

```swift
// ✅ Unit Test naming: test_[method]_[scenario]_[expectedResult]
final class AudioServiceTests: XCTestCase {
    
    var sut: AudioService!
    var mockRecorder: MockAudioRecorder!
    
    override func setUp() {
        super.setUp()
        mockRecorder = MockAudioRecorder()
        sut = AudioService(recorder: mockRecorder)
    }
    
    func test_startRecording_whenPermissionGranted_shouldBeginRecording() async throws {
        // Given
        mockRecorder.permissionGranted = true
        
        // When
        try await sut.startRecording()
        
        // Then
        XCTAssertTrue(sut.isRecording)
    }
    
    func test_startRecording_whenPermissionDenied_shouldThrowError() async {
        // Given
        mockRecorder.permissionGranted = false
        
        // When/Then
        await XCTAssertThrowsError(try await sut.startRecording()) { error in
            XCTAssertEqual(error as? AudioError, .microphonePermissionDenied)
        }
    }
}
```

## 10. Git Conventions

### Branch Naming
```
feature/add-voice-recording
bugfix/audio-playback-crash
refactor/photo-storage-service
hotfix/permission-handling
```

### Commit Messages
```
feat: add voice recording functionality
fix: resolve audio playback crash on iOS 17
refactor: improve photo storage performance
docs: update README with setup instructions
test: add unit tests for AudioService
chore: update dependencies
```

## 11. Performance Guidelines

```swift
// ✅ Lazy loading cho images
struct PhotoThumbnail: View {
    let photo: Photo
    
    var body: some View {
        AsyncImage(url: photo.thumbnailURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Color.gray.opacity(0.3)
        }
    }
}

// ✅ Background processing cho heavy tasks
func processImage(_ data: Data) async -> UIImage? {
    await Task.detached(priority: .userInitiated) {
        // Heavy image processing
    }.value
}

// ✅ Avoid retain cycles
class AudioPlayerViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    func setupBindings() {
        audioService.playbackProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.currentProgress = progress
            }
            .store(in: &cancellables)
    }
}
```

## 12. Accessibility

```swift
// ✅ Thêm accessibility labels
Image(systemName: "mic.fill")
    .accessibilityLabel("Record voice note")
    .accessibilityHint("Double tap to start recording")

// ✅ Dynamic Type support
Text(photo.caption)
    .font(.body)
    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
```

---

## 📋 Checklist trước khi commit

- [ ] Code follows naming conventions
- [ ] No force unwrapping (!) without justification
- [ ] Error handling implemented
- [ ] Accessibility labels added for UI elements
- [ ] Unit tests written for new functionality
- [ ] No hardcoded strings (use Localizable.strings)
- [ ] No memory leaks (weak self in closures)
- [ ] Code documented with comments where needed

---

*Last updated: December 2024*
