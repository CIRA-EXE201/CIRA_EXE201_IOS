import Foundation
import Testing
@testable import Cira

struct DTO_Tests {

    @Test("Test PostDTO Model Decoding")
    func testPostDTODecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "owner_id": "123e4567-e89b-12d3-a456-426614174001",
            "image_path": "path/to/image.jpg",
            "visibility": "friends",
            "created_at": "2025-01-01T12:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let dto = try JSONDecoder().decode(PostDTO.self, from: data)
        
        #expect(dto.id == "123e4567-e89b-12d3-a456-426614174000")
        #expect(dto.owner_id == "123e4567-e89b-12d3-a456-426614174001")
        #expect(dto.image_path == "path/to/image.jpg")
        #expect(dto.live_photo_path == nil)
        #expect(dto.visibility == "friends")
    }

    @Test("Test ChapterDTO Model Decoding")
    func testChapterDTODecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "owner_id": "123e4567-e89b-12d3-a456-426614174001",
            "name": "Japan Trip",
            "description_text": "A wonderful week in Japan",
            "cover_image_path": "path/cover.jpg",
            "created_at": "2025-01-01T12:00:00Z",
            "updated_at": "2025-01-02T12:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let chapter = try JSONDecoder().decode(ChapterDTO.self, from: data)
        
        #expect(chapter.id == "123e4567-e89b-12d3-a456-426614174000")
        #expect(chapter.name == "Japan Trip")
        #expect(chapter.description_text == "A wonderful week in Japan")
        #expect(chapter.cover_image_path == "path/cover.jpg")
    }

    @Test("Test PostVisibility Enum")
    func testPostVisibilityValues() {
        #expect(PostVisibility.private.displayName == "Only Me")
        #expect(PostVisibility.friends.displayName == "Friends")
        #expect(PostVisibility.family.displayName == "Family")
        #expect(PostVisibility.public.displayName == "Everyone")
        
        #expect(PostVisibility.private.icon == "lock.fill")
        #expect(PostVisibility.friends.icon == "person.2.fill")
    }
}
