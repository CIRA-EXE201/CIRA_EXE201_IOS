import SwiftUI

struct SendMessageSheet: View {
    let post: Post
    @State private var messageText = ""
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Post Preview
                HStack(alignment: .top, spacing: 12) {
                    // Thumbnail
                    if let firstPhoto = post.photos.first, let url = firstPhoto.imageURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let firstPhoto = post.photos.first, let data = firstPhoto.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gửi cho \(post.author.username)")
                            .font(.headline)
                        
                        Text("Phản hồi về bài viết của họ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
                
                Divider()
                
                // Input Area
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Viết tin nhắn...", text: $messageText, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .focused($isInputFocused)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Tin nhắn mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Group {
                        if isSending {
                            ProgressView()
                        }
                    }
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @FocusState private var isInputFocused: Bool
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let sentText = messageText
        isSending = true
        
        Task {
            do {
                _ = try await MessageService.shared.sendMessage(
                    to: post.author.id,
                    postId: post.id,
                    content: sentText
                )
                dismiss()
            } catch {
                print("Failed to send message: \(error)")
                isSending = false
            }
        }
    }
}
