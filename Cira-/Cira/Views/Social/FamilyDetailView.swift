//
//  FamilyDetailView.swift
//  Cira
//
//  Shows family members, invite code (if admin) and leave family option
//

import SwiftUI
import Auth

struct FamilyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let family: Family
    
    @State private var members: [FamilyMemberProfile] = []
    @State private var isLoading = true
    @State private var showLeaveAlert = false
    @State private var isLeaving = false
    
    // Check if current user is admin
    private var isAdmin: Bool {
        let myId = SupabaseManager.shared.currentUser?.id
        return members.first(where: { $0.id == myId })?.role == "admin" || family.owner_id == myId
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGray6).ignoresSafeArea() // Light grey
            
            if isLoading {
                ProgressView("Đang tải danh sách thành viên...")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerView
                        
                        // Invite Code Section (Admin only)
                        if isAdmin, let code = family.invite_code {
                            inviteCodeView(code: code)
                        }
                        
                        // Members Section
                        membersSection
                        
                        // Action buttons
                        leaveButtonSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Thông tin Gia đình")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMembers()
        }
        .alert("Rời Gia đình", isPresented: $showLeaveAlert) {
            Button("Hủy", role: .cancel) { }
            Button("Rời đi", role: .destructive, action: leaveFamilyAction)
        } message: {
            Text("Bạn có chắc chắn muốn rời khỏi gia đình này? Bạn sẽ không thể xem ảnh chung nữa.")
        }
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Text(family.name.prefix(1).uppercased())
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
            }
            .padding(.top, 8)
            
            Text(family.name)
                .font(.title2.bold())
                .foregroundColor(.black.opacity(0.9))
                .multilineTextAlignment(.center)
            
            if let desc = family.description, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func inviteCodeView(code: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mã Tham gia")
                .font(.headline)
            
            HStack {
                Text(code)
                    .font(.body.monospaced().bold())
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = code
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
            )
            
            Text("Chia sẻ mã này cho người thân để họ tham gia chung.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Thành viên")
                    .font(.headline)
                
                Spacer()
                
                Text("\(members.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.06))
                    .clipShape(Capsule())
            }
            
            VStack(spacing: 8) {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        // Avatar
                        if let avatarBase64 = member.avatar_data,
                           let imageData = Data(base64Encoded: avatarBase64),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(String(member.username?.prefix(1) ?? "?").uppercased())
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.username ?? "Người ẩn danh")
                                .font(.headline)
                            
                            if member.role == "admin" {
                                Text("Quản trị viên")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("Thành viên")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
                    )
                }
            }
        }
    }
    
    private var leaveButtonSection: some View {
        Button(action: { showLeaveAlert = true }) {
            HStack {
                if isLeaving {
                    ProgressView()
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Rời Gia đình")
                }
            }
            .font(.headline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.05)))
            )
        }
        .disabled(isLeaving)
        .padding(.top, 24)
    }
    
    // MARK: - Actions
    private func loadMembers() {
        Task {
            isLoading = true
            do {
                members = try await FamilyService.shared.getFamilyMembers(familyId: family.id)
            } catch {
                print("Lỗi tải members: \(error)")
            }
            isLoading = false
        }
    }
    
    private func leaveFamilyAction() {
        Task {
            isLeaving = true
            do {
                try await FamilyService.shared.leaveFamily(familyId: family.id)
                dismiss() // Exit detail screen
            } catch {
                print("Lỗi rời gia đình: \(error)")
                isLeaving = false
            }
        }
    }
}
