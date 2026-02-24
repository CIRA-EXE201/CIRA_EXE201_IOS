import SwiftUI
import Supabase

struct MessageInboxView: View {
    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundStyle(.tertiary)
                        Text("Chưa có tin nhắn nào")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Phản hồi bài viết của người khác để bắt đầu trò chuyện.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink {
                                ConversationView(conversation: conversation)
                            } label: {
                                ConversationRow(conversation: conversation)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tin nhắn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray.opacity(0.5))
                            .font(.system(size: 24))
                    }
                }
            }
            .task {
                await loadConversations()
            }
        }
    }
    
    private func loadConversations() async {
        isLoading = true
        do {
            conversations = try await MessageService.shared.fetchConversations()
        } catch {
            print("Failed to load conversations: \(error)")
        }
        isLoading = false
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    if let avatarStr = conversation.otherUserAvatarData,
                       let data = Data(base64Encoded: avatarStr),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else {
                        Text(conversation.otherUserName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.gray)
                    }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(.headline)
                    Spacer()
                    Text(formatTime(conversation.lastMessageDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Vừa xong" }
        if diff < 3600 { return "\(diff/60)p" }
        if diff < 86400 { return "\(diff/3600)g" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}
