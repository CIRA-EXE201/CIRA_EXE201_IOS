import SwiftUI
import OSLog
import Auth

private let logger = Logger(subsystem: "tutu.Cira-", category: "LikeDebug")

struct PostControlsView: View {
    let post: Post
    let onLikeToggle: (UUID) -> Void
    
    @State private var isShowingComments = false
    @State private var isShowingSendMessage = false
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var isLiking = false
    
    init(post: Post, onLikeToggle: @escaping (UUID) -> Void) {
        self.post = post
        self.onLikeToggle = onLikeToggle
        _isLiked = State(initialValue: post.isLiked)
        _likeCount = State(initialValue: post.likeCount)
        _commentCount = State(initialValue: post.commentCount)
        logger.debug("Init called for \(post.id.uuidString). isLiked: \(post.isLiked)")
    }
    
    private var isMyPost: Bool {
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
            }
            
            
            if !isMyPost {
                // Interaction Bar (Input + Icons)
                HStack(spacing: 12) {
                    // Message Input
                    Button(action: { isShowingSendMessage = true }) {
                        HStack {
                            Text("Gửi tin nhắn...")
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
                            isShowingSendMessage = true
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
        .sheet(isPresented: $isShowingSendMessage) {
            SendMessageSheet(post: post)
        }
        .sheet(isPresented: $isShowingComments) {
            CommentSheet(postId: post.photos.first?.id ?? post.id) // Fallback for id mapping
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
        return "1d"
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
