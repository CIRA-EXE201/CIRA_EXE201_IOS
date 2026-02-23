//
//  ProfileView.swift
//  Cira
//
//  User Profile with calendar showing captured photos
//

import SwiftUI
import Supabase
import SwiftData

// MARK: - Profile Data Model
struct ProfileData: Decodable {
    let username: String?
    let avatar_data: String?
    let bio: String?
    let created_at: String?
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ProfileView: View {
    // MARK: - SwiftData
    @Environment(\.modelContext) private var modelContext
    
    // Remove passed safeArea
    let safeArea: EdgeInsets
    var onClose: (() -> Void)? = nil
    @State private var showSubscription = false
    
    // Profile data from Supabase
    @State private var profileData: ProfileData?
    @State private var isLoading = true
    
    // MARK: - Calendar Data
    // Key: "MM-dd" -> Array of thumbnail data (max 2 items)
    @State private var calendarPhotos: [String: [Data]] = [:]
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    // Streak
    @State private var currentStreak: Int = 0
    
    // Scroll Tracking
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { proxy in
            
            ZStack {
                // White background
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with back button and Gold button
                    headerView
                        .padding(.top, safeArea.top + 8)
                        .zIndex(1) // Ensure header is above scroll content
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // User Info - Avatar left, Name right
                            userInfoSection
                                .opacity(scrollOffset < -50 ? 0 : 1) // Fade out effect
                        
                        // Streak highlight card
                        streakCard
                        
                        // Calendar - all 12 months
                        calendarSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: ScrollViewOffsetPreferenceKey.self,
                                    value: proxy.frame(in: .named("scroll")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollOffset = value
                    }
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .presentationDetents([.height(600)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
        }
        .onAppear {
            fetchProfile()
        }
        .task(id: selectedYear) {
            await fetchCalendarPhotos(for: selectedYear)
        }
    }
    }
    
    // MARK: - Fetch Calendar Photos
    private func fetchCalendarPhotos(for year: Int) async {
        let calendar = Calendar.current
        
        // Date range for the entire year
        guard let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)),
              let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfYear) else {
            return
        }
        
