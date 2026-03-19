import SwiftUI
import OSLog
import Auth

private let logger = Logger(subsystem: "tutu.Cira-", category: "LikeDebug")

struct PostControlsView: View {
    let post: Post
    let onLikeToggle: (UUID) -> Void
    
    @State private var isShowingComments = false
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var isLiking = false
    let isQuickReplyFocused: Bool
    let onReplyTap: () -> Void
    
    // Report/Block states
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var showBlockedToast = false
    @State private var isBlocking = false
    var onBlockUser: ((UUID) -> Void)? = nil
    
    init(post: Post, isQuickReplyFocused: Bool = false, onLikeToggle: @escaping (UUID) -> Void, onReplyTap: @escaping () -> Void, onBlockUser: ((UUID) -> Void)? = nil) {
        self.post = post
        self.isQuickReplyFocused = isQuickReplyFocused
        self.onLikeToggle = onLikeToggle
        self.onReplyTap = onReplyTap
        self.onBlockUser = onBlockUser
        _isLiked = State(initialValue: post.isLiked)
        _likeCount = State(initialValue: post.likeCount)
        _commentCount = State(initialValue: post.commentCount)
        logger.debug("Init called for \(post.id.uuidString). isLiked: \(post.isLiked)")
    }
    
    private var isMyPost: Bool {
        if post.author.username.lowercased() == "me" {
            return true
        }
        guard let currentUserStr = SupabaseManager.shared.currentUser?.id.uuidString,
              let currentUserId = UUID(uuidString: currentUserStr) else {
            return false
        }
        return post.author.id == currentUserId
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Author & Time
            HStack(spacing: 12) {
                // Author Avatar
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(post.author.username.prefix(1).uppercased())
                            .font(.caption)
                            .foregroundStyle(.black.opacity(0.7))
                    }
                
                // Name & Time
                HStack(spacing: 6) {
                    Text(post.author.username.capitalized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.85))
                    
                    Text(formatTime(post.createdAt))
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.5))
                }
                Spacer()
                
                // Report/Block menu (only for other users' posts)
                if !isMyPost {
                    Menu {
                        Button(role: .none) {
                            showReportSheet = true
                        } label: {
                            Label("Báo cáo", systemImage: "flag")
                        }
                        
                        Button(role: .destructive) {
                            showBlockAlert = true
                        } label: {
                            Label("Chặn \(post.author.username)", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }
            
            
            if !isMyPost {
                // Interaction Bar (Input + Icons)
                HStack(spacing: 12) {
                    // Message Input
                    Button(action: { onReplyTap() }) {
                        HStack {
                            Text("Trả lời...")
                                .font(.system(size: 15))
                                .foregroundStyle(.black.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.06))
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(isQuickReplyFocused ? 0 : 1)
                    
                    // Reactions
                    HStack(spacing: 16) {
                        Button(action: {
                            toggleLike()
                        }) {
                            HStack(spacing: 4) {
                                Text(isLiked ? "❤️" : "🤍") // Better heart emoji
                                    .font(.system(size: 24))
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                
                                if likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.black.opacity(0.7))
                                }
                            }
                        }
                        .disabled(isLiking)
                        
                        Button(action: {
                            onReplyTap()
                        }) {
                            Image(systemName: "paperplane")
                                .font(.system(size: 20))
                                .foregroundStyle(.black.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $isShowingComments) {
            CommentSheet(postId: post.photos.first?.id ?? post.id) // Fallback for id mapping
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(
                postId: post.id,
                reportedUserId: post.author.id,
                reportedUsername: post.author.username
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Chặn \(post.author.username)?", isPresented: $showBlockAlert) {
            Button("Huỷ", role: .cancel) { }
            Button("Chặn", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Bạn sẽ không còn thấy bài đăng từ \(post.author.username). Bạn có thể bỏ chặn trong phần cài đặt.")
        }
        .overlay {
            if showBlockedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                        Text("Đã chặn \(post.author.username)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.85)))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }
                .animation(.spring(response: 0.3), value: showBlockedToast)
            }
        }
        .onChange(of: post.isLiked) { oldValue, newValue in
            logger.debug("onChange(isLiked) for \(post.id.uuidString). old: \(oldValue), new: \(newValue)")
            isLiked = newValue
        }
        .onChange(of: post.likeCount) { oldValue, newValue in
            logger.debug("onChange(likeCount) for \(post.id.uuidString). old: \(oldValue), new: \(newValue)")
            likeCount = newValue
        }
        .onChange(of: post.commentCount) { oldValue, newValue in
            commentCount = newValue
        }
    }
    
    // MARK: - Block User
    private func blockUser() {
        isBlocking = true
        Task {
            do {
                try await ReportService.shared.blockUser(userId: post.author.id)
                withAnimation {
                    showBlockedToast = true
                }
                // Notify parent to remove from feed
                onBlockUser?(post.author.id)
                
                // Auto-hide toast
                try? await Task.sleep(for: .seconds(2))
                withAnimation {
                    showBlockedToast = false
                }
            } catch {
                print("Failed to block user: \(error)")
            }
            isBlocking = false
        }
    }
    
    private func toggleLike() {
        guard !isLiking else { return }
        isLiking = true
        
        let previousLikeState = isLiked
        let previousCount = likeCount
        logger.debug("User tapped Like for \(post.id.uuidString). current: \(previousLikeState)")
        
        // 1. Optimistic UI update (Local State)
        isLiked.toggle()
        if isLiked {
            likeCount += 1
        } else {
            likeCount = max(0, likeCount - 1)
        }
        
        // 2. Sync with Parent ViewModel (So re-renders use updated data)
        onLikeToggle(post.id)
        
        Task {
            do {
                try await LikeService.shared.toggleLike(for: post.id)
                logger.debug("LikeService finished successfully for \(post.id.uuidString)")
            } catch {
                let errStr = "Failed to toggle like: \(error)\\n"
                logger.error("LikeService threw error \(errStr)")
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                try? errStr.write(to: docs.appendingPathComponent("like_error.log"), atomically: true, encoding: .utf8)
                
                // Revert on failure
                DispatchQueue.main.async {
                    self.isLiked = previousLikeState
                    self.likeCount = previousCount
                    self.onLikeToggle(post.id) // Revert parent too
                }
            }
            isLiking = false
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "vừa xong" }
        if diff < 3600 { return "\(diff/60)ph" }
        if diff < 86400 { return "\(diff/3600)g" }
        let days = diff / 86400
        if days < 7 { return "\(days)d" }
        if days < 30 { return "\(days/7)w" }
        if days < 365 { return "\(days/30)mo" }
        return "\(days/365)y"
    }
}

struct ReactionButton: View {
    let emoji: String
    
    var body: some View {
        Button(action: {}) {
            Text(emoji)
                .font(.system(size: 24))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
    }
}

