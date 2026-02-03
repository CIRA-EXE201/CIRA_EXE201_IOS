import SwiftUI

struct PostControlsView: View {
    let post: Post
    
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
            
            // Interaction Bar (Input + Icons)
            HStack(spacing: 12) {
                // Message Input
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
                
                // Reactions
                HStack(spacing: 16) {
                    ReactionButton(emoji: "💛")
                    ReactionButton(emoji: "🔥")
                    ReactionButton(emoji: "😍")
                    
                    Button(action: {}) {
                        Image(systemName: "face.smiling.inverse")
                            .font(.system(size: 24))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
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
