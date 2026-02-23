import Foundation
import Testing
@testable import Cira

struct Cira_Tests {

    @Test("Test FeedPost Decoding from nested profiles JSON")
    func testDecodeFeedPostNestedProfiles() throws {
        let jsonString = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "owner_id": "123e4567-e89b-12d3-a456-426614174001",
            "visibility": "public",
            "created_at": "2025-01-01T12:00:00Z",
            "profiles": {
                "username": "nested_user",
                "avatar_data": "base64_avatar_data"
            }
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let post = try decoder.decode(FeedPost.self, from: data)
        
        #expect(post.id.uuidString == "123E4567-E89B-12D3-A456-426614174000")
        #expect(post.visibility == "public")
        #expect(post.author_username == "nested_user", "Should correctly extract username from nested profiles object")
        #expect(post.author_avatar_data == "base64_avatar_data", "Should correctly extract avatar from nested profiles object")
    }
    
    @Test("Test FeedPost Decoding from flat RPC JSON")
    func testDecodeFeedPostFlatRPC() throws {
        let jsonString = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "owner_id": "123e4567-e89b-12d3-a456-426614174001",
            "visibility": "friends",
            "created_at": "2025-01-01T12:00:00Z",
            "author_username": "flat_user",
            "author_avatar_data": "flat_avatar_data"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let post = try decoder.decode(FeedPost.self, from: data)
        
        #expect(post.visibility == "friends")
        #expect(post.author_username == "flat_user", "Should correctly extract username from flat JSON")
        #expect(post.author_avatar_data == "flat_avatar_data", "Should correctly extract avatar from flat JSON")
    }

}
