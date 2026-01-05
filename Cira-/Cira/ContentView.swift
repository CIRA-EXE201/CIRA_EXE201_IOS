//
//  ContentView.swift
//  Cira-
//
//  Main TabView with Liquid Glass effect
//  Tabs: Home, Camera, My Story + AI Voice Chat button
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showAIChatPopup = false
    
    enum Tab: Int, CaseIterable {
        case home = 0
        case camera = 1
        case myStory = 2
        case ai = 3
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .camera: return "Camera"
            case .myStory: return "My Story"
            case .ai: return "AI"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .camera: return "camera.fill"
            case .myStory: return "book.fill"
            case .ai: return "waveform.circle.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label(Tab.home.title, systemImage: Tab.home.icon)
                    }
                    .tag(Tab.home)
                
                CameraView()
                    .tabItem {
                        Label(Tab.camera.title, systemImage: Tab.camera.icon)
                    }
                    .tag(Tab.camera)
                
                MyStoryView()
                    .tabItem {
                        Label(Tab.myStory.title, systemImage: Tab.myStory.icon)
                    }
                    .tag(Tab.myStory)
                
                AIVoiceChatView(showChatPopup: $showAIChatPopup)
                    .tabItem {
                        Label("Assistant", systemImage: "waveform.circle.fill")
                    }
                    .tag(Tab.ai)
            }
            .tint(.black)
            
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
}

// MARK: - AI Voice Chat View
struct AIVoiceChatView: View {
    @State private var messageText = ""
    @Binding var showChatPopup: Bool
    
    // Sample memory suggestions from AI
    private let memorySuggestions: [MemorySuggestion] = [
        MemorySuggestion(icon: "calendar", title: "One year ago today", description: "You took 5 photos in Da Lat", color: .black),
        MemorySuggestion(icon: "heart.fill", title: "Best memories", description: "November family photos were most loved", color: .black),
        MemorySuggestion(icon: "sparkles", title: "Create new album", description: "AI suggests: 2024 Pets compilation", color: .black),
        MemorySuggestion(icon: "clock.fill", title: "Don't forget to record", description: "You haven't recorded your voice this week", color: .black),
    ]
    
    // Sample reminders
    private let reminders: [MemoryReminder] = [
        MemoryReminder(type: .birthday, title: "Mom's Birthday", daysLeft: 5),
        MemoryReminder(type: .anniversary, title: "3 Year Anniversary", daysLeft: 12),
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
                            // AI Greeting
                            aiGreetingCard
                            
                            // Memory Suggestions
                            suggestionsSection
                            
                            // Upcoming Reminders
                            remindersSection
                            
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
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Assistant")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Memory suggestions and reminders")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Settings button
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - AI Greeting Card
    private var aiGreetingCard: some View {
        VStack(spacing: 16) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(.black)
            }
            
            Text("Hello! 👋")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("I can help you search memories, create albums, or remind you of important dates.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.06))
        )
    }
    
    // MARK: - Suggestions Section
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggestions for you")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(memorySuggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
    
    // MARK: - Reminders Section
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(reminders) { reminder in
                    ReminderCard(reminder: reminder)
                }
            }
        }
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
