# Kế hoạch tăng độ tin cậy cho Syrin clean

Trạng thái: **đã triển khai, đạt kiểm thử cục bộ và CI; các cổng nghiệm thu môi trường vẫn mở**. Baseline `a0752aa`, ngày 2026-10-28; nhánh `codex/hardening`, [PR nháp #1](https://github.com/sovergarden-dev/syrin-clean/pull/1). Nguồn: [báo cáo kiểm tra](../research/audit-safety.md) và [bằng chứng](../research/audit-evidence.json). Đích: thao tác đúng phạm vi, có đường phục hồi được kiểm chứng và báo cáo không biến dữ liệu thiếu thành kết luận tốt.

## 1. Khép kín vòng đời file

Xử lý F01–F04 trước các tính năng dọn mới.

- [x] Thiết kế journal theo phiên/item với các trạng thái planned, moving, quarantined, restoring, restored, conflict, failed, purged; ghi và kiểm tra journal trước khi thao tác.
- [x] Dùng cùng một resolver cho root ở apply/restore/purge; kiểm tra root thuộc phiên và đường dẫn item nằm đúng phạm vi, không nhận root ổ đĩa hoặc thư mục dùng chung làm khu cách ly.
- [x] Purge chỉ xử lý các item được chọn, không xóa dữ liệu ngoài manifest hoặc cả thư mục người dùng đã truyền.
- [x] Khôi phục có conflict policy rõ: giữ bản mới, khôi phục sang tên khác hoặc chờ lựa chọn. Item chưa xử lý luôn còn khả năng resume.
- [x] Khi move/copy/journal thất bại, trả trạng thái thật và giữ đủ thông tin để phục hồi; mã thoát thể hiện lỗi hoặc hoàn thành một phần.
- [x] Kiểm tra đường dẫn cloud theo quan hệ thư mục thật, tổ tiên/hậu duệ, symlink/junction, file offline và reparse root; provider chưa nhận diện phải được nêu rõ.
- [x] Sau đo lịch sử lớn: chuyển vòng chuẩn hóa/kiểm tra tổ tiên sang helper native, giữ nguyên chặn đường dẫn và kiểm tra handle; toàn bộ regression đạt và bản đã cài tạo lại báo cáo thật đầy đủ mà không thay audit/baseline gốc.

Nghiệm thu: file ngoài phạm vi không bị đụng; conflict không mất journal; lỗi sau từng bước không tạo file mồ côi; chạy lại không làm lặp thao tác; QuarantineRoot tùy chọn có cùng nghĩa trong cả ba mode. Bộ kiểm thử tự động chỉ xóa file fixture trong môi trường cách ly. Lượt sử dụng thật cần kế hoạch và sự duyệt riêng của chủ máy; bằng chứng riêng không đưa vào repository.

## 2. Làm đúng dữ liệu và giao tiếp với Windows

Xử lý F05–F10, F13–F14 và hardening Restore Point.

- [x] Tạo schema có phiên bản cho audit, proposals và state; thêm session/volume identity, trạng thái collector, lỗi, thời điểm đo và giới hạn quét.
- [x] Tách measured, estimated và reclaimable; phân loại cache/app data/user data/VM/system bằng trường dữ liệu, không suy từ nhãn.
- [x] Collector lỗi, không đủ quyền, bị timeout hoặc bị cắt bớt kết quả phải xuất partial/unavailable, không báo 0 healthy.
- [x] Dùng đúng ổ hệ thống và tách số liệu theo ổ; chỉ so sánh baseline tương thích.
- [x] Khóa StartupApproved theo hive + nhánh + tên; kiểm tra đồng thời HKCU, HKLM và 32-bit.
- [x] Sửa truyền tham số qua tiến trình và mã lỗi của elevation helper; kiểm tra chuỗi rỗng, Unicode, khoảng trắng, dấu nháy và dấu backslash cuối.
- [x] Kiểm tra JSON/schema trước khi tạo report; đầu vào lỗi không ghi đè báo cáo hợp lệ.
- [x] Sửa lỗi thay báo cáo đã có trên PowerShell 5.1 phát hiện ở lượt dùng thật ngày 29/10; regression tái hiện lỗi trước sửa và xác minh cập nhật/giữ bản cũ khi file khóa sau sửa.
- [x] Truyền report mode xuyên suốt UI → prompt/skill → script; chế độ không tạo HTML thực sự không ghi HTML.
- [x] Phân biệt Windows edition/channel và tình trạng hỗ trợ; không suy toàn bộ từ build number.
- [x] Đã triển khai xác minh Restore Point mới bằng sequence/time và hoàn nguyên registry, kiểm thử bằng giả lập; phần dịch vụ thật trên VM chưa xác minh.

Nghiệm thu: fixture D-system/C-data chọn đúng ổ; thiếu collector hiện unknown; VM và dữ liệu chat không thành rác; bảng đo không hứa giải phóng cả folder; các tham số nhận được giống đầu vào; JSON lỗi tạo thông báo có ích; VM snapshot xác nhận Restore Point mới và trạng thái registry sau lỗi.

## 3. Có một nguồn và một cổng kiểm chứng phát hành

Xử lý F11–F12 và giảm các bản sao phải sửa bằng tay.

- [x] Chuyển script/report/CSS dùng chung về một nguồn rồi đóng gói vào từng edition; giữ đầu ra HTML/ZIP tự chứa để mở offline.
- [x] Dùng chung chính sách an toàn giữa prompt-only và skill; phân biệt rõ adapter thực thi của từng kênh, không để agent tự suy ra hai cách phục hồi khác nhau.
- [x] Installer xác minh bản mới trong staging, cập nhật có rollback và không làm mất bản cũ khi copy lỗi.
- [x] Build theo allowlist; từ chối file ngoài dự kiến, kiểm tra không có bí mật, tạo checksum và danh sách file phát hành.
- [x] Thêm regression tests từ các ca lỗi trong báo cáo, cùng kiểm tra BOM/PowerShell 5.1, EN/VI parity, ZIP nhúng, appendix extraction, liên kết và build tái lập.
- [x] Đưa các kiểm tra vào CI; kiểm thử có đặc quyền nằm ở luồng VM riêng, không chạy trên profile thật hoặc runner có dữ liệu cá nhân.

Nghiệm thu: mỗi nguồn dùng chung chỉ sửa một lần; build từ clone sạch không tạo diff; thêm `.env` hoặc log vào thư mục nguồn không lọt vào ZIP; cập nhật lỗi vẫn giữ skill trước đó; mỗi regression test phải chứng minh đã thất bại trên hành vi cũ và đạt sau sửa.

## 4. Hoàn thiện trải nghiệm và khả năng sử dụng lâu dài

Xử lý F15 và các đề xuất UX sau khi luồng dữ liệu đã đúng.

- [x] Hoàn thiện tab semantics và keyboard navigation; keyboard và accessibility tree đã kiểm tra; screen reader, zoom/reduced-motion hệ thống và ma trận người dùng còn cần nghiệm thu riêng.
- [x] Hiển thị rõ khoản nào là cache, dữ liệu cá nhân, dữ liệu ứng dụng hoặc chỉ có thể di chuyển; giải thích căn cứ, lợi ích và cách quay lại của từng item.
- [x] Bổ sung xem lịch sử phiên, resume, khôi phục từng item và xuất báo cáo đã che dữ liệu riêng để người dùng chủ động chia sẻ.
- [x] Đã giới hạn số hạt, dừng vẽ khi không nhìn thấy và thêm nút tắt; benchmark CPU trên máy yếu chưa được xác minh.
- [x] Kiểm tra mobile xem người mới có tìm được hành động đầu tiên trước khi phải đọc hoặc cuộn nhiều; giữ lựa chọn nâng cao ở chỗ ít gây phân tán.
- [x] Sửa các lời hứa tuyệt đối về rollback/privacy và công bố ma trận môi trường, agent, phiên bản đã kiểm chứng.

Nghiệm thu: người dùng biết cái gì chưa đo được, có thể duyệt một item và khôi phục nó mà không phải nhớ đường dẫn; trợ năng được kiểm thử thực tế; báo cáo không tạo tải nền đáng kể khi không được xem; mọi lời hứa công khai có phạm vi và bằng chứng.

## Cổng trước khi coi là bản ổn định

- [ ] Không còn lỗi P1 và các ca hồi quy tương ứng đạt.
- [x] Phục hồi thành công trên dữ liệu fixture sau mô phỏng lỗi ghi journal/hết dung lượng, lỗi quyền, file khóa thật, xung đột tên và ngắt giữa chừng; đây không phải bằng chứng nghiệm thu dịch vụ hệ thống trên VM.
- [ ] Đã thử Windows 10/11, x64/ARM64 và các edition được tuyên bố hỗ trợ; nhánh chưa thử phải ghi là chưa xác minh.
- [ ] Luồng agent từ kiểm tra đến duyệt, dry run, thực thi, dừng và hoàn tác đã được chạy trên VM có snapshot và dữ liệu fixture.
- [ ] Đã kiểm tra filesystem/cloud với thư mục chuyển hướng, junction, đường dẫn dài/Unicode và cloud placeholders mà không tải hoặc xóa ngoài ý muốn.
- [x] Gói phát triển, nguồn, tài liệu và checksum khớp nhau; CI trên Windows đạt ở commit triển khai `4680f1e`. Đây chưa phải gói phát hành ổn định.

Chưa lên lịch triển khai desktop wrapper, backend, tài khoản, telemetry hoặc tự động dọn định kỳ. Chỉ mở các hạng mục này khi có nhu cầu cụ thể sau khi đạt các cổng an toàn; không dùng chúng để thay thế việc sửa lỗi hiện có.

## Giới hạn được chủ dự án xác nhận

Chủ dự án xác nhận chưa có VM và chọn giữ kiểm chứng VM ở trạng thái chưa xác minh. Các checkbox triển khai không đồng nghĩa tất cả cổng ổn định đã đạt. Không chạy thao tác hệ thống thật trên máy cá nhân để thay thế phép thử VM.
