//
//  ContentView.swift
//  Cira-
//
//  Main TabView with Liquid Glass effect
//  Tabs: Home, My Story + AI Voice Chat button
//

import SwiftUI
import Supabase

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showAIChatPopup = false
    @State private var showProfile = false
    @State private var userAvatarData: String? = nil
    
    enum Tab: Int, CaseIterable {
        case home = 0
        case myStory = 2
        case ai = 3
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .myStory: return "My Story"
            case .ai: return "AI"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .myStory: return "book.fill"
            case .ai: return "waveform.circle.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Home now contains both Camera and Feed
                HomeView(showProfile: $showProfile, avatarData: userAvatarData)
                    .tabItem {
                        Label(Tab.home.title, systemImage: Tab.home.icon)
                    }
                    .tag(Tab.home)
                
                MyStoryView(showProfile: $showProfile, avatarData: userAvatarData)
                    .tabItem {
                        Label(Tab.myStory.title, systemImage: Tab.myStory.icon)
                    }
                    .tag(Tab.myStory)
                
                AIVoiceChatView(showChatPopup: $showAIChatPopup, showProfile: $showProfile, avatarData: userAvatarData)
                    .tabItem {
                        Label("Assistant", systemImage: "waveform.circle.fill")
                    }
                    .tag(Tab.ai)
            }
            .tint(.black)
            .fullScreenCover(isPresented: $showProfile) {
                ProfileView(safeArea: .init()) {
                    showProfile = false
                }
            }
            .task {
                await fetchUserAvatar()
            }
            
            // Chat popup overlay - at ContentView level to cover TabBar
            if showAIChatPopup {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAIChatPopup = false
                        }
                    }
                
                VStack {
                    Spacer()
                    AIChatPopup(isPresented: $showAIChatPopup)
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Fetch User Avatar
    private func fetchUserAvatar() async {
        guard let userId = SupabaseManager.shared.currentUser?.id else { return }
        do {
            struct SimpleProfile: Decodable { let avatar_data: String? }
            let profile: SimpleProfile = try await SupabaseManager.shared.client
                .from("profiles")
                .select("avatar_data")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.userAvatarData = profile.avatar_data
            }
        } catch {
            print("Failed to fetch user avatar in ContentView: \(error)")
        }
    }
}

// MARK: - Models
enum AINotificationType {
    case like
    case birthday
    case memoryReview
    case suggestion
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .birthday: return "gift.fill"
        case .memoryReview: return "clock.arrow.circlepath"
        case .suggestion: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .like: return .red
        case .birthday: return .orange
        case .memoryReview: return .blue
        case .suggestion: return .purple
        }
    }
}

struct AINotification: Identifiable {
    let id = UUID()
    let type: AINotificationType
    let title: String
    let subtitle: String
    let timeAgo: String
}

// MARK: - AI Voice Chat View
struct AIVoiceChatView: View {
    @State private var messageText = ""
    @Binding var showChatPopup: Bool
    @Binding var showProfile: Bool
    var avatarData: String?
    
    // Hardcoded mock data to demonstrate the UI requested by the user
    private let notifications: [AINotification] = [
        AINotification(type: .birthday, title: "Sắp đến sinh nhật Mẹ", subtitle: "Còn 5 ngày nữa. Bạn có muốn tạo một video kỷ niệm không?", timeAgo: "Hôm nay"),
        AINotification(type: .like, title: "Trung Hiếu đã thả tim bài viết của bạn", subtitle: "Album: Chuyến đi Đà Lạt tháng 10", timeAgo: "2 giờ trước"),
        AINotification(type: .memoryReview, title: "1 năm nhìn lại", subtitle: "Bạn có 15 bức ảnh và 2 ghi âm giọng nói vào ngày này năm ngoái.", timeAgo: "Hôm qua"),
        AINotification(type: .suggestion, title: "Gợi ý kết nối", subtitle: "Đã 3 tháng rồi bạn chưa cập nhật câu chuyện nào với Gia đình.", timeAgo: "Tuần trước")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            
            ZStack {
                // White background
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, safeArea.top + 8)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // Important Notifications / Reminders at the top
                            notificationsSection
                            
                            Spacer(minLength: 140)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                    
                    // Input bar at bottom - above tab bar
                    inputBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, safeArea.bottom + 12)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Notifications & Reminders Section
    @ViewBuilder
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thông báo & Lời nhắc")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ForEach(notifications) { notification in
                    AINotificationCard(notification: notification)
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Assistant")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Gợi ý, thông báo và đồng hành cùng ký ức")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Profile button
            Button(action: { showProfile = true }) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if let avatarStr = avatarData,
                           let data = Data(base64Encoded: avatarStr),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.black.opacity(0.7))
                        }
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Input Bar with Liquid Glass
    private var inputBar: some View {
        HStack(spacing: 12) {
            // Text input field - tap to show popup - Liquid Glass style
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showChatPopup = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                    
                    Text("Ask AI about your memories...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
            
            // Voice button - Liquid Glass style
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showChatPopup = true
                }
            }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .glassEffect(.regular.interactive())
            }
        }
    }
}

