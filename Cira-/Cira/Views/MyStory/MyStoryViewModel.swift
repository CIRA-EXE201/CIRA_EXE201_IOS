//
//  MyStoryViewModel.swift
//  Cira
//
//  ViewModel for My Story tab
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class MyStoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var chapters: [Chapter] = []
    @Published private(set) var photos: [Photo] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var photoCount: Int {
        12 // Mock count
    }
    
    var chapterCount: Int {
        3 // Mock count
    }
    
    var voiceCount: Int {
        4 // Mock count
    }
    
    // MARK: - Init
    init() {
        // Load mock data
    }
    
    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }
    
    func createChapter(name: String, description: String?) async throws {
        let chapter = Chapter(name: name, description: description)
        chapters.append(chapter)
    }
    
    func deleteChapter(_ chapter: Chapter) async throws {
        chapters.removeAll { $0.id == chapter.id }
    }
}
