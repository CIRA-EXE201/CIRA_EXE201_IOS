//
//  AddFriendsView.swift
//  Cira
//
//  View for adding friends and family with search, invite link, and suggestions
//

import SwiftUI
import Auth

struct AddFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [FriendProfile] = []
    @State private var isSearching = false
    @State private var showShareSheet = false
    @State private var pendingRequests: [Friendship] = []
    @State private var selectedTab = 0
    
    // Generate invite link based on current user
    private var inviteLink: String {
        let userId = SupabaseManager.shared.currentUser?.id.uuidString ?? "unknown"
        return "https://cira-web-blue.vercel.app/invite/\(userId)"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text("Add Friends").tag(0)
                    Text("Pending").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                if selectedTab == 0 {
                    addFriendsContent
                } else {
                    pendingRequestsContent
                }
            }
            .background(Color.white)
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                loadPendingRequests()
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [inviteLink])
            }
        }
    }
    
    // MARK: - Add Friends Content
    private var addFriendsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search Bar
                searchBar
                
                // Invite Link Section
                inviteLinkSection
                
                // Search Results or Suggestions
                if !searchText.isEmpty {
                    searchResultsSection
                } else {
                    suggestedFriendsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search by username...", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    performSearch(query: newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Invite Link Section
    private var inviteLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite Friends")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share your invite link")
                        .font(.subheadline)
                    Text("Friends can add you directly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.06))
            )
        }
    }
    
    // MARK: - Search Results
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Search Results")
                    .font(.headline)
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if searchResults.isEmpty && !isSearching {
                Text("No users found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                ForEach(searchResults) { user in
                    userRow(user: user)
                }
            }
        }
    }
    
    // MARK: - Suggested Friends
    private var suggestedFriendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested")
                .font(.headline)
            
            Text("Find friends by searching their username above")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
        }
    }
    
    // MARK: - User Row
    private func userRow(user: FriendProfile) -> some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarBase64 = user.avatar_data,
               let imageData = Data(base64Encoded: avatarBase64),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(String(user.username?.prefix(1) ?? "?").uppercased())
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username ?? "Unknown")
                    .font(.headline)
                Text("@\(user.username?.lowercased() ?? "user")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { sendFriendRequest(to: user) }) {
                Text("Add")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.black)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.06))
        )
    }
    
    // MARK: - Pending Requests Content
    private var pendingRequestsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if pendingRequests.isEmpty {
                    Text("No pending requests")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 48)
                } else {
                    ForEach(pendingRequests) { request in
                        pendingRequestRow(request: request)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Pending Request Row
    private func pendingRequestRow(request: Friendship) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Friend Request")
                    .font(.headline)
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { acceptRequest(request) }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                
                Button(action: { declineRequest(request) }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.06))
        )
    }
    
    // MARK: - Actions
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        Task {
            do {
                searchResults = try await FriendService.shared.searchUsers(query: query)
            } catch {
                print("Search failed: \(error)")
            }
            isSearching = false
        }
    }
    
    private func sendFriendRequest(to user: FriendProfile) {
        Task {
            do {
                try await FriendService.shared.sendFriendRequest(to: user.id)
                // Remove from search results after sending
                searchResults.removeAll { $0.id == user.id }
            } catch {
                print("Failed to send request: \(error)")
            }
        }
    }
    
    private func loadPendingRequests() {
        Task {
            do {
                pendingRequests = try await FriendService.shared.getPendingRequests()
            } catch {
                print("Failed to load pending requests: \(error)")
            }
        }
    }
    
    private func acceptRequest(_ request: Friendship) {
        Task {
            do {
                try await FriendService.shared.acceptFriendRequest(request.id)
                pendingRequests.removeAll { $0.id == request.id }
            } catch {
                print("Failed to accept: \(error)")
            }
        }
    }
    
    private func declineRequest(_ request: Friendship) {
        Task {
            do {
                try await FriendService.shared.removeFriend(request.id)
                pendingRequests.removeAll { $0.id == request.id }
            } catch {
                print("Failed to decline: \(error)")
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AddFriendsView()
}
