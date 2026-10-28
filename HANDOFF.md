# Syrin clean: bàn giao hardening

Trạng thái: đã triển khai và đạt kiểm thử cục bộ/CI; bản phát triển ở [PR nháp #1](https://github.com/sovergarden-dev/syrin-clean/pull/1), nhánh `codex/hardening`, chưa phát hành ổn định. Baseline audit là `a0752aa`; phiên bản tên file 3.6 được giữ, thay đổi ghi ở Unreleased.

## Phạm vi và quyết định đã chốt

Chủ dự án đã đồng ý toàn bộ kế hoạch sửa/nâng cấp. Sau khi Hyper-V báo thiếu quyền quản lý, chủ dự án xác nhận chưa có VM và yêu cầu giữ kiểm chứng VM ở trạng thái chưa xác minh. Không thử Restore Point hoặc thay đổi hệ thống thật trên máy cá nhân để thay thế VM.

Runtime mới tự động hóa vòng đời file theo kế hoạch cố định. Chỉnh cấu hình, sửa Windows và gỡ ứng dụng giữ ở dạng tư vấn tới khi có adapter/quy trình đã kiểm chứng. Đây không phải sandbox cho một agent có toàn quyền shell.

## Nguồn chuẩn

- `src/runtime`: module và entry point dùng chung; `src/instructions`: chính sách và các giai đoạn EN/VI.
- `src/report`: báo cáo và mô hình dữ liệu; `src/web`: logic/CSS chung và nội dung giao diện theo ngôn ngữ.
- `src/install.ps1`: staging, checksum, khóa tiến trình, rollback; backup nằm ngoài thư mục nạp skill.
- `tools/build.py`: sinh mọi bản phân phối; không sửa trực tiếp file sinh trong skill, web, prompts hoặc dist.

## Những thay đổi chính

- Lập kế hoạch theo từng file, mã ngắn cho người dùng, ID cố định và digest cho bộ thực thi.
- Root có chủ sở hữu, khóa writer, kế hoạch bất biến và journal append-only. Xung đột được giữ; resume đối chiếu trạng thái, không đoán hay lặp xóa.
- Rename và purge dùng handle với kiểm tra định danh file; không xóa cây thư mục hoặc dữ liệu ngoài danh sách. Chặn đường dẫn không được hỗ trợ, reparse/recall và quan hệ cloud đã nhận diện.
- Audit schema có trạng thái collector và phân loại dữ liệu rõ. Báo cáo không biến thiếu số liệu thành 0 tốt, không coi app/VM là rác, chọn đúng ổ hệ thống và so sánh cùng máy.
- Parse/schema sai không ghi đè báo cáo tốt; report mode none không tạo HTML. Có lịch sử, yêu cầu khôi phục từng item và bản chia sẻ tổng hợp.
- Trình cài xác minh trước khi thay, có rollback và giữ bản cũ. Build dùng allowlist, manifest, checksum; prompt độc lập mang cùng runtime và extractor chống traversal.
- Giao diện có tab semantics/keyboard, nhóm lựa chọn nâng cao, nội dung chính trước cảnh 3D trên mobile; báo cáo dừng hiệu ứng khi tạm dừng, khuất viewport hoặc tab không hiển thị.

## Kiểm chứng

Các regression test dùng file/profile fixture riêng, Windows PowerShell 5.1 và Node. Chúng bao gồm xung đột khôi phục, purge đúng mục, lỗi journal, thay file ngay trước xóa, khóa writer, junction thật, import CSV cũ, dữ liệu thiếu, quoting Unicode, Restore Point giả lập, checksum, rollback bộ cài và extractor. Đợt tiếp theo bổ sung chuỗi gọi CLI không làm mất hàm của caller, đọc JSON/hash cùng một phiên bản byte, sửa lỗi cập nhật báo cáo và thử cây 2.048 file.

Lệnh chuẩn: `python -B -X utf8 tools/build.py`, rồi `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1`. CI Windows chạy cùng bộ kiểm tra với quyền repo chỉ đọc; không tự deploy/release.

Kết quả nghiệm thu cuối cùng và các giới hạn nằm trong [kế hoạch](docs/plan/hardening.md), [ma trận hỗ trợ](docs/feat/support.md) và [hướng dẫn kiểm chứng](docs/ref/validation.md). Không suy ra Windows 10/11, ARM64, provider cloud, UAC thật hoặc mọi agent đều đã đạt từ các test fixture.

[Bằng chứng thực nghiệm](docs/research/hardening-validation.md) ghi 15 ca quarantine, 7 nhóm runtime, mô hình báo cáo, 7 ca đóng gói/cài đặt, 61 đầu ra build và các kiểm tra trình duyệt. Hai workflow GitHub trên commit triển khai `4680f1e` đều đạt, gồm kiểm tra checkout sạch sau chạy test.

Các số liệu trên thuộc đợt triển khai ban đầu. Đợt ngày 29/10 đạt 16 ca quarantine, 10 nhóm runtime, mô hình báo cáo, bài thử cây 2.048 file/12 phiên và 7 ca đóng gói; 61 đầu ra khớp nguồn. Giao diện báo cáo EN/VI được thử với 37 phiên giả lập, chọn file qua nhiều trang, chặn chọn file đã xóa và hiển thị lỗi nhật ký; bố cục 390/1366 px không tràn ngang. [Kế hoạch mở rộng runtime](docs/plan/runtime-scale.md) theo dõi kiểm tra thuộc tính native, policy tham chiếu trong từng thao tác, lịch sử đầy đủ, tiến độ audit và hiệu ứng nhẹ hơn. Nhật ký chạy thật chứa thông tin riêng được giữ ngoài repository; kết quả của một máy không thay thế nghiệm thu VM hoặc mọi cấu hình hỗ trợ.

## Khi tiếp tục

Dùng [lệnh runtime](docs/ref/commands.md), [kiến trúc](docs/arch/project.md) và [hợp đồng thực thi](docs/arch/execution.md). Báo cáo audit gốc được giữ nguyên theo baseline trong `docs/research/audit-safety.md`; không sửa lại lịch sử để giả vờ lỗi chưa từng tồn tại.

Các cổng VM/phần cứng/agent chưa thử phải giữ mở. Khi có VM dùng một lần và snapshot, mới kiểm chứng dịch vụ System Restore, rollback registry, lỗi quyền, file khóa, cloud placeholders và ma trận được quảng bá. Không tạo tag, release hoặc tuyên bố bản ổn định khi các cổng đó chưa đạt.
