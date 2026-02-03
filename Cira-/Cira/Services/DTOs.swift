import Foundation

// MARK: - Encodable Post Data
struct PostDTO: Codable {
    let id: String
    let owner_id: String
    // We send base64 for legacy support if needed, but prefer storage path
    // let image_data: String 
    let image_path: String?
    let live_photo_path: String?
    let message: String?
    let voice_url: String?
    let voice_duration: Double?
    let visibility: String?  // 'private', 'friends', 'family', 'public'
    let created_at: String
    let updated_at: String?
}

// MARK: - Chapter DTO for Supabase
struct ChapterDTO: Codable {
    let id: String
    let owner_id: String
    let name: String
    let description_text: String?
    let cover_image_path: String?
    let created_at: String
    let updated_at: String
}

// MARK: - Post Visibility Enum
enum PostVisibility: String, Codable, CaseIterable {
    case `private` = "private"   // Only me
    case friends = "friends"      // Friends only
    case family = "family"        // Family only
    case `public` = "public"      // Everyone
    
    var displayName: String {
        switch self {
        case .private: return "Only Me"
        case .friends: return "Friends"
        case .family: return "Family"
        case .public: return "Everyone"
        }
    }
    
    var icon: String {
        switch self {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .family: return "house.fill"
        case .public: return "globe"
        }
    }
}
