//
//  JoinFamilyView.swift
//  Cira
//
//  View to join a family group using an invite code
//

import SwiftUI

struct JoinFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    
    var onJoined: ((Family) -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGray6).ignoresSafeArea() // Light grey
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nhập mã Tham gia")
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.8))
                        
                        TextField("Mã gồm 8 ký tự", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Text("Xin chủ Gia đình mã tham gia rồi dán vào đây.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    Button(action: joinFamilyAction) {
                        HStack(spacing: 8) {
                            if isJoining {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.badge.key")
                                Text("Tham gia Gia đình")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(inviteCode.isEmpty || isJoining ? Color.gray : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    }
                    .disabled(inviteCode.isEmpty || isJoining)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .navigationTitle("Tham gia Gia đình")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
    
    private func joinFamilyAction() {
        Task {
            isJoining = true
            errorMessage = nil
            do {
                let newFam = try await FamilyService.shared.joinFamily(inviteCode: inviteCode)
                onJoined?(newFam)
                dismiss()
            } catch {
                errorMessage = "Lỗi xác thực mã: Mã không hợp lệ hoặc bạn đã tham gia."
            }
            isJoining = false
        }
    }
}
