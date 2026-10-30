# Syrin clean

**Kiểm tra Windows, xem bằng chứng, duyệt đúng thao tác file.**

Đây là bộ skill và prompt song ngữ dùng chung runtime PowerShell. **4.0.0-preview.2 là bản pre-release**, còn các cổng kiểm chứng môi trường. Cấu hình chưa thử không được coi là đã chứng nhận.

[English](README.md) · [Lệnh sử dụng](docs/ref/commands.md) · [Ma trận hỗ trợ](docs/feat/support.md) · [Kiểm chứng](docs/ref/validation.md) · [Lịch sử thay đổi](CHANGELOG.md)

## Các phần đã có

- Kiểm tra chỉ đọc với trạng thái đầy đủ, một phần, không khả dụng hoặc lỗi; thiếu số liệu không biến thành “0 lỗi”.
- Phân biệt cache, dữ liệu ứng dụng, file cá nhân, máy ảo và dữ liệu hệ thống; không đồng nhất dung lượng đo được với dung lượng sẽ giải phóng.
- Lập kế hoạch theo từng file trước khi cách ly, khôi phục hoặc xóa hẳn. Người dùng duyệt mã ngắn; agent giữ ánh xạ ID và mã băm của đúng kế hoạch.
- Nhật ký bền vững, kiểm tra định danh file, xử lý trùng tên, tiếp tục sau gián đoạn và lịch sử phiên.
- Báo cáo offline EN/VI, so sánh cùng máy và bản xuất tổng hợp đã lược bỏ thông tin riêng thô.
- Có tiến độ kiểm tra, chọn phiên và phân trang để xem đủ lịch sử đã tải; hiệu ứng báo cáo được giới hạn số lần vẽ.

Thao tác tự động hiện giới hạn ở vòng đời file mà runtime hỗ trợ. Chỉnh hệ thống, sửa Windows, gỡ app và phần cứng giữ ở dạng tư vấn tới khi có hỗ trợ đã kiểm chứng. Cách ly không thay sao lưu và không giải phóng dung lượng; xóa hẳn là bước riêng, không hoàn tác được.

## Bắt đầu bằng chỉ kiểm tra

1. Tải [gói tiếng Việt](dist/syrin-clean-skill-v4.0.0-preview.2-vi.zip) hoặc [gói tiếng Anh](dist/syrin-clean-skill-v4.0.0-preview.2-en.zip) của nhánh này.
2. Nhờ agent kiểm tra gói rồi chạy `install.ps1` bằng Windows PowerShell 5.1. Trình cài chuẩn bị và xác minh trước khi thay; bản cũ được giữ ngoài thư mục nạp skill ở `%USERPROFILE%\.syrin-clean-installer`.
3. Mở phiên agent mới và gửi: **Dùng skill syrin-clean để kiểm tra máy và lập đề xuất, chưa thực thi thay đổi.**
4. Đọc bằng chứng và phần chưa đo được. Với thao tác file, xem đúng danh sách và xác nhận các mã đã chọn; không duyệt mơ hồ việc liên quan file cá nhân hoặc xóa hẳn.

Hai vị trí cài là `.claude/skills/syrin-clean` và `.agents/skills/syrin-clean`. Đã kiểm tra việc cài file; khả năng nạp và luồng đầy đủ của từng agent/phiên bản vẫn cần kiểm chứng. Trình cài không dọn máy.

## Prompt độc lập và trang HTML

[Prompt VI](prompts/syrin-clean-prompt-vi-v4.0.0-preview.2.md) và [prompt EN](prompts/syrin-clean-prompt-en-v4.0.0-preview.2.md) có cùng runtime được nhúng. Agent đọc phần PROMPT, trích bootstrap bằng lệnh filesystem rồi giải nén vào thư mục mới, trống; không chép Base64 vào ngữ cảnh model. Bootstrap kiểm tra mã băm và đường dẫn, không thực thi dọn dẹp.

Mở [bản web](https://sovergarden-dev.github.io/syrin-clean/) hoặc tải [một file HTML offline](dist/syrin-clean.html). Mặc định English, chuyển EN/VI ngay trong trang và giữ hồ sơ đang nhập. Font, cả hai gói, bộ tạo prompt và [báo cáo giả lập](dist/syrin-clean-report-demo.html) đều được nhúng. Trang không chạy lệnh Windows. File đính kèm Releases được tải về; liên kết Pages mở bản web.

Báo cáo cũng có nút EN/VI, tìm và lọc lịch sử, giữ lựa chọn qua các trang và bản in tóm tắt. Bản ghi gốc giữ ngôn ngữ nguồn. Hiệu ứng có giới hạn tải và nút tạm dừng.

## Dữ liệu riêng và giới hạn

Phiên kiểm tra mặc định ở `%LOCALAPPDATA%\SyrinClean\Sessions`; khu cách ly ở `%LOCALAPPDATA%\SyrinClean\Quarantine`. Root tùy chọn phải cục bộ, thuộc chủ sở hữu và tách khỏi file được chọn. Di chuyển ở cùng ổ. Provider cloud và filesystem chưa thử cần xem riêng.

Runtime không upload dữ liệu. Agent/nhà cung cấp có thể xử lý đầu ra terminal ngoài máy. Báo cáo và kế hoạch thô chứa đường dẫn riêng; không đưa chúng vào Git hoặc chia sẻ nhầm. `make-report.ps1 -Share -NoOpen` tạo bản tổng hợp để xem lại, không bảo đảm ẩn danh tuyệt đối.

Theo lựa chọn của chủ dự án, **kiểm chứng VM vẫn chưa xác minh**. Không dùng thử thao tác hệ thống thật trên máy cá nhân để thay cho VM. Xem [ma trận hỗ trợ](docs/feat/support.md).

## Build và kiểm thử

Cần Python 3.10+, Node.js 22+ và Windows PowerShell 5.1 cho toàn bộ bộ kiểm tra; không cần cài thư viện npm/Python.

```powershell
python -B -X utf8 tools/build.py
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1
```

Nguồn chuẩn nằm trong `src/runtime`, `src/instructions`, `src/report`, `src/web`. Các gói `skill/`, `dist/`, prompt và HTML được sinh lại; không sửa riêng bản nhúng. `build.py --check` chỉ xác minh, không ghi file. CI kiểm thử trên Windows, không tự phát hành hoặc triển khai website.

[Kiến trúc](docs/arch/project.md) · [Hợp đồng thực thi](docs/arch/execution.md) · [Bàn giao](HANDOFF.md) · [Bảo mật](SECURITY.md) · [MIT](LICENSE)
