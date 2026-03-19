//
//  PostDestinationSlider.swift
//  Cira
//
//  Magnetic snap-to-center circle slider for choosing post destination.
//  Theme: white / gold / black — matches the app's visual identity.
//

import SwiftUI
import SwiftData

// MARK: - Post Destination
enum PostDestination: Identifiable, Equatable {
    case singlePost
    case newChapter
    case existingChapter(Chapter)
    
    var id: String {
        switch self {
        case .singlePost: return "single"
        case .newChapter: return "new_chapter"
        case .existingChapter(let c): return c.id.uuidString
        }
    }
    
    var icon: String {
        switch self {
        case .singlePost: return "paperplane.fill"
        case .newChapter: return "plus"
        case .existingChapter: return "book.closed.fill"
        }
    }
    
    var label: String {
        switch self {
        case .singlePost: return "Đăng bài"
        case .newChapter: return "Chương mới"
        case .existingChapter(let c): return c.name
        }
    }
    
    static func == (lhs: PostDestination, rhs: PostDestination) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Theme Colors
private let goldenOrange = Color(red: 1.0, green: 0.75, blue: 0.0)

// MARK: - Magnetic Snap Slider
struct PostDestinationSlider: View {
    let chapters: [Chapter]
    @Binding var selectedDestination: PostDestination
    
    @State private var baseOffset: CGFloat = 0
    @State private var dragDelta: CGFloat = 0
    @State private var activeIndex: Int = 0
    
    private var destinations: [PostDestination] {
        var dests: [PostDestination] = [.singlePost]
        for chapter in chapters.prefix(10) {
            dests.append(.existingChapter(chapter))
        }
        dests.append(.newChapter)
        return dests
    }
    
    private let circleSize: CGFloat = 44
    private let circleSpacing: CGFloat = 20
    private var step: CGFloat { circleSize + circleSpacing }
    
    private var totalOffset: CGFloat { baseOffset + dragDelta }
    
    var body: some View {
        let allDests = destinations
        
        VStack(spacing: 6) {
            // Circles
            GeometryReader { geo in
                let centerX = geo.size.width / 2
                
                HStack(spacing: circleSpacing) {
                    ForEach(Array(allDests.enumerated()), id: \.element.id) { index, dest in
                        destinationCircle(dest, isActive: index == activeIndex)
                    }
                }
                .offset(x: centerX - circleSize / 2 + totalOffset)
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            dragDelta = value.translation.width
                            
                            let centerInItemSpace = -(baseOffset + dragDelta) / step
                            let nearestIdx = max(0, min(allDests.count - 1, Int(round(centerInItemSpace))))
                            
                            if nearestIdx != activeIndex {
                                activeIndex = nearestIdx
                                selectedDestination = allDests[nearestIdx]
                                HapticHelper.light()
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            let finalOffset = baseOffset + dragDelta + velocity * 0.3
                            
                            let centerInItemSpace = -finalOffset / step
                            let snappedIdx = max(0, min(allDests.count - 1, Int(round(centerInItemSpace))))
                            
                            activeIndex = snappedIdx
                            selectedDestination = allDests[snappedIdx]
                            
                            baseOffset += dragDelta
                            dragDelta = 0
                            
                            withAnimation(.interpolatingSpring(stiffness: 350, damping: 28)) {
                                baseOffset = -CGFloat(snappedIdx) * step
                            }
                            
                            HapticHelper.light()
                        }
                )
            }
            .frame(height: circleSize + 16)
            // NO .clipped() — circles can breathe, scale ring won't be cut
            
            // Label BELOW circles
            Text(allDests[safe: activeIndex]?.label ?? "")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.black.opacity(0.55))
                .lineLimit(1)
                .frame(height: 14)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: activeIndex)
        }
        .onAppear {
            if let idx = destinations.firstIndex(of: selectedDestination) {
                activeIndex = idx
                baseOffset = -CGFloat(idx) * step
            }
        }
    }
    
    @ViewBuilder
    private func destinationCircle(_ destination: PostDestination, isActive: Bool) -> some View {
        let size = circleSize
        let scale: CGFloat = isActive ? 1.15 : 0.8
        
        ZStack {
            Circle()
                .fill(isActive ? goldenOrange : Color.black.opacity(0.06))
                .frame(width: size, height: size)
            
            if isActive {
                Circle()
                    .stroke(goldenOrange.opacity(0.5), lineWidth: 2.5)
                    .frame(width: size + 6, height: size + 6)
            }
            
            if case .existingChapter(let chapter) = destination,
               let coverData = chapter.coverImageData ?? chapter.photos.first?.imageData,
               let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 4, height: size - 4)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isActive ? goldenOrange : .clear, lineWidth: 2))
            } else {
                Image(systemName: destination.icon)
                    .font(.system(size: isActive ? 16 : 13, weight: .semibold))
                    .foregroundStyle(isActive ? .white : .black.opacity(0.5))
            }
        }
        .scaleEffect(scale)
        .opacity(isActive ? 1.0 : 0.5)
        .animation(.interpolatingSpring(stiffness: 300, damping: 22), value: isActive)
    }
}

// MARK: - Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
