# Syrin clean: bàn giao

Trạng thái: PR #1 đã merge vào main ở f4d1d35, sau khi sửa lỗi đọc lại kế hoạch ở 856b16a và đạt hai workflow. Công việc hiện tại chuẩn bị 4.0.0-preview.1 với GitHub Pages và HTML offline theo lựa chọn của chủ dự án. Đây vẫn là pre-release; các cổng VM/môi trường chưa đạt không bị đóng thay.

## Nguồn chuẩn

- project.json: phiên bản, kênh và địa chỉ công khai.
- src/runtime và src/instructions: runtime và chính sách dùng chung; không sửa trực tiếp bản sinh.
- src/shared: token, font có giấy phép và renderer có giới hạn tải.
- src/web: một template EN/VI, module và dữ liệu ngôn ngữ/hồ sơ.
- src/report: mô hình dữ liệu, báo cáo song ngữ và dữ liệu minh họa được ghi rõ.
- tools/build.py: sinh package, prompt, HTML, manifest và checksum.
- tools/publish_site.py: chỉ đưa hai HTML công khai cùng metadata vào thư mục Pages rỗng, ngoài checkout.

## Những gì phải giữ

Thực thi file dùng cùng một bản kế hoạch cho digest, nội dung và dữ liệu lưu trong phiên. ID được chọn, định danh handle, quyền sở hữu root, journal và kiểm tra đường dẫn vẫn bắt buộc. Báo cáo tạo yêu cầu cho agent; nó không thực thi thao tác Windows. Xóa hẳn là kế hoạch riêng và không hoàn tác được.

Trang mở mặc định English; lựa chọn ngôn ngữ của người dùng được giữ. Đổi EN/VI không làm mất hồ sơ, tab hay lựa chọn file. Bản ghi gốc giữ ngôn ngữ nguồn. Dữ liệu chưa biết/chưa đầy đủ vẫn được ghi đúng, không chuyển thành 0 tốt.

Báo cáo thật, journal, đường dẫn máy và backup registry chỉ ở ngoài repository. Pages chỉ có trang chính và báo cáo giả lập. Không dùng báo cáo thật làm ví dụ công khai.

## Kiểm chứng và phát hành

Lệnh chuẩn: python -B -X utf8 tools/build.py, rồi powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1. Các kiểm thử dùng fixture riêng; Restore Point giả lập không chứng nhận dịch vụ thật.

Validate chạy trên Windows. Pages chỉ triển khai tag của bản phát hành đã công bố. Windows kiểm tra và đóng gói thư mục site theo allowlist; Linux nhận artifact, đối chiếu checksum với Release rồi triển khai. Bản phát hành tải lên các artifact được chọn rõ, có checksum; không phát hành nội dung thư mục làm việc.

[Bằng chứng hardening](docs/research/hardening-validation.md), [kiểm chứng giao diện](docs/research/bilingual-validation.md), [kế hoạch phát hành](docs/plan/bilingual-experience.md) và [ma trận hỗ trợ](docs/feat/support.md) phân biệt việc đã làm với giới hạn còn mở.

## Khi tiếp tục

Chủ dự án chưa có VM và đã chọn giữ kiểm chứng VM ở trạng thái chưa xác minh. Không thay phép thử VM bằng thao tác hệ thống thật trên workstation. System Restore, nền tảng/filesystem/provider chưa thử và trợ năng đầy đủ phải có bằng chứng trước khi nâng mức công bố hỗ trợ hoặc gọi bản ổn định.

Chưa có yêu cầu tạo tài khoản/backend, telemetry, dọn tự động định kỳ hoặc thêm adapter tối ưu hệ thống. Ưu tiên chất lượng luồng đã có và dữ liệu kiểm chứng trước khi mở rộng phạm vi.
