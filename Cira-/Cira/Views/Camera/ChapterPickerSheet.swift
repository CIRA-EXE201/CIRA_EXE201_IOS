//
//  ChapterPickerSheet.swift
//  Cira
//
//  Sheet to pick existing chapter or create new one
//

import SwiftUI
import SwiftData

struct ChapterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Chapter.updatedAt, order: .reverse) private var chapters: [Chapter]
    
    @State private var showCreateNew = false
    @State private var newChapterName = ""
    @State private var newChapterDescription = ""
    
    let onSelect: (Chapter?) -> Void // nil means create single post without chapter
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Options list
                List {
                    // Single post option
                    Section {
                        Button(action: {
                            onSelect(nil)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "photo")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Single post")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.primary)
                                    
                                    Text("Post this photo as a single post")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Create new chapter
                    Section {
                        Button(action: {
                            showCreateNew = true
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.orange)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create new chapter")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.primary)
                                    
                                    Text("Start a new story")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Existing chapters
                    if !chapters.isEmpty {
                        Section(header: Text("Add to existing chapter")) {
                            ForEach(chapters) { chapter in
                                Button(action: {
                                    onSelect(chapter)
                                    dismiss()
                                }) {
                                    ChapterRow(chapter: chapter)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Save to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateNew) {
                CreateChapterSheet { chapter in
                    onSelect(chapter)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Chapter Row
struct ChapterRow: View {
    let chapter: Chapter
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover image or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                if let coverData = chapter.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let firstPhoto = chapter.photos.first,
                          let imageData = firstPhoto.imageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "book.closed")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Label("\(chapter.photoCount)", systemImage: "photo")
                    
                    if chapter.hasVoiceNotes {
                        Label("\(chapter.voiceCount)", systemImage: "waveform")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Create Chapter Sheet
struct CreateChapterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var description = ""
    @FocusState private var isNameFocused: Bool
    
    let onCreate: (Chapter) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Information")) {
                    TextField("Chapter name", text: $name)
                        .focused($isNameFocused)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "book.closed")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name.isEmpty ? "Chapter name" : name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(name.isEmpty ? .secondary : .primary)
                                
                                if !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChapter()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }
    
    private func createChapter() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let chapter = Chapter(
            name: trimmedName,
            description: description.isEmpty ? nil : description
        )
        
        modelContext.insert(chapter)
        
        do {
            try modelContext.save()
            onCreate(chapter)
            dismiss()
        } catch {
            print("Failed to create chapter: \(error)")
        }
    }
}

#Preview {
    ChapterPickerSheet { chapter in
        print("Selected: \(chapter?.name ?? "Single post")")
    }
}
