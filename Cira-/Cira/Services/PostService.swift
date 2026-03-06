//
//  PostService.swift
//  Cira
//
//  Service for managing posts with SwiftData
//

import Foundation
import SwiftData
import UIKit
import Supabase
import Auth

@MainActor
final class PostService {
    static let shared = PostService()
    
    private init() {}
    
    // MARK: - Save New Post (Single or to Chapter)
    func savePost(
        imageData: Data,
        livePhotoMovieURL: URL?,
        voiceNoteURL: URL?,
        voiceDuration: TimeInterval?,
        message: String?,
        chapter: Chapter? = nil,
        modelContext: ModelContext
    ) async throws -> Photo {
        // Create Photo with pending sync status
        let photo = Photo(imageData: imageData)
        photo.syncStatus = .pending
        
        // Handle Live Photo movie - copy to documents
        if let movieURL = livePhotoMovieURL {
            let fileName = "livephoto_\(photo.id.uuidString).mov"
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: movieURL, to: destinationURL)
                photo.livePhotoMoviePath = fileName
            } catch {
                print("Failed to copy Live Photo movie: \(error)")
            }
        }
        
        // Handle voice note
        if let voiceURL = voiceNoteURL, let duration = voiceDuration {
            let fileName = "voice_\(UUID().uuidString).m4a"
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: voiceURL, to: destinationURL)
                
                let voiceNote = VoiceNote(audioFileName: fileName, duration: duration)
                photo.voiceNote = voiceNote
                modelContext.insert(voiceNote)
            } catch {
                print("Failed to copy voice note: \(error)")
            }
        }
        
        // Save message if provided
        if let msg = message, !msg.isEmpty {
            photo.message = msg
        }
        
        // Add to chapter if provided
        if let chapter = chapter {
            photo.chapter = chapter
            chapter.photos.append(photo)
            chapter.updatedAt = Date()
            
            // Set cover image if first photo
            if chapter.coverImageData == nil {
                chapter.coverImageData = imageData
            }
        }
        
        // Insert photo
        modelContext.insert(photo)
        
        // Save locally first (offline-first)
        try modelContext.save()
        
        if let chapter = chapter {
            print("✅ Post saved locally to chapter '\(chapter.name)' with ID: \(photo.id)")
        } else {
            print("✅ Single post saved locally with ID: \(photo.id)")
        }
        
        // Trigger cloud sync (non-blocking)
        Task {
            await SyncManager.shared.syncPendingPosts()
        }
        
        return photo
    }

    
    // MARK: - Fetch All Posts
    // MARK: - Fetch All Posts (For Home Feed)
    func fetchAllPosts(modelContext: ModelContext) -> [Photo] {
        let descriptor = FetchDescriptor<Photo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch all posts: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch My Posts (For Profile/Story)
    func fetchMyPosts(modelContext: ModelContext, currentUserId: String) -> [Photo] {
        let descriptor = FetchDescriptor<Photo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        // Note: SwiftData predicate with optional String equality can be tricky, 
        // so we filter in memory for safety if the dataset isn't huge, 
        // or we use a safe predicate. For now, filter in memory is safer for optional Strings.
        
        do {
            let all = try modelContext.fetch(descriptor)
            return all.filter { $0.ownerId == nil || $0.ownerId == currentUserId || $0.ownerId == "" }
        } catch {
            print("Failed to fetch my posts: \(error)")
            return []
        }
    }
    
    // MARK: - Convert Photo to Post for display
    func convertToPost(photo: Photo) -> Post {
        var voiceItem: Post.VoiceItem? = nil
        
        if let voiceNote = photo.voiceNote {
            voiceItem = Post.VoiceItem(
                duration: voiceNote.duration,
                audioURL: voiceNote.audioFileURL,
                waveformLevels: voiceNote.waveformData ?? [0.3, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7]
            )
        }
        
        let photoItem = Post.PhotoItem(
            id: photo.id,
            imageURL: nil,
            imageData: photo.imageData,
            remoteImagePath: photo.remoteImagePath,
            livePhotoMoviePath: photo.livePhotoMoviePath,
            voiceNote: voiceItem
        )
        
        let currentUserIdStr = SupabaseManager.shared.currentUser?.id.uuidString ?? UUID().uuidString
        let currentUserId = UUID(uuidString: currentUserIdStr) ?? UUID()
        
        let authorIdStr = photo.ownerId ?? currentUserIdStr
        let authorId = UUID(uuidString: authorIdStr) ?? currentUserId
        
        // If it's my post, authorUsername logic
        var username = "Me"
        if let photoUsername = photo.authorUsername, !photoUsername.isEmpty {
            username = photoUsername
        } else if authorIdStr != currentUserIdStr {
            username = "Friend"
        }
        
        let avatarURL = photo.authorAvatarData != nil ? URL(string: "data:image/jpeg;base64,\(photo.authorAvatarData!)") : nil
        
        return Post(
            id: photo.id,
            type: .single,
            photos: [photoItem],
            author: Post.Author(id: authorId, username: username, avatarURL: avatarURL),
            createdAt: photo.createdAt,
            likeCount: 0,
            commentCount: 0,
            isLiked: false,
            message: photo.message
        )
    }
    
    // MARK: - Delete Post
    func deletePost(photo: Photo, modelContext: ModelContext) throws {
        // Delete voice note file if exists
        if let voiceNote = photo.voiceNote, let url = voiceNote.audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Delete live photo movie if exists
        if let moviePath = photo.livePhotoMoviePath {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let movieURL = documentsPath.appendingPathComponent(moviePath)
            try? FileManager.default.removeItem(at: movieURL)
        }
        
        modelContext.delete(photo)
        try modelContext.save()
    }
}