        // Fetch descriptor
        let predicate = #Predicate<Photo> { photo in
            photo.createdAt >= startDate && photo.createdAt <= endDate
        }
        
        let descriptor = FetchDescriptor<Photo>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let photos = try modelContext.fetch(descriptor)
            
            // Group by "MM-dd" and keep top 2
            var newCalendarPhotos: [String: [Data]] = [:]
            
            for photo in photos {
                guard let thumbnailData = photo.thumbnailData ?? photo.imageData else { continue }
                
                let month = calendar.component(.month, from: photo.createdAt)
                let day = calendar.component(.day, from: photo.createdAt)
                let key = String(format: "%02d-%02d", month, day)
                
                if newCalendarPhotos[key] == nil {
                    newCalendarPhotos[key] = []
                }
                
                if newCalendarPhotos[key]!.count < 2 {
                    newCalendarPhotos[key]!.append(thumbnailData)
                }
            }
            
            await MainActor.run {
                self.calendarPhotos = newCalendarPhotos
            }
            
            // Calculate stats after fetching photos
            await calculateStats()
        } catch {
            print("❌ Failed to fetch calendar photos: \(error)")
        }
    }
    
    // MARK: - Calculate Stats (Streak)
    private func calculateStats() async {
        let descriptor = FetchDescriptor<Photo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        
        do {
            let allPhotos = try modelContext.fetch(descriptor)
            
            // Calculate Streak
            var streak = 0
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            
            // Get unique days with photos
            let uniqueDays = Set(allPhotos.map { calendar.startOfDay(for: $0.createdAt) })
            
            // Check if streak is active (has photo Today OR Yesterday)
            if uniqueDays.contains(today) || uniqueDays.contains(yesterday) {
                // Streak is alive, calculate length
                var checkDate = today 
                
                // If no photo today but has yesterday, start checking from yesterday
                if !uniqueDays.contains(today) && uniqueDays.contains(yesterday) {
                   checkDate = yesterday
                }
                
                while uniqueDays.contains(checkDate) {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                }
            } else {
                streak = 0
            }
            
            await MainActor.run {
                self.currentStreak = streak
            }
        } catch {
            print("❌ Failed to calculate stats: \(error)")
        }
    }
    
    // MARK: - Fetch Profile
    private func fetchProfile() {
        Task {
            guard let userId = SupabaseManager.shared.currentUser?.id else {
                isLoading = false
                return
            }
            
            do {
                let profile: ProfileData = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("username, avatar_data, bio, created_at")
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                profileData = profile
            } catch {
                print("Failed to fetch profile: \(error)")
            }
            isLoading = false
        }
    }
    
    // MARK: - Format Joined Date
    private func formattedJoinDate() -> String {
        guard let dateString = profileData?.created_at else {
            return "Joined recently"
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMMM yyyy"
            return "Joined " + displayFormatter.string(from: date)
        }
        return "Joined recently"
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            // Subscription button - Gold (now on left)
            Button(action: {
                showSubscription = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("Gold")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            
            Spacer()
            
            // Collapsed State: Username
            if scrollOffset < -50 {
                Text(profileData?.username ?? "User")
                    .font(.headline)
                    .transition(.opacity)
            } else {
                Text("Profile")
                    .font(.headline)
                    .transition(.opacity)
            }
            
            Spacer()
            
            // Right Side Container
            HStack(spacing: 12) {
                // Collapsed State: Avatar
                if scrollOffset < -50 {
                    if let avatarBase64 = profileData?.avatar_data,
                       let imageData = Data(base64Encoded: avatarBase64),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // Fallback Avatar Icon
                         Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.gray)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Back button (now on right)
                Button(action: { onClose?() }) {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .animation(.easeInOut, value: scrollOffset)
    }
    
    // MARK: - User Info (Avatar left, Name right)
    private var userInfoSection: some View {
        HStack(alignment: .center, spacing: 16) {
            // Avatar with gradient ring
            Circle()
                .stroke(
                    Color.gray.opacity(0.3),
                    lineWidth: 3
                )
                .frame(width: 80, height: 80)
                .overlay {
                    if let avatarBase64 = profileData?.avatar_data,
                       let imageData = Data(base64Encoded: avatarBase64),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 74, height: 74)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.gray)
                            }
                    }
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(profileData?.username ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                // Divider line
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                    .frame(maxWidth: 120)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(profileData?.username?.lowercased() ?? "username")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Text(formattedJoinDate())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Streak Card
    private var streakCard: some View {
        HStack {
            Spacer()
            
            // Streak content only
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.title2)
                    Text("\(currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                }
                Text("day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Memories section removed per user request
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.06))
        )
    }
    
    // MARK: - Calendar Section (All 12 months)
    private var calendarSection: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        
        return VStack(alignment: .leading, spacing: 0) {
            // Year navigation - separate card
            HStack {
                Button(action: { 
                    withAnimation { selectedYear -= 1 }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("\(String(selectedYear))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { 
                    withAnimation { selectedYear += 1 }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.medium))
                        .foregroundStyle(selectedYear < currentYear ? Color.primary : Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(selectedYear >= currentYear)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.12))
            )
            
            Spacer().frame(height: 16)
            
            // All 12 months - each in separate card
            VStack(spacing: 16) {
                ForEach(getAllMonthsInYear(), id: \.self) { monthDate in
                    monthCalendarView(for: monthDate)
                }
            }
        }
    }
    
    private func monthCalendarView(for monthDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Month header section - darker background
            HStack {
                Text(monthName(for: monthDate))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.12))
            
            // Calendar grid - 7 columns
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth(for: monthDate).enumerated()), id: \.offset) { index, day in
                    if day == 0 {
                        // Empty cell
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        // Day cell with photo and day number
                        dayCellView(day: day, monthDate: monthDate)
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func dayCellView(day: Int, monthDate: Date) -> some View {
        let photoKey = getPhotoKey(day: day, monthDate: monthDate)
        let photos = calendarPhotos[photoKey] ?? []
        let hasPhoto = !photos.isEmpty
        let isToday = isCurrentDay(day, in: monthDate)
        
        return VStack(spacing: 2) {
            // Thumbnail container
            ZStack {
                if hasPhoto {
                    // Render Stacked Photos
                    ZStack {
                        // Bottom Photo (if exists, indexed 1 in our reverse sorted array)
                        if photos.count > 1, let uiImage = UIImage(data: photos[1]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .rotationEffect(.degrees(6)) // Rotate for stack effect
                                .offset(x: 2, y: 0) // Slight offset
                                .opacity(0.8)
                        }
                        
                        // Top Photo (indexed 0)
                        if let uiImage = UIImage(data: photos[0]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    
                } else {
                    // Empty Placeholder
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.08))
                        .aspectRatio(1, contentMode: .fit)
                }
                
                // Today indicator (Border)
                if isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 2)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            
            // Day number below the image
            Text("\(day)")
                .font(.system(size: 10))
                .foregroundStyle(isToday ? .black : .secondary)
                .fontWeight(isToday ? .bold : .regular)
        }
    }
    
    // MARK: - Helpers
    private func getAllMonthsInYear() -> [Date] {
        let calendar = Calendar.current
        var months: [Date] = []
        
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())
        
        // Determine start month
        // If viewing current year: start from current month
        // If viewing past year: start from 12
        let startMonth = (selectedYear == currentYear) ? currentMonth : 12
        
        // Get months in reverse order (e.g., Dec -> Jan, or Current -> Jan)
        for month in stride(from: startMonth, through: 1, by: -1) {
            var components = DateComponents()
            components.year = selectedYear
            components.month = month
            components.day = 1
            
            if let date = calendar.date(from: components) {
                months.append(date)
            }
        }
        
        return months
    }
    
    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN") // Keep localized as requested
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }
    
    private func getPhotoKey(day: Int, monthDate: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: monthDate)
        return String(format: "%02d-%02d", month, day)
    }
    
    private func daysInMonth(for monthDate: Date) -> [Int] {
        let calendar = Calendar.current
        
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let firstDay = calendar.date(from: components) else { return [] }
        
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        let numDays = range.count
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        var days: [Int] = []
        for _ in 1..<firstWeekday {
            days.append(0)
        }
        for day in 1...numDays {
            days.append(day)
        }
        
        return days
    }
    
    private func isCurrentDay(_ day: Int, in monthDate: Date) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        let monthComponents = calendar.dateComponents([.year, .month], from: monthDate)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        return monthComponents.year == todayComponents.year &&
               monthComponents.month == todayComponents.month &&
               day == todayComponents.day
    }
}

#Preview {
    ProfileView(safeArea: EdgeInsets())
}
