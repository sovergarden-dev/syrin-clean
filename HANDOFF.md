# Syrin clean: bàn giao

## Bản 4.1.0-preview.2

Ngày 2026-11-18: chuẩn bị và phát hành `4.1.0-preview.2` dưới dạng pre-release sau lượt kiểm tra zero-trust và nâng cấp `P0` đến `P3` ([biên bản audit](docs/research/audit-perfection.md), [kế hoạch đã hoàn tất](docs/plan/done/perfection-upgrade.md)). Bổ sung duyệt file native C# `CollectPlanFiles` (hạ thời gian lập kế hoạch fixture 2.048 file từ 111.344 ms xuống ~3,4 giây), nhóm thư mục tất định `G1..Gn`, biên nhận phê duyệt gọn nhẹ, các bộ thu thập `hotspots` / `devArtifacts` / `Downloads`, nút tạo yêu cầu xóa hẳn (`#purge-request`), cài đặt đa agent (`-IncludeDetectedAgents`), nhánh xử lý `elevation-unsupported` trong môi trường sandbox, chẩn đoán Android tùy chọn (`thermal`, `appSizes`, cửa sổ hai mốc `gfxinfo`) và siêu dữ liệu SEO/JSON-LD cùng `og-preview.png`, `robots.txt`, `sitemap.xml` trên GitHub Pages.

## Bản 4.1.0-preview.1

