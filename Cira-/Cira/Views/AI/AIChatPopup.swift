//
//  AIChatPopup.swift
//  Cira
//
//  Chat popup for AI Assistant — messages, input, and voice
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - AI Chat Popup
struct AIChatPopup: View {
    @Binding var isPresented: Bool
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(isUser: false, text: "Xin chào! Tôi có thể giúp bạn tìm kiếm ký ức, tạo album hoặc trả lời câu hỏi về ảnh của bạn. Hãy hỏi tôi bất cứ điều gì! 😊")
    ]
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            // Header
            HStack {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.black)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cira AI")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Trợ lý Ký ức")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack(spacing: 12) {
                // Text field
                HStack(spacing: 8) {
                    TextField("Nhập tin nhắn...", text: $messageText)
                        .focused($isInputFocused)
                    
                    if !messageText.isEmpty {
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, messageText.isEmpty ? 16 : 8)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.08))
                )
                
                // Voice button
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        )
        .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(.all, edges: .bottom)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            isInputFocused = true
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(isUser: true, text: messageText)
        messages.append(userMessage)
        
        let userText = messageText
        messageText = ""
        
        // Simulate AI response
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            let response = generateAIResponse(for: userText)
            messages.append(ChatMessage(isUser: false, text: response))
        }
    }
    
    private func generateAIResponse(for query: String) -> String {
        let responses = [
            "Tôi tìm thấy 12 ảnh liên quan đến chủ đề này trong album của bạn. Bạn muốn xem không? 📸",
            "Đây là một kỷ niệm đẹp! Bạn có 3 ảnh từ ngày đó với 2 bản ghi âm. ❤️",
            "Tôi có thể tạo album mới với những ảnh này. Bạn muốn đặt tên album là gì? 📚",
            "Kỷ niệm này được lưu 6 tháng trước. Thời gian trôi nhanh thật! ⏰",
        ]
        return responses.randomElement() ?? "Tôi hiểu rồi! Để tôi tìm cho bạn... 🔍"
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

// MARK: - Chat Bubble
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            
            if !message.isUser {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(.black)
                }
            }
            
            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.isUser ? Color.black : Color.gray.opacity(0.1))
                )
                .foregroundStyle(message.isUser ? .white : .primary)
            
            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}
