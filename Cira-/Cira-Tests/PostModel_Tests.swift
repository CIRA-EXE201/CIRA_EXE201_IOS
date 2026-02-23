import Foundation
import Testing
@testable import Cira

struct PostModel_Tests {

    @Test("Test Post Type Checks")
    func testPostType() {
        let singlePost = Post(
            id: UUID(),
            type: .single,
            photos: [Post.PhotoItem(id: UUID(), imageURL: nil, imageData: nil, voiceNote: nil)],
            author: Post.Author(id: UUID(), username: "test", avatarURL: nil),
            createdAt: Date(),
            likeCount: 0,
            commentCount: 0,
            isLiked: false
        )
        
        #expect(singlePost.isChapter == false)
        #expect(singlePost.photoCount == 1)
        
        let chapterPost = Post(
            id: UUID(),
            type: .chapter,
            photos: [
                Post.PhotoItem(id: UUID(), imageURL: nil, imageData: nil, voiceNote: nil),
                Post.PhotoItem(id: UUID(), imageURL: nil, imageData: nil, voiceNote: nil)
            ],
            author: Post.Author(id: UUID(), username: "test2", avatarURL: nil),
            createdAt: Date(),
            likeCount: 5,
            commentCount: 2,
            isLiked: true
        )
        
        #expect(chapterPost.isChapter == true)
        #expect(chapterPost.photoCount == 2)
    }

    @Test("Test PhotoItem Flags")
    func testPhotoItemFlags() {
        let emptyPhoto = Post.PhotoItem(id: UUID(), imageURL: nil, imageData: nil, voiceNote: nil)
        #expect(emptyPhoto.hasVoice == false)
        #expect(emptyPhoto.hasLivePhoto == false)
        #expect(emptyPhoto.livePhotoMovieURL == nil)
        
        let voiceItem = Post.VoiceItem(duration: 10, audioURL: nil, waveformLevels: [])
        let voicePhoto = Post.PhotoItem(id: UUID(), imageURL: nil, imageData: nil, livePhotoMoviePath: nil, voiceNote: voiceItem)
        #expect(voicePhoto.hasVoice == true)
        
        let livePhotoItem = Post.PhotoItem(id: UUID(), imageURL: nil, imageData: nil, livePhotoMoviePath: "test.mov", voiceNote: nil)
        #expect(livePhotoItem.hasLivePhoto == true)
        #expect(livePhotoItem.livePhotoMovieURL?.lastPathComponent == "test.mov")
    }

    @Test("Test VoiceItem Duration Formatting")
    func testVoiceItemDuration() {
        let voice1 = Post.VoiceItem(duration: 65, audioURL: nil, waveformLevels: [])
        #expect(voice1.formattedDuration == "1:05")
        
        let voice2 = Post.VoiceItem(duration: 9, audioURL: nil, waveformLevels: [])
        #expect(voice2.formattedDuration == "0:09")
    }

}
