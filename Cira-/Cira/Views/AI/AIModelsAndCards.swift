//
//  AIModelsAndCards.swift
//  Cira
//
//  AI-related models and card components
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - AI Notification Type
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

// MARK: - AI Notification
struct AINotification: Identifiable {
    let id = UUID()
    let type: AINotificationType
    let title: String
    let subtitle: String
    let timeAgo: String
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