// MARK: - Memory Suggestion Model
struct MemorySuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Memory Reminder Model
struct MemoryReminder: Identifiable {
    let id = UUID()
    let type: ReminderType
    let title: String
    let daysLeft: Int
    
    enum ReminderType {
        case birthday
        case anniversary
        case custom
        
        var icon: String {
            switch self {
            case .birthday: return "birthday.cake.fill"
            case .anniversary: return "heart.fill"
            case .custom: return "bell.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .birthday: return .black
            case .anniversary: return .black
            case .custom: return .black
            }
        }
    }
}

// MARK: - Notification Card
struct AINotificationCard: View {
    let notification: AINotification
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: notification.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(notification.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(notification.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(notification.timeAgo)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.06))
        )
    }
}

// MARK: - Suggestion Card
struct SuggestionCard: View {
    let suggestion: MemorySuggestion
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(suggestion.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: suggestion.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(suggestion.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.06))
        )
    }
}

// MARK: - Reminder Card
struct ReminderCard: View {
    let reminder: MemoryReminder
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(reminder.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: reminder.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(reminder.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(reminder.daysLeft) days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Days badge
            Text("\(reminder.daysLeft)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(reminder.type.color)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(reminder.type.color.opacity(0.15))
                )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.06))
        )
    }
}

// MARK: - Pending Request Card
struct PendingRequestCard: View {
    let request: PendingFriendRequest
    let onAction: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarDataStr = request.profile.avatar_data,
               let data = Data(base64Encoded: avatarDataStr),
               let uiImage = UIImage(data: data) {
                 Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                 Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    )
            }
            
            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(request.profile.username ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Đã gửi lời mời")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            if isProcessing {
                ProgressView()
                    .frame(width: 44, height: 44)
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        handleDecline()
                    }) {
                        Text("Xóa")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        handleAccept()
                    }) {
                        Text("Chấp nhận")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.05)) // Highlight with red tint
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func handleAccept() {
        isProcessing = true
        Task {
            do {
                try await FriendService.shared.acceptFriendRequest(request.friendshipId)
                await MainActor.run { onAction() }
            } catch {
                print("Accept error: \(error)")
            }
            await MainActor.run { isProcessing = false }
        }
    }
    
    private func handleDecline() {
        isProcessing = true
        Task {
            do {
                try await FriendService.shared.removeFriend(request.friendshipId)
                await MainActor.run { onAction() }
            } catch {
                print("Decline error: \(error)")
            }
            await MainActor.run { isProcessing = false }
        }
    }
}

// MARK: - AI Chat Popup
struct AIChatPopup: View {
    @Binding var isPresented: Bool
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(isUser: false, text: "Hello! I can help you search memories, create albums, or answer questions about your photos. Ask me anything! 😊")
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
                    
                    Text("Memory Assistant")
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
                    TextField("Type a message...", text: $messageText)
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = generateAIResponse(for: userText)
            messages.append(ChatMessage(isUser: false, text: response))
        }
    }
    
    private func generateAIResponse(for query: String) -> String {
        let responses = [
            "I found 12 photos related to this topic in your album. Would you like to see them? 📸",
            "This is a beautiful memory! You have 3 photos from that day with 2 voice recordings. ❤️",
            "I can create a new album with these photos. What would you like to name the album? 📚",
            "This memory was saved 6 months ago. Time flies! ⏰",
        ]
        return responses.randomElement() ?? "I understand! Let me search for you... 🔍"
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

#Preview {
    ContentView()
}
