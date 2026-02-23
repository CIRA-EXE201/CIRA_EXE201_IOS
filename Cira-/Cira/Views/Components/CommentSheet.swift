import SwiftUI

struct CommentSheet: View {
    let postId: UUID
    @State private var comments: [PostComment] = []
    @State private var newCommentText = ""
    @State private var isSubmitting = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    Text("Chưa có bình luận nào")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // Input Area
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Viết bình luận...", text: $newCommentText, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Button {
                        submitComment()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Bình luận")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Group {
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
            }
            .task {
                await loadComments()
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func loadComments() async {
        isLoading = true
        do {
            comments = try await CommentService.shared.fetchComments(for: postId)
        } catch {
            print("Failed to load comments: \(error)")
        }
        isLoading = false
    }
    
    private func submitComment() {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let textToSubmit = newCommentText
        isSubmitting = true
        newCommentText = ""
        
        Task {
            do {
                let newComment = try await CommentService.shared.addComment(to: postId, content: textToSubmit)
                withAnimation {
                    comments.append(newComment)
                }
            } catch {
                print("Failed to submit comment: \(error)")
                newCommentText = textToSubmit // Restore text on failure
            }
            isSubmitting = false
        }
    }
}

struct CommentRow: View {
    let comment: PostComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(comment.author_username?.prefix(1).uppercased() ?? "?")
                        .font(.subheadline.bold())
                        .foregroundStyle(.gray)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(comment.author_username ?? "Unknown User")
                        .font(.subheadline.bold())
                    
                    Text(formatTime(comment.created_at))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(comment.content)
                    .font(.subheadline)
            }
            
            Spacer()
        }
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "vừa xong" }
        if diff < 3600 { return "\(diff/60)p" }
        if diff < 86400 { return "\(diff/3600)g" }
        return "\(diff/86400)n"
    }
}
