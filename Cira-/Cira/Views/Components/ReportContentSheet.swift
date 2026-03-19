//
//  ReportContentSheet.swift
//  Cira
//
//  Bottom sheet for reporting content (App Store compliance)
//

import SwiftUI

struct ReportContentSheet: View {
    let postId: UUID?
    let reportedUserId: UUID
    let reportedUsername: String
    var onDismiss: (() -> Void)? = nil
    
    @State private var selectedReason: ReportReason?
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showSuccess {
                    successView
                } else {
                    reportForm
                }
            }
            .navigationTitle("Báo cáo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") {
                        dismiss()
                        onDismiss?()
                    }
                }
            }
        }
    }
    
    // MARK: - Report Form
    private var reportForm: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                
                Text("Tại sao bạn muốn báo cáo nội dung này?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("Báo cáo của bạn sẽ được xem xét trong 24 giờ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            
            // Reason Picker
            VStack(spacing: 4) {
                ForEach(ReportReason.allCases) { reason in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedReason = reason
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: reason.icon)
                                .font(.system(size: 16))
                                .frame(width: 24)
                                .foregroundStyle(selectedReason == reason ? .white : .primary)
                            
                            Text(reason.displayName)
                                .font(.body)
                                .foregroundStyle(selectedReason == reason ? .white : .primary)
                            
                            Spacer()
                            
                            if selectedReason == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedReason == reason ? Color.black : Color.gray.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            // Details (optional)
            if selectedReason != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chi tiết (tuỳ chọn)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("Mô tả thêm...", text: $details, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.08))
                        )
                }
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Submit Button
            Button {
                submitReport()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Gửi báo cáo")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedReason == nil ? Color.gray : Color.red)
                )
            }
            .disabled(selectedReason == nil || isSubmitting)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            
            Text("Cảm ơn bạn!")
                .font(.title2.bold())
            
            Text("Báo cáo của bạn đã được ghi nhận.\nChúng tôi sẽ xem xét trong thời gian sớm nhất.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                dismiss()
                onDismiss?()
            } label: {
                Text("Đóng")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Submit
    private func submitReport() {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await ReportService.shared.reportContent(
                    postId: postId,
                    reportedUserId: reportedUserId,
                    reason: reason,
                    details: details.isEmpty ? nil : details
                )
                withAnimation {
                    showSuccess = true
                }
            } catch {
                errorMessage = "Không thể gửi báo cáo. Vui lòng thử lại."
            }
            isSubmitting = false
        }
    }
}
