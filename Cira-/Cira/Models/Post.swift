//
//  Post.swift
//  Cira
//
//  Display model for Feed posts
//

import Foundation

/// Represents a post in the home feed
/// Can be a single photo or a chapter with multiple photos
struct Post: Identifiable {
    let id: UUID
    let type: PostType
    let photos: [PhotoItem]
    let author: Author
    let createdAt: Date
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    var message: String?
    
    enum PostType {
        case single      // Single photo with optional voice
        case chapter     // Multiple photos (swipeable)
    }
    
    struct Author {
        let id: UUID
        let username: String
        let avatarURL: URL?
    }
    
    struct PhotoItem: Identifiable {
        let id: UUID
        let imageURL: URL?
        let imageData: Data?
        let livePhotoMoviePath: String?
        let voiceNote: VoiceItem?
        
        var hasVoice: Bool {
            voiceNote != nil
        }
        
        var hasLivePhoto: Bool {
            livePhotoMoviePath != nil
        }
        
        var livePhotoMovieURL: URL? {
            guard let path = livePhotoMoviePath else { return nil }
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return documentsPath?.appendingPathComponent(path)
        }
        
        init(id: UUID, imageURL: URL?, imageData: Data?, livePhotoMoviePath: String? = nil, voiceNote: VoiceItem?) {
            self.id = id
            self.imageURL = imageURL
            self.imageData = imageData
            self.livePhotoMoviePath = livePhotoMoviePath
            self.voiceNote = voiceNote
        }
    }
    
    struct VoiceItem {
        let duration: TimeInterval
        let audioURL: URL?
        let waveformLevels: [Float]
        
        var formattedDuration: String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var isChapter: Bool {
        type == .chapter
    }
    
    var photoCount: Int {
        photos.count
    }
}

// MARK: - Mock Data
extension Post {
    static let mockPosts: [Post] = [
        Post(
            id: UUID(),
            type: .single,
            photos: [
                PhotoItem(
                    id: UUID(),
                    imageURL: nil,
                    imageData: nil,
                    livePhotoMoviePath: nil,
                    voiceNote: VoiceItem(
                        duration: 15,
                        audioURL: nil,
                        waveformLevels: [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.5, 0.3, 0.6, 0.8, 0.5]
                    )
                )
            ],
            author: Author(id: UUID(), username: "huynh", avatarURL: nil),
            createdAt: Date().addingTimeInterval(-3600),
            likeCount: 24,
            commentCount: 5,
            isLiked: false,
            message: nil
        ),
        Post(
            id: UUID(),
            type: .chapter,
            photos: [
                PhotoItem(id: UUID(), imageURL: nil, imageData: nil, livePhotoMoviePath: nil, voiceNote: nil),
                PhotoItem(
                    id: UUID(),
                    imageURL: nil,
                    imageData: nil,
                    livePhotoMoviePath: nil,
                    voiceNote: VoiceItem(duration: 8, audioURL: nil, waveformLevels: [0.4, 0.6, 0.8, 0.5, 0.7, 0.3])
                ),
                PhotoItem(id: UUID(), imageURL: nil, imageData: nil, livePhotoMoviePath: nil, voiceNote: nil),
            ],
            author: Author(id: UUID(), username: "friend1", avatarURL: nil),
            createdAt: Date().addingTimeInterval(-7200),
            likeCount: 156,
            commentCount: 23,
            isLiked: true,
            message: nil
        ),
        Post(
            id: UUID(),
            type: .single,
            photos: [
                PhotoItem(id: UUID(), imageURL: nil, imageData: nil, livePhotoMoviePath: nil, voiceNote: nil)
            ],
            author: Author(id: UUID(), username: "friend2", avatarURL: nil),
            createdAt: Date().addingTimeInterval(-86400),
            likeCount: 89,
            commentCount: 12,
            isLiked: false,
            message: nil
        ),
    ]
}
