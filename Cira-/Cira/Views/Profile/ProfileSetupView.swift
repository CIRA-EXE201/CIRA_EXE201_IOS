//
//  ProfileSetupView.swift
//  Cira
//
//  Profile setup screen for new users
//

import SwiftUI
import PhotosUI
import Supabase

struct ProfileSetupView: View {
    @State private var username = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCompleted = false
    
    var body: some View {
        if isCompleted {
            ContentView()
        } else {
            NavigationStack {
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Title
                    Text("Complete Your Profile")
                        .font(.title.bold())
                    
                    // Avatar Picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let avatarData, let uiImage = UIImage(data: avatarData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                avatarData = data
                            }
                        }
                    }
                    
                    Text("Tap to add a profile photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline.bold())
                        
                        TextField("Enter your username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Error Message
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Complete Button
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Complete Setup")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(username.isEmpty ? Color.gray : Color.black)
                        )
                    }
                    .disabled(username.isEmpty || isLoading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func saveProfile() {
        guard !username.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let userId = SupabaseManager.shared.currentUser?.id else {
                    throw NSError(domain: "ProfileSetup", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                }
                
                // Create profile data
                let profileData = ProfileUpdateData(
                    username: username,
                    avatar_data: avatarData?.base64EncodedString()
                )
                
                // Update profile in Supabase
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(profileData)
                    .eq("id", value: userId.uuidString)
                    .execute()
                
                withAnimation {
                    isCompleted = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Encodable Model
struct ProfileUpdateData: Encodable {
    let username: String
    let avatar_data: String?
}

#Preview {
    ProfileSetupView()
}
