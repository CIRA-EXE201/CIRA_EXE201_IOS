import SwiftUI
import Supabase

struct ConversationView: View {
    let conversation: Conversation
    @State private var messages: [DirectMessage] = []
    @State private var newMessageText = ""
    @State private var isSending = false
    @State private var isLoading = true
    
    // For auto-scrolling
    @State private var bottomRef = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if messages.isEmpty {
                Spacer()
                Text("Bắt đầu cuộc trò chuyện.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                MessageBubble(message: msg, otherUserAvatarData: conversation.otherUserAvatarData)
                                    .id(msg.id)
                            }
                            
                            Color.clear
                                .frame(height: 1)
                                .id(bottomRef)
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        // Scroll to bottom when messages update
                        withAnimation {
                            proxy.scrollTo(bottomRef, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        // Scroll down initially
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(bottomRef, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input Area
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Tin nhắn...", text: $newMessageText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle(conversation.otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        do {
            messages = try await MessageService.shared.fetchMessages(with: conversation.id)
        } catch {
            print("Failed to load messages: \(error)")
        }
        isLoading = false
    }
    
    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let sentText = newMessageText
        isSending = true
        newMessageText = ""
        
        Task {
            do {
                let newMsg = try await MessageService.shared.sendMessage(
                    to: conversation.id,
                    postId: nil,
                    content: sentText
                )
                withAnimation {
                    messages.append(newMsg)
                }
            } catch {
                print("Failed to send message: \(error)")
                newMessageText = sentText
            }
            isSending = false
        }
    }
}

struct MessageBubble: View {
    let message: DirectMessage
    let otherUserAvatarData: String?
    
    private var isMe: Bool {
        guard let myId = SupabaseManager.shared.currentUser?.id else { return false }
        return message.sender_id == myId
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isMe {
                // Other User Avatar
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if let avatarStr = otherUserAvatarData,
                           let data = Data(base64Encoded: avatarStr),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                    }
            } else {
                Spacer(minLength: 40)
            }
            
            // Message Content
            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMe ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isMe ? .white : .black)
                .font(.system(size: 16))
                .clipShape(BubbleShape(myMessage: isMe))
            
            if isMe {
                // Optional read receipt or status
            } else {
                Spacer(minLength: 40)
            }
        }
    }
}

struct BubbleShape: Shape {
    var myMessage: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: [
            .topLeft, .topRight, myMessage ? .bottomLeft : .bottomRight
        ], cornerRadii: CGSize(width: 16, height: 16))
        
        return Path(path.cgPath)
    }
}
