//
//  ProfileView.swift
//  Cira
//
//  User Profile with calendar showing captured photos
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showSubscription = false
    
    // Mock data - photos for specific days (month-day: color placeholder)
    // Format: "MM-DD" -> Color
    private let photosData: [String: Color] = [
        "12-01": .gray,
        "12-07": .gray,
        "11-15": .gray,
        "11-20": .gray,
        "10-05": .gray
    ]
    
    // Streak data
    private let currentStreak: Int = 5
    private let totalMemories: Int = 42
    
    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button and Gold button
                headerView
                    .padding(.top, 8)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // User Info - Avatar left, Name right
                        userInfoSection
                        
                        // Streak highlight card
                        streakCard
                        
                        // Calendar - all 12 months
                        calendarSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .presentationDetents([.height(600)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            Text("Profile")
                .font(.headline)
            
            Spacer()
            
            // Subscription button - Gold with Apple Liquid Glass
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
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
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 74, height: 74)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.gray)
                        }
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                // Divider line
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                    .frame(maxWidth: 120)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@username")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Joined December 2025")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Streak Card
    private var streakCard: some View {
        HStack(spacing: 20) {
            // Streak
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
            .frame(maxWidth: .infinity)
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 40)
            
            // Total memories
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("📸")
                        .font(.title2)
                    Text("\(totalMemories)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                }
                Text("memories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
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
                ForEach(daysInMonth(for: monthDate), id: \.self) { day in
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
        let hasPhoto = photosData[photoKey] != nil
        let isToday = isCurrentDay(day, in: monthDate)
        
        return VStack(spacing: 2) {
            // Photo thumbnail or empty cell
            ZStack {
                if hasPhoto {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(photosData[photoKey] ?? .gray)
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.08))
                        .aspectRatio(1, contentMode: .fit)
                }
                
                // Today indicator
                if isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black, lineWidth: 2)
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
        
        // Get all 12 months of the selected year (in reverse order - December to January)
        for month in stride(from: 12, through: 1, by: -1) {
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
        formatter.locale = Locale(identifier: "vi_VN")
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
    ProfileView()
}
