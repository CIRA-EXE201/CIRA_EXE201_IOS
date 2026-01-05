//
//  MyStoryView.swift
//  Cira
//
//  My Story tab - User's personal chapters/albums
//  Redesigned to match app's Liquid Glass aesthetic
//

import SwiftUI
import SwiftData

struct MyStoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chapter.updatedAt, order: .reverse) private var chapters: [Chapter]
    @State private var showCreateChapter = false
    @State private var selectedChapter: Chapter?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let safeArea = geometry.safeAreaInsets
                
                ZStack {
                    // Clean white background like other views
                    Color.white
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header matching ProfileView style
                        headerView
                            .padding(.top, safeArea.top + 8)
                        
                        // Search bar
                        searchBar
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        // Chapters grid
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                // Add new chapter button
                                addChapterButton
                                
                                ForEach(chapters) { chapter in
                                    ChapterCard(chapter: chapter) {
                                        deleteChapter(chapter)
                                    }
                                    .onTapGesture {
                                        selectedChapter = chapter
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, safeArea.bottom + 100)
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateChapter) {
                CreateChapterSheet { _ in
                    // Chapter created, list will auto-update via @Query
                }
            }
            .navigationDestination(item: $selectedChapter) { chapter in
                ChapterDetailView(chapter: chapter)
            }
        }
    }
    
    // MARK: - Delete Chapter
    private func deleteChapter(_ chapter: Chapter) {
        modelContext.delete(chapter)
        try? modelContext.save()
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 16) {
            Text("My Story")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            // Add button
            Button(action: { showCreateChapter = true }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text("Search chapters...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.08))
            )
            
            // Voice search button
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Add Chapter Button
    private var addChapterButton: some View {
        Button(action: { showCreateChapter = true }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundStyle(.gray.opacity(0.4))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.gray)
                }
                
                Text("Create new chapter")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 6]))
                    .foregroundStyle(.gray.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chapter Card (Grid style matching app aesthetic)
struct ChapterCard: View {
    let chapter: Chapter
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail area - larger, takes most space
            ZStack(alignment: .topTrailing) {
                // Cover image or placeholder
                if let coverData = chapter.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if let firstPhoto = chapter.photos.first,
                          let imageData = firstPhoto.imageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.3),
                                    Color.gray.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.gray.opacity(0.8))
                        }
                }
                
                // Voice badge if has voice notes
                if chapter.hasVoiceNotes {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.black))
                        .padding(8)
                }
            }
            
            // Info area
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(chapter.photoCount) photos")
                    
                    if chapter.voiceCount > 0 {
                        Text("• \(chapter.voiceCount) recordings")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.06))
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .contextMenu {
            Button(action: {}) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: {}) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    MyStoryView()
        .modelContainer(for: [Chapter.self, Photo.self, VoiceNote.self], inMemory: true)
}
