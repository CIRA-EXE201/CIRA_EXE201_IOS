//
//  CreateFamilyView.swift
//  Cira
//
//  View to create a new family group
//

import SwiftUI

struct CreateFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var familyDescription = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var onCreated: ((Family) -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGray6).ignoresSafeArea() // Light grey
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tên Gia đình")
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.8))
                        
                        TextField("VD: Gia đình 4 con Gà", text: $familyName)
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mô tả (Không bắt buộc)")
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.8))
                        
                        TextField("Viết gì đó về gia đình của bạn...", text: $familyDescription)
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
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Spacer()
                    
                    Button(action: createFamilyAction) {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus")
                                Text("Tạo Gia đình")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(familyName.isEmpty || isCreating ? Color.gray : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    }
                    .disabled(familyName.isEmpty || isCreating)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .navigationTitle("Tạo Gia đình")
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
    
    private func createFamilyAction() {
        Task {
            isCreating = true
            errorMessage = nil
            do {
                let newFam = try await FamilyService.shared.createFamily(name: familyName, description: familyDescription.isEmpty ? nil : familyDescription)
                onCreated?(newFam)
                dismiss()
            } catch {
                errorMessage = "Có lỗi xảy ra: \(error.localizedDescription)"
            }
            isCreating = false
        }
    }
}
