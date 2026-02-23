import Foundation
import Testing
@testable import Cira

struct FamilyService_Tests {

    @Test("Test Family Model Decoding")
    func testFamilyDecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "The Smiths",
            "description": "Family group",
            "cover_data": "base64",
            "owner_id": "123e4567-e89b-12d3-a456-426614174001",
            "invite_code": "ABCDEF",
            "is_active": true,
            "created_at": "2025-01-01T12:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let family = try JSONDecoder().decode(Family.self, from: data)
        
        #expect(family.id.uuidString == "123E4567-E89B-12D3-A456-426614174000")
        #expect(family.name == "The Smiths")
        #expect(family.description == "Family group")
        #expect(family.owner_id.uuidString == "123E4567-E89B-12D3-A456-426614174001")
        #expect(family.invite_code == "ABCDEF")
        #expect(family.is_active == true)
    }

    @Test("Test FamilyMembership Model Decoding")
    func testFamilyMembershipDecoding() throws {
        let json = """
        {
            "family_id": "123e4567-e89b-12d3-a456-426614174000",
            "user_id": "123e4567-e89b-12d3-a456-426614174001",
            "role": "admin",
            "joined_at": "2025-01-01T12:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let membership = try JSONDecoder().decode(FamilyMembership.self, from: data)
        
        #expect(membership.family_id.uuidString == "123E4567-E89B-12D3-A456-426614174000")
        #expect(membership.role == "admin")
        #expect(membership.joined_at == "2025-01-01T12:00:00Z")
    }

    @Test("Test FamilyMemberProfile Init")
    func testFamilyMemberProfile() {
        let uuid = UUID()
        let profile = FamilyMemberProfile(user_id: uuid, role: "member", username: "john", avatar_data: nil)
        
        #expect(profile.id == uuid, "id should be mapped strictly to user_id")
        #expect(profile.role == "member")
        #expect(profile.username == "john")
    }

}
