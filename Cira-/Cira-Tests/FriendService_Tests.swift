import Foundation
import Testing
@testable import Cira

struct FriendService_Tests {

    @Test("Test Friendship Model Decoding")
    func testFriendshipDecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "requester_id": "123e4567-e89b-12d3-a456-426614174001",
            "addressee_id": "123e4567-e89b-12d3-a456-426614174002",
            "status": "accepted",
            "created_at": "2025-01-01T12:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let req = try JSONDecoder().decode(Friendship.self, from: data)
        
        #expect(req.id.uuidString == "123E4567-E89B-12D3-A456-426614174000")
        #expect(req.requester_id.uuidString == "123E4567-E89B-12D3-A456-426614174001")
        #expect(req.addressee_id.uuidString == "123E4567-E89B-12D3-A456-426614174002")
        #expect(req.status == "accepted")
    }

    @Test("Test FriendProfile Model Decoding")
    func testFriendProfileDecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "username": "jane_doe",
            "avatar_data": "base_64_avatar"
        }
        """
        
        let data = json.data(using: .utf8)!
        let profile = try JSONDecoder().decode(FriendProfile.self, from: data)
        
        #expect(profile.id.uuidString == "123E4567-E89B-12D3-A456-426614174000")
        #expect(profile.username == "jane_doe")
        #expect(profile.avatar_data == "base_64_avatar")
    }

}
