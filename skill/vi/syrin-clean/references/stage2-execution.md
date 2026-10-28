# Giai đoạn 2: Thực thi, hoàn tác, báo cáo

=== GIAI ĐOẠN 2: THỰC THI, HOÀN TÁC, BÁO CÁO ===
Sau khi tôi `XÁC NHẬN`:
1. Kiểm tra điều kiện (Quy tắc 8), tạo lưới an toàn (Quy tắc 7). Gom mọi thao tác cần Admin của các mã đã duyệt vào MỘT script thực thi có log từng bước, tự nâng quyền để tôi chỉ bấm UAC một lần.
2. Thứ tự A → B → R → C (sửa chữa trước khi dọn kho thành phần). Không chạm mã không được duyệt. Mỗi mã ghi log: lệnh, thời điểm, kết quả, dung lượng trước/sau, file khóa đã bỏ qua.
3. `undo.ps1` khôi phục được mọi thay đổi cấu hình (Startup, Task, StartupType, power plan, hibernate, registry); đầu file liệt kê việc KHÔNG hoàn tác được và nơi chứa file đã xóa mềm; kiểm tra cú pháp (`[ScriptBlock]::Create((Get-Content -Raw <file>))`) trước khi báo xong.
4. Cần khởi động lại: nói lý do, để tôi chọn lúc, cập nhật `state.json` trước. Khi tôi gõ `Tiếp tục`: tự kiểm tra nhật ký lỗi, số mục Startup, thời gian boot và so với `baseline.json`.
5. BÁO CÁO CUỐI (chat gọn, chi tiết trong `report.html` tự mở). Để có trước/sau: chạy lại `scripts/audit.ps1 -OutDir <thư mục làm việc>\after -Quiet`, rồi `scripts/make-report.ps1 -OutDir <thư mục làm việc>\after -Baseline <thư mục làm việc>\audit.json`. mở đầu bằng 3 dòng lời thường (đã làm gì, máy bạn được gì bằng con số, có gì cần để ý không); sau đó bảng Trước/Sau so với `baseline.json` (dung lượng trống từng ổ, GB đã giải phóng, số Startup/Task/Service, RAM/Commit lúc rảnh, thời gian boot); mã thành công / bỏ qua / lỗi kèm lý do; cách hoàn tác (`Hoàn tác` hoặc `Hoàn tác: A2`; dự phòng khi không còn agent: chạy `powershell -NoProfile -ExecutionPolicy Bypass -File "<đường dẫn>\undo.ps1"` bằng quyền Admin, hoặc System Restore `rstrui.exe` với tên Restore Point); checklist theo dõi 7 ngày (3–5 điểm riêng cho máy này) và lịch bảo trì (Storage Sense, cập nhật Windows/driver, chạy lại Giai đoạn 0 sau 30 ngày).

Khôi phục file đã cách ly: `scripts/quarantine.ps1 -Restore`. Xóa hẳn khu cách ly (chỉ khi người dùng duyệt mã đó): `scripts/quarantine.ps1 -Purge`.
