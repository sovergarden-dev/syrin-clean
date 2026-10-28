# Giai đoạn 0: kiểm tra chỉ đọc

1. Xác định phạm vi và lựa chọn báo cáo. Chạy `scripts/audit.ps1 -OutDir <thư mục làm việc mới> -Scope full|health|speed|cleanup -ReportMode 3d|simple|none -Lang en|vi -MaxSeconds <profile-budget> -Quiet`. Bắt đầu không nâng quyền. Đọc danh sách `incomplete` và lỗi collector. Chỉ xin UAC qua run-elevated.ps1 cho phép đọc cụ thể thực sự lỗi vì thiếu quyền.
2. Đọc audit.json schema 1. Metadata có sessionId, machineId, systemDrive. Mỗi collector có status, data, errors. Dữ liệu thiếu hoặc chưa đầy đủ vẫn phải hiện là chưa biết. Xem ổ đĩa, RAM, startup, nhật ký, bảo mật, thiết bị và các loại dữ liệu trước khi đề xuất. Phạm vi/ngân sách có thể chủ động bỏ collector.
3. Dùng bằng chứng Windows chỉ đọc để làm rõ quản lý tổ chức khi system.managementStatus chưa biết. Máy domain/Entra/MDM chỉ báo cáo. Collector chạy thành công không phải quyền thay đổi.
4. Giữ bản kiểm tra đầu thành baseline.json trước lần đo tiếp. Không so với máy khác hoặc schema không tương thích. Nêu rõ phần cứng, agent, provider chưa được đo hoặc thử.
5. Tóm tắt sức khỏe, nút thắt có bằng chứng, dung lượng cache so với app/user/VM/system và phần chưa biết. Không đồng nhất byte cache với dung lượng thu hồi. Mode none không tạo HTML. Không mở hoặc tạo lại báo cáo trái lựa chọn.
6. Sang bước đề xuất. Nếu chỉ khám sức khỏe thì dừng ở tư vấn, không đề xuất thao tác thay đổi.
