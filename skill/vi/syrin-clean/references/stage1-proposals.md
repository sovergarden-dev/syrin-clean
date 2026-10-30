# Giai đoạn 1: đề xuất và xác nhận

Hiện mã ngắn trong từng kế hoạch (Q1, R1, P1), tên file, dung lượng và hậu quả. Ánh xạ chúng vào ID cố định trong kế hoạch. Giữ mã băm đầy đủ trong hồ sơ; hiện mã tham chiếu ngắn để người dùng phân biệt lần sửa. Chỉ tra mã đã xác nhận trong đúng kế hoạch đó; không bắt người dùng gõ UUID dài.

Dùng cột lời thường: ID, việc làm, bằng chứng, lợi ích dự kiến, mất mát/rủi ro và hoàn tác. Tách tư vấn hiệu năng, rà soát cache, lựa chọn file cá nhân, sửa chữa và phần cứng. Thao tác hệ thống chưa được hỗ trợ giữ ở dạng tư vấn, ghi rõ; Restore Point không làm việc không thể hoàn tác trở thành có thể hoàn tác.

Với file, gọi `scripts/quarantine.ps1 -Operation quarantine -Path <đường dẫn cụ thể> -QuarantineRoot <root cục bộ mới, trống, cùng ổ> -PlanFile <thư mục làm việc>\file-plan.json`. Lập kế hoạch không di chuyển file. Xem đúng item, định danh file và mã băm trả về. Chọn thư mục sẽ mở rộng thành file; lỗi hoặc đường dẫn không an toàn không tạo kế hoạch thực thi. Không đặt khu cách ly bên trong thư mục được chọn.

Muốn khôi phục hoặc xóa hẳn, chạy `scripts/quarantine.ps1 -History -QuarantineRoot <root>` trước. Lập kế hoạch bằng `-Operation restore|purge -SessionId <id> -ItemId <các ID cụ thể> -PlanFile <thư mục làm việc>\recovery-plan.json`. Khôi phục mặc định giữ file đang có và ghi xung đột. `-Conflict rename` hoặc `-RestoreDirectory <thư mục cục bộ>` tạo đích khác để xem lại. Phiên nhập từ bản cũ chỉ hỗ trợ khôi phục.

Có thể ghi proposals.json theo assets/proposals.schema.json với audit sessionId. Đây là dữ liệu trình bày, không phải quyền thực thi. Tạo lại báo cáo đã chọn bằng `scripts/make-report.ps1 -OutDir <dir> -Lang en|vi -QuarantineRoot <root>` chỉ khi report mode cho phép.

Với lịch sử dài, đọc `report-progress.json` để biết giai đoạn, số phiên đã xử lý/lỗi, sự kiện đã xác minh và thời gian đã chạy. `-Quiet` ẩn tiến độ trên console nhưng vẫn ghi file này. Cần `status=completed`, `htmlWritten=true` và kiểm tra `historyErrors`; 100% chỉ xác nhận đã ghi HTML, không bảo đảm mọi phiên lịch sử đều hợp lệ. Bản ghi `running` đã cũ không chứng minh tiến trình còn sống. Không chia sẻ file tiến độ riêng tư này.

Trình bày kế hoạch rồi yêu cầu người dùng xác nhận đúng thao tác và ID. Nêu rõ cách ly giải phóng 0 byte; xóa hẳn không hoàn tác được. Không biến “tất cả” hoặc “khuyến nghị” thành đồng ý với file cá nhân hoặc việc không hoàn tác được nếu chưa nhắc lại ID cụ thể và nhận xác nhận. DỪNG tại đây cho tới khi người dùng xác nhận.