Ngày 2026-11-14: đã phát hành `4.1.0-preview.1` dưới dạng pre-release sau khi [PR #6](https://github.com/sovergarden-dev/syrin-clean/pull/6) merge. Tag trỏ tới `217669768a33250fd135f2ec9e2816fef0ffefde`; tám asset tải lại khớp SHA-256 và đều xác minh được chứng thực gắn với đúng repo, workflow, commit và tag. Hai HTML trên Pages khớp asset. Xem [bằng chứng phát hành](docs/research/device-release-verification.md), [kế hoạch](docs/plan/device-support.md) và [phạm vi](docs/feat/devices.md). Gói ZIP tham khảo không được chạy, nhập dữ liệu riêng vào repo hay coi là quyền thao tác điện thoại. Các bản cài toàn cục và asset của preview 2 giữ nguyên.

Kiểm chứng ứng viên: [bản ghi](docs/research/device-validation.md) và [lượt Android thật](docs/research/android-live-validation.md). Một điện thoại Android 14 đã hoàn tất kiểm tra chỉ đọc sáu bộ thu thập sau khi người dùng duyệt USB debugging. Đã sửa lỗi chọn Python khi PATH có nhiều kết quả, ADB chưa có server và nhận dạng bind mount dữ liệu. Raw audit, package inventory, serial và báo cáo thật giữ riêng ngoài repo. Các OEM khác, kiểm tra frame thật, VM và trợ năng đầy đủ vẫn mở. Các thay đổi đã được commit và hợp nhất cập nhật demo/hỏi đáp từ main; không có tác vụ dọn điện thoại tự động chờ chạy.

Kiểm thử chốt ngày 2026-11-14: 83 đầu ra khớp nguồn, kiểm thử Node, 21 ca cách ly, 16 nhóm runtime và 25 ca Python đều đạt, gồm regression liên kết tài liệu trong ZIP. Lượt cuối lập kế hoạch 2.048 file trong 111.344 ms, xác minh 12 phiên và 4.098 event ở phiên dày. Giới hạn 120 giây và kiểm tra đường dẫn/định danh vẫn giữ nguyên; lượt trước 35.741 ms cho thấy tải máy có biến động, chưa phải benchmark có kiểm soát. Thêm `-Check`, hướng dẫn kết nối và mô tả app/tác vụ; frame thiếu mốc là partial, frame mang tên app khác bị loại. Đã kiểm tra EN/VI, bàn phím và 320 px trước phát hành; trên trang live đã thử dữ liệu Android qua EN/VI hai chiều, ZIP tải thật và bộ lọc báo cáo. Các cổng VM, OEM khác, frame trên tác vụ thật và trợ năng đầy đủ vẫn mở; chưa công bố bản ổn định.

Chủ máy chọn giữ nguyên nhóm cache đã được trình duyệt và không có app/tác vụ ưu tiên. Không có thao tác xóa cache, gỡ app, đổi settings hay tối ưu điện thoại được thực hiện. Server web kiểm thử và ADB server của lượt phần cứng đã đóng; không dừng ứng dụng khác. CI trên nhánh, PR, main, tag và quy trình Pages đều đạt. Quy trình phát hành không thay skill toàn cục.

## Bản phát hành trước

Trạng thái: 4.0.0-preview.2 đã được phát hành với GitHub Pages và HTML offline sau khi PR #4 merge. Tag trỏ tới `3e3dcf1`; tám asset, hai HTML công khai và bản ZIP tải qua giao diện đã được đối chiếu checksum. Các asset của preview trước giữ nguyên. Đây vẫn là pre-release; các cổng VM/môi trường chưa đạt không bị đóng thay.

## Nguồn chuẩn

- project.json: phiên bản, kênh và địa chỉ công khai.
- src/runtime và src/instructions: runtime và chính sách dùng chung; không sửa trực tiếp bản sinh.
- src/shared: token, font có giấy phép và renderer có giới hạn tải.
- src/web: một template EN/VI, module và dữ liệu ngôn ngữ/hồ sơ.
- src/report: mô hình dữ liệu, báo cáo song ngữ và dữ liệu minh họa được ghi rõ.
- tools/build.py: sinh package, prompt, HTML, manifest và checksum.
- tools/publish_site.py: chỉ đưa hai HTML công khai, `og-preview.png`, `robots.txt`, `sitemap.xml` cùng metadata vào thư mục Pages rỗng, ngoài checkout.

## Những gì phải giữ

Thực thi file dùng cùng một bản kế hoạch cho digest, nội dung và dữ liệu lưu trong phiên. ID được chọn, định danh handle, quyền sở hữu root, journal và kiểm tra đường dẫn vẫn bắt buộc. Báo cáo tạo yêu cầu cho agent; nó không thực thi thao tác Windows. Xóa hẳn là kế hoạch riêng và không hoàn tác được.

Trang mở mặc định English; lựa chọn ngôn ngữ của người dùng được giữ. Đổi EN/VI không làm mất hồ sơ, tab hay lựa chọn file. Bản ghi gốc giữ ngôn ngữ nguồn. Dữ liệu chưa biết/chưa đầy đủ vẫn được ghi đúng, không chuyển thành 0 tốt.

Báo cáo thật, journal, đường dẫn máy và backup registry chỉ ở ngoài repository. Pages chỉ có trang chính và báo cáo giả lập. Không dùng báo cáo thật làm ví dụ công khai.

## Kiểm chứng và phát hành

Lệnh chuẩn: python -B -X utf8 tools/build.py, rồi powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1. Các kiểm thử dùng fixture riêng; Restore Point giả lập không chứng nhận dịch vụ thật.

Validate chạy trên Windows. Pages chỉ triển khai tag của bản phát hành đã công bố. Windows kiểm tra và đóng gói thư mục site theo allowlist; Linux nhận artifact, đối chiếu checksum với Release rồi triển khai. Bản phát hành tải lên các artifact được chọn rõ, có checksum; không phát hành nội dung thư mục làm việc.

[Bằng chứng hardening](docs/research/hardening-validation.md), [kiểm chứng giao diện](docs/research/bilingual-validation.md), [kế hoạch phát hành](docs/plan/done/bilingual-experience.md) và [ma trận hỗ trợ](docs/feat/support.md) phân biệt việc đã làm với giới hạn còn mở.

[Mở trang web](https://sovergarden-dev.github.io/syrin-clean/) · [Release hiện tại](https://github.com/sovergarden-dev/syrin-clean/releases/tag/4.1.0-preview.2) · [Triển khai 4.1.0-preview.1 trước đó](https://github.com/sovergarden-dev/syrin-clean/actions/runs/43585731937).

## Khi tiếp tục

Tối ưu đọc journal, tiến độ báo cáo và sửa ngữ nghĩa nút chuyển động đã nằm trong preview 2. Hai lượt đo tuần tự trên 18.840 event giảm trung bình khoảng 41% thời gian; lịch sử đầu ra khớp hoàn toàn. Hai bản skill tiếng Việt trên máy đã được cập nhật qua installer có backup; bản vừa cài tạo lại báo cáo đủ 37 phiên/4.710 item, không lỗi lịch sử và giữ nguyên audit gốc. Xem [phép đo](docs/research/journal-validation.md), [kiểm chứng giao diện](docs/research/html-interaction-validation.md) và [bằng chứng phát hành](docs/research/preview-two-verification.md). Raw log, báo cáo máy và định danh backup vẫn ở ngoài repository. Commit ghi chép sau phát hành trên main không thay đổi tag hay các asset đã công bố.

Chủ dự án chưa có VM và đã chọn giữ kiểm chứng VM ở trạng thái chưa xác minh. Không thay phép thử VM bằng thao tác hệ thống thật trên workstation. System Restore, nền tảng/filesystem/provider chưa thử và trợ năng đầy đủ phải có bằng chứng trước khi nâng mức công bố hỗ trợ hoặc gọi bản ổn định.

Chưa có yêu cầu tạo tài khoản/backend, telemetry, dọn tự động định kỳ hoặc thêm adapter tối ưu hệ thống. Ưu tiên chất lượng luồng đã có và dữ liệu kiểm chứng trước khi mở rộng phạm vi.
