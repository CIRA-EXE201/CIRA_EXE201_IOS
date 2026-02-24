//
//  FamiliesView.swift
//  Cira
//
//  Main view for listing and managing the user's families
//

import SwiftUI
import Auth

struct FamiliesView: View {
    @State private var families: [Family] = []
    @State private var isLoading = true
    @State private var showCreateFamily = false
    @State private var showJoinFamily = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGray6).ignoresSafeArea() // Light grey background
            
            if isLoading {
                ProgressView("Đang tải danh sách Gia đình...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if families.isEmpty {
                emptyStateView
            } else {
                familiesList
            }
        }
        .navigationTitle("Gia đình")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showCreateFamily = true }) {
                        Label("Tạo Gia đình mới", systemImage: "plus.circle")
                    }
                    Button(action: { showJoinFamily = true }) {
                        Label("Tham gia bằng Mã", systemImage: "person.badge.key")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Circle())
                }
            }
        }
        .onAppear {
            loadFamilies()
        }
        .sheet(isPresented: $showCreateFamily) {
            CreateFamilyView(onCreated: { newFamily in
                families.insert(newFamily, at: 0)
            })
        }
        .sheet(isPresented: $showJoinFamily) {
            JoinFamilyView(onJoined: { newFamily in
                if !families.contains(where: { $0.id == newFamily.id }) {
                    families.insert(newFamily, at: 0)
                }
            })
        }
    }
    
    // MARK: - Views
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Chưa có Gia đình nào")
                .font(.title2.bold())
                .foregroundColor(.black.opacity(0.8))
            
            Text("Tạo một không gian riêng tư để chia sẻ hình ảnh và kỉ niệm với những người thân yêu nhất của bạn.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button(action: { showCreateFamily = true }) {
                    Text("Tạo Gia đình mới")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Button(action: { showJoinFamily = true }) {
                    Text("Tham gia bằng Mã")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
    }
    
    private var familiesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(families) { family in
                    NavigationLink(destination: FamilyDetailView(family: family)) {
                        FamilyRow(family: family)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Actions
    private func loadFamilies() {
        Task {
            isLoading = true
            do {
                families = try await FamilyService.shared.getMyFamilies()
            } catch {
                print("Lỗi tải danh sách gia đình: \(error)")
            }
            isLoading = false
        }
    }
}

struct FamilyRow: View {
    let family: Family
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Placeholder
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                Text(family.name.prefix(1).uppercased())
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(family.name)
                    .font(.headline)
                    .foregroundColor(.black.opacity(0.9))
                
                if let desc = family.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Nhóm Gia đình")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
        )
    }
}
