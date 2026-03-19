//
//  AIVoiceChatView.swift
//  Cira
//
//  AI Assistant tab — notifications, reminders, and input bar
//  Extracted from ContentView.swift
//

import SwiftUI

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
                Text("Trợ lý AI")
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
    
    // MARK: - Input Bar (iOS 18 compatible with iOS 26 glass fallback)
    private var inputBar: some View {
        HStack(spacing: 12) {
            // Text input field
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showChatPopup = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                    
                    Text("Hỏi AI về ký ức của bạn...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                )
                .modifier(GlassEffectModifier())
            }
            .buttonStyle(.plain)
            
            // Voice button
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
                            .fill(Color.black.opacity(0.06))
                    )
                    .modifier(GlassEffectModifier())
            }
        }
    }
}

// MARK: - Glass Effect Modifier (iOS 26+ only, minimal fallback for iOS 18+)
struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive())
        } else {
            content
        }
    }
}
