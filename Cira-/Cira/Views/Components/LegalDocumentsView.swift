//
//  LegalDocumentsView.swift
//  Cira
//
//  In-app Terms of Service and Privacy Policy popups
//

import SwiftUI

// MARK: - Terms of Service
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Cập nhật lần cuối: 16/03/2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        section("1. Chấp nhận Điều khoản",
                                "Bằng việc tải xuống, cài đặt hoặc sử dụng ứng dụng CIRA, bạn đồng ý tuân thủ các Điều khoản Dịch vụ này. Nếu bạn không đồng ý, vui lòng không sử dụng ứng dụng.")
                        
                        section("2. Mô tả Dịch vụ",
                                "CIRA là ứng dụng lưu giữ ký ức gia đình thông qua ảnh, giọng nói và câu chuyện. Ứng dụng cho phép người dùng chụp ảnh hàng ngày, ghi âm giọng nói, tạo chương truyện, và chia sẻ khoảnh khắc với gia đình và bạn bè.")
                        
                        section("3. Tài khoản Người dùng",
                                "Bạn cần tạo tài khoản để sử dụng CIRA. Bạn chịu trách nhiệm bảo mật thông tin đăng nhập của mình. Bạn phải từ 13 tuổi trở lên để sử dụng ứng dụng.")
                        
                        section("4. Nội dung Người dùng",
                                "Bạn sở hữu toàn bộ nội dung bạn đăng lên CIRA (ảnh, giọng nói, văn bản). Bằng việc đăng nội dung, bạn cấp cho CIRA quyền lưu trữ và hiển thị nội dung đó cho những người bạn chia sẻ. Bạn cam kết không đăng nội dung vi phạm pháp luật hoặc xâm phạm quyền người khác.")
                        
                        section("5. Hành vi bị cấm",
                                "Bạn không được: sử dụng ứng dụng cho mục đích bất hợp pháp; đăng nội dung bạo lực, thù ghét, hoặc khiêu dâm; quấy rối hoặc bắt nạt người dùng khác; cố gắng truy cập trái phép hệ thống.")
                        
                        section("6. Xoá Tài khoản",
                                "Bạn có thể xoá tài khoản bất cứ lúc nào trong phần Hồ sơ. Khi xoá, toàn bộ dữ liệu cá nhân sẽ bị xoá vĩnh viễn trong vòng 30 ngày.")
                        
                        section("7. Giới hạn Trách nhiệm",
                                "CIRA được cung cấp \"nguyên trạng\". Chúng tôi không chịu trách nhiệm cho mất mát dữ liệu do lỗi kỹ thuật ngoài tầm kiểm soát.")
                        
                        section("8. Thay đổi Điều khoản",
                                "Chúng tôi có thể cập nhật Điều khoản này. Các thay đổi sẽ được thông báo qua ứng dụng. Việc tiếp tục sử dụng sau khi cập nhật đồng nghĩa với việc bạn chấp nhận các thay đổi.")
                        
                        section("9. Liên hệ",
                                "Nếu có câu hỏi, vui lòng liên hệ: support@cira-app.com")
                    }
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle("Điều khoản Dịch vụ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
    
    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Privacy Policy
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Cập nhật lần cuối: 16/03/2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        section("1. Thông tin chúng tôi thu thập",
                                "Khi sử dụng CIRA, chúng tôi thu thập: thông tin tài khoản (tên, email đăng nhập qua Google); ảnh và ghi âm giọng nói bạn tạo; thông tin thiết bị và thống kê sử dụng cơ bản.")
                        
                        section("2. Cách sử dụng Thông tin",
                                "Chúng tôi sử dụng thông tin để: cung cấp và duy trì dịch vụ; lưu trữ và đồng bộ nội dung của bạn; cải thiện trải nghiệm người dùng; gửi thông báo liên quan đến ứng dụng.")
                        
                        section("3. Lưu trữ Dữ liệu",
                                "Dữ liệu của bạn được lưu trữ an toàn trên Supabase (đối tác lưu trữ đám mây). Ảnh và giọng nói được mã hoá khi truyền tải. Dữ liệu cũng được lưu cục bộ trên thiết bị để trải nghiệm nhanh hơn.")
                        
                        section("4. Chia sẻ Thông tin",
                                "Chúng tôi KHÔNG bán thông tin cá nhân của bạn. Chúng tôi chỉ chia sẻ dữ liệu với: người dùng mà bạn chủ động chia sẻ (gia đình, bạn bè); nhà cung cấp dịch vụ kỹ thuật (Supabase, Google); khi pháp luật yêu cầu.")
                        
                        section("5. Quyền của Bạn",
                                "Bạn có quyền: truy cập và tải xuống dữ liệu của mình; chỉnh sửa thông tin cá nhân; xoá tài khoản và toàn bộ dữ liệu; rút lại sự đồng ý sử dụng camera/microphone bất cứ lúc nào.")
                        
                        section("6. Camera và Microphone",
                                "CIRA cần truy cập camera để chụp ảnh và microphone để ghi âm giọng nói. Bạn có toàn quyền kiểm soát việc cấp phép này trong Cài đặt thiết bị.")
                        
                        section("7. Bảo mật",
                                "Chúng tôi áp dụng các biện pháp bảo mật tiêu chuẩn ngành để bảo vệ dữ liệu của bạn, bao gồm mã hoá SSL/TLS và xác thực an toàn.")
                        
                        section("8. Dữ liệu Trẻ em",
                                "CIRA không dành cho trẻ em dưới 13 tuổi. Chúng tôi không cố ý thu thập dữ liệu từ trẻ em dưới 13 tuổi.")
                        
                        section("9. Liên hệ",
                                "Nếu có câu hỏi về chính sách bảo mật, vui lòng liên hệ: privacy@cira-app.com")
                    }
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle("Chính sách Bảo mật")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
    
    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
