<div align="center">

# Syrin clean

**Máy nhanh lại. Bạn chỉ duyệt.**

Skill và prompt cho AI Agent trên máy bạn: tự kiểm tra, tăng tốc và dọn dẹp Windows 10/11 an toàn, bạn chỉ duyệt bằng lời thường.

[English](README.md) · [Tài liệu](docs/index.md) · [Ghi chú bàn giao](HANDOFF.md) · [Lịch sử phiên bản](CHANGELOG.md)

</div>

![Câu chuyện 3D: quét, cách ly, dọn](docs/images/scene-sequence.png)

## Vì sao có dự án này

Nhiều mẹo "tối ưu máy" khuyên xóa Prefetch, dọn registry hay tắt Defender. Nhiều AI agent khi được nhờ "dọn máy" thì tự nghĩ ra lệnh trên một máy chưa từng thấy. Dự án này đưa cho agent một quy trình đã được thiết kế kỹ:

- **Đo trước, kết luận sau:** phần cứng, bản Windows, loại và sức khỏe ổ, RAM, nhiệt, app khởi động, nhật ký lỗi và khoảng 50 vị trí rác, tất cả chỉ đọc.
- **Bạn quyết định bằng lời thường:** mỗi đề xuất ghi được gì, mất gì, quay lại được không. Không rành máy tính thì gõ `Duyệt gói khuyến nghị`.
- **Luôn có đường quay lại:** Restore Point đã xác minh, sao lưu registry, `undo.ps1` theo từng mã, khu cách ly cho file cá nhân.
- **Tiết kiệm quota:** script viết sẵn, đầu ra nhỏ, tài liệu nạp theo từng bước.

## Bắt đầu nhanh

**Cách 1: cài skill (khuyên dùng)**
1. Tải [skill tiếng Việt](https://github.com/sovergarden-dev/syrin-clean/raw/refs/heads/main/dist/syrin-clean-skill-v3.6-vi.zip) hoặc [skill tiếng Anh](https://github.com/sovergarden-dev/syrin-clean/raw/refs/heads/main/dist/syrin-clean-skill-v3.6-en.zip) (hướng dẫn tiếng Anh, vẫn trả lời tiếng Việt).
2. Nhắn agent: *"Hãy cài skill từ file zip này: `<đường dẫn>`. Giải nén ra thư mục tạm rồi chạy install.ps1 bằng `powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1`."*
3. Mở **phiên mới** của agent và gửi: *"Dùng skill syrin-clean để kiểm tra, tối ưu và dọn dẹp máy tính này."*

Lần đầu nên chạy chế độ **Chỉ kiểm tra**: trang web có nút tạo sẵn câu mở đầu này.

Để dùng trang tùy chỉnh, tải repo về rồi mở `web/syrin-clean-vi-v3.6.html` hoặc `web/syrin-clean-en-v3.6.html` bằng trình duyệt. Trang đã nhúng file skill và bộ tạo prompt, không cần chạy server.

**Cách 2: dùng file prompt** (mọi agent có terminal): lưu `prompts/syrin-clean-prompt-vi-v3.6.md` vào máy rồi nhắn agent *"Đọc file `<đường dẫn>` và làm đúng theo phần PROMPT"*. File đã kèm bộ lệnh kiểm tra, mẫu báo cáo 3D và script tạo báo cáo.

## Câu lệnh chat

`Duyệt: A1, B1-B6, C2` · `Duyệt gói khuyến nghị` · `Bỏ: B4` · `Giải thích: C3` · `XÁC NHẬN` · `DỪNG` · `Tiếp tục` · `Hoàn tác` / `Hoàn tác: A2`. Nói tự nhiên cũng được; agent nhắc lại mã trước khi làm.

## Cấu trúc, build, kiểm thử

Xem [README.md](README.md) (tiếng Anh) cho cấu trúc thư mục, bảng script, cách build (`python tools/build.py`) và cách kiểm thử (`?check`). Trạng thái công việc và việc còn mở nằm trong [HANDOFF.md](HANDOFF.md).

## Miễn trừ

Dự án chỉ thay đổi hệ thống sau khi bạn duyệt và luôn tạo đường quay lại, nhưng không công cụ nào thay được bản sao lưu dữ liệu của chính bạn.

## Giấy phép

[MIT](LICENSE)
