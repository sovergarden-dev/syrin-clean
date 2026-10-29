# Syrin clean: kiểm tra an toàn và hướng nâng cấp

Status: amended 2026-10-28

Ưu tiên của dự án là làm chắc cơ chế cách ly, khôi phục và số liệu dùng để ra quyết định. Bản 3.6 có thể build và sử dụng giao diện, nhưng các lỗi dưới đây khiến tôi chưa khuyên xem chức năng dọn dẹp là bản ổn định dành cho người dùng phổ thông.

## Thời điểm

Ngày 2026-10-28, múi giờ Asia/Bangkok. Baseline: [`a0752aac632ef3f378e8020cd1f0480c759dadb6`](https://github.com/sovergarden-dev/syrin-clean/tree/a0752aac632ef3f378e8020cd1f0480c759dadb6); mọi số dòng trong báo cáo ứng với commit này. Phạm vi khóa bằng `git ls-files`: 52 file đã theo dõi, gồm nguồn, bản sinh, gói ZIP và tài liệu. Hai ảnh và tài liệu lịch sử là tài nguyên tham khảo, không phải mã thực thi được kiểm thử.

## Mục đích

Yêu cầu: “kiểm tra thật kỹ dự án và còn có đề xuất gì để chỉnh sửa, bổ sung, nâng cấp dự án nữa không? tôi không gấp muốn hoàn hảo nhất có thể”. Đây là lượt đánh giá và đề xuất; không sửa runtime, không commit, không push và không triển khai website.

Chuỗi mục tiêu: tìm lỗi và điểm yếu → làm cho thao tác và báo cáo đáng tin → giúp người không chuyên cải thiện máy mà vẫn kiểm soát được dữ liệu. Không coi số lượng tính năng hoặc hiệu ứng là tiêu chí hoàn tất.

## Cách kiểm tra

- Đọc nguồn theo luồng: cài đặt → kiểm tra → đề xuất/duyệt → cách ly/khôi phục/xóa → báo cáo; đối chiếu prompt đầy đủ với skill.
- Tách một bản sao của commit để build và thử lỗi. Fixture dùng dữ liệu tổng hợp; không chạy kiểm tra toàn bộ máy, không tạo Restore Point thật và không nâng quyền.
- Chạy Windows PowerShell 5.1.19041.6456. Với thao tác nguy hiểm, thay đúng biên I/O bằng hàm ghi nhận lời gọi; không thực hiện xóa, di chuyển dữ liệu thật hay sửa registry. Trường hợp xung đột khi khôi phục dùng file thật do phép thử tự tạo.
- Chạy JavaScript phần dữ liệu báo cáo bằng Node với DOM giả lập. Mở trang HTML thật bằng trình duyệt thông qua server loopback chỉ cho phép hai file HTML công khai; không cấp quyền truy cập tùy ý vào filesystem.
- Đối chiếu các hành vi Windows và ngữ nghĩa tab với nguồn chính thức. Phân biệt quan sát đã tái hiện, kết luận từ luồng mã và đề xuất cần kiểm chứng thêm.

## Các bước đã thực hiện

- [x] Khóa baseline và kiểm tra detector trước khi kết luận.
- [x] Đọc sáu script độc lập, builder, dữ liệu prompt, report template và hai trang HTML.
- [x] Tái hiện lỗi khôi phục, phạm vi xóa, ghi journal, cloud path, collector, Startup, truyền tham số, cài đặt và báo cáo.
- [x] Build từ bản sao và so sánh sáu thành phẩm; thử ranh giới đóng gói bằng file `.env` tổng hợp.
- [x] Kiểm tra responsive, tạo hồ sơ, đặt lại, mở nội dung và tải ZIP/Markdown thật.
- [x] Rà soát sự lặp lại, chênh lệch tài liệu và các lời hứa chưa được mã thực thi bảo đảm.
- [x] Lập kế hoạch sửa theo rủi ro và điều kiện nghiệm thu, không triển khai thay đổi.

## Kết quả đã xác nhận

Có **15 nhóm phát hiện: 5 P1, 9 P2, 1 P3**. P1 cần xử lý trước khi dùng rộng rãi thao tác dọn trên dữ liệu thật; P2 ảnh hưởng tính đúng, độ tin cậy hoặc khả năng phát hành; P3 là thiếu sót giao diện hỗ trợ truy cập. Đây là mức ưu tiên của đánh giá, không phải số liệu về tần suất lỗi ngoài thực tế. Không nhân đôi số lượng vì cùng lỗi có trong cả EN và VI.

| Mã | Mức | Phát hiện và bằng chứng | Hướng xử lý |
|---|---|---|---|
| F01 | P1 | `quarantine.ps1:27` xóa đệ quy toàn bộ `QuarantineRoot` khi tìm thấy `manifest.csv`. Fixture có một file được ghi nhận và một file không liên quan; lời gọi xóa được ghi nhận nhắm vào cả thư mục. Lệnh xóa đã được giả lập, không có dữ liệu bị xóa trong phép thử. | Xóa đúng các item đã duyệt trong manifest của phiên; kiểm tra quyền sở hữu root, đường dẫn và nội dung còn lại; không xóa cả root như bước mặc định. |
| F02 | P1 | `quarantine.ps1:18` bỏ qua item nếu đường dẫn gốc đã có file, nhưng dòng 24 vẫn đổi tên manifest sang trạng thái đã khôi phục. Phép thử thật: `SKIP`, file cũ vẫn ở khu cách ly, `manifest.csv` mất, lần `-Restore` tiếp theo không xử lý gì. | Giữ các item chưa hoàn thành trong journal đang hoạt động, ghi trạng thái xung đột và cho người dùng chọn tên đích hoặc bỏ qua có thể thử lại. |
| F03 | P1 | `quarantine.ps1:48` phát lệnh di chuyển trước khi ghi manifest ở dòng 50. Khi giả lập lỗi ghi manifest, thứ tự vẫn là `move → manifest failure`; không có bước khôi phục vị trí cũ. Cùng phép thử xác nhận `-Apply -QuarantineRoot <custom>` bỏ qua root đã truyền và vẫn chọn root ở đầu ổ. | Một thao tác có journal ghi trước, trạng thái rõ và phục hồi khi lỗi; thống nhất root cho apply/restore/purge; trả kết quả có cấu trúc và mã thoát thất bại. |
| F04 | P1 | `quarantine.ps1:39` chỉ kiểm tra `StartsWith` theo chuỗi. Thư mục cha chứa OneDrive vẫn được cho qua; thư mục anh em tên `OneDriveBackup` lại bị coi là OneDrive. Phép thử dùng preview, không di chuyển dữ liệu cloud. | So đường dẫn theo ranh giới thư mục, kiểm tra cả tổ tiên/hậu duệ và reparse point; không dựa vào tiền tố tên để xác định dữ liệu đồng bộ. |
| F05 | P1 | `audit.ps1:158` đo cả thư mục dữ liệu ứng dụng và dòng 165 đo VHDX. `report-template.html:117` chỉ nhận diện dữ liệu cá nhân bằng một regex trên nhãn. Fixture Telegram 3 GB + Zalo 2 GB + Docker VHDX 5 GB được hiện thành **10 GB rác/cache, không tính dữ liệu cá nhân**. | Phân loại bằng dữ liệu có kiểu: cache, app data, user data, VM, system; dung lượng đo được và dung lượng có thể thu hồi phải là hai đại lượng khác nhau. |
| F06 | P2 | `audit.ps1:9` bỏ qua lỗi trên toàn script; `Get-SafeSize` nuốt exception ở dòng 48. Khi giả lập Access Denied, kết quả là `GB=0, Complete=true`. Report dòng 133–137 còn biến collector thiếu thành “0 startup”, “0 lỗi” màu xanh. | Collector phải trả trạng thái complete/partial/unavailable/failed, lỗi và nguồn đo. Dữ liệu thiếu hiển thị “chưa đo được”, không thành số 0. |
| F07 | P2 | `report-template.html:115` luôn ưu tiên ổ C; audit không xuất định danh ổ hệ thống trong metadata. Fixture mô tả Windows trên D, D còn 1%, C còn 60%; report chọn C và hiện trạng thái tốt. | Audit xuất `systemDrive`/volume ID; report dùng đúng định danh và tách số liệu theo ổ. Không suy luận ổ hệ thống từ thư mục lưu báo cáo. |
| F08 | P2 | `audit.ps1:115` lưu trạng thái StartupApproved chỉ theo tên. Với `DemoApp` ở HKCU bật và HKLM tắt, fixture nhận được **cả hai đều tắt** ở dòng 124. | Khóa định danh gồm hive, nhánh/kiến trúc và tên item; giữ trạng thái unknown khi không có bản ghi phù hợp. |
| F09 | P2 | `run-elevated.ps1:12` bọc đối số có khoảng trắng bằng dấu nháy mà không xử lý dấu `\` cuối. Chạy một tiến trình PowerShell thật, không nâng quyền, cho thấy `C:\Fixture Folder\` được nhận thành `C:\Fixture Folder" -Quiet ` và `Quiet=false`. | Truyền tham số theo giao thức không mất thông tin, hoặc dùng quy tắc quoting Windows đúng; bổ sung ca Unicode, dấu cách, dấu nháy, chuỗi rỗng và dấu `\` cuối. Phân biệt lỗi khởi chạy với UAC bị từ chối. |
| F10 | P2 | `make-report.ps1:11` đọc JSON thành chuỗi rồi chèn thẳng vào script ở dòng 24. Input `this is not JSON` vẫn tạo `report.html`; `node --check` trên script sinh ra trả 1. | Parse và kiểm tra schema trước khi render; báo lỗi dễ hiểu và không ghi đè báo cáo tốt trước đó bằng đầu ra lỗi. |
| F11 | P2 | `install.ps1:10` xóa bản skill đang cài trước khi copy bản mới. Phép thử lỗi copy ghi nhận thứ tự `remove old → copy failure`; các thao tác xóa/copy đều được giả lập. | Chuẩn bị và xác minh bản mới ở staging, thay bản cũ sau khi hoàn tất, giữ khả năng rollback; không mất bản đang chạy nếu cập nhật lỗi. |
| F12 | P2 | `tools/build.py:55` đóng gói mọi file dưới `skill/<lang>`, không có allowlist. Thêm `.env` không được Git theo dõi vào bản sao thử nghiệm rồi build: file đó xuất hiện trong ZIP. Đây là fixture không có bí mật; không kết luận repo hiện đã lộ credential. | Đóng gói theo allowlist, kiểm tra file bất thường và bí mật trước khi tạo artifact; manifest kiểm chứng nội dung và checksum. |
| F13 | P2 | Web EN dòng 755 và VI dòng 866 hứa “không tạo file báo cáo”, nhưng `audit.ps1:214` luôn ghi `audit-report.html` và không có tham số bỏ qua HTML. | Đưa report mode vào giao diện script và kiểm thử xuyên suốt UI → prompt → lệnh thực thi; giữ đúng nghĩa của tùy chọn người dùng chọn. |
| F14 | P2 | `audit.ps1:59` gắn nhãn mọi Windows 10 là hết hỗ trợ từ 14/10/2025. Windows 10 Enterprise LTSC 2021 vẫn có thời hạn hỗ trợ trong năm 2027 theo Microsoft, nên nhánh này không đúng cho phạm vi Enterprise đang quảng bá. | Tách tên OS khỏi tình trạng hỗ trợ; xác định edition/channel/ESU và ghi unknown khi chưa xác minh, không đưa lời khuyên nâng cấp từ một điều kiện build duy nhất. |
| F15 | P3 | Web EN dòng 454 và VI dòng 453 dùng `role=tablist`, nhưng các nút con thiếu `role=tab`, `aria-selected`, `aria-controls`; kiểm tra DOM thật trả null cho cả ba. | Hoàn thiện tab/tabpanel, trạng thái chọn và phím mũi tên theo WAI-ARIA, kiểm tra bằng bàn phím và screen reader. |

### Vị trí nguồn

Các vị trí trên dùng bản EN làm đại diện cho script/template chung; đã xác minh cả năm cặp script và report template EN/VI giống byte. Lỗi audit và report còn được nhúng vào hai prompt Markdown và hai trang HTML; các gói ZIP phải được sinh lại sau khi sửa. Một sửa ở file sinh sẽ bị lần build sau ghi đè.

- [Quarantine](../../skill/en/syrin-clean/scripts/quarantine.ps1), [audit](../../skill/en/syrin-clean/scripts/audit.ps1), [elevation](../../skill/en/syrin-clean/scripts/run-elevated.ps1).
- [Report builder](../../skill/en/syrin-clean/scripts/make-report.ps1), [report template](../../skill/en/syrin-clean/assets/report-template.html), [installer](../../skill/en/install.ps1), [build](../../tools/build.py).
- [Web EN](../../web/syrin-clean-en-v3.6.html), [web VI](../../web/syrin-clean-vi-v3.6.html).

### Bằng chứng và giới hạn kiểm chứng

[Kết quả máy đọc được](audit-evidence.json) lưu kết quả probe; đường dẫn tạm đã thay bằng `<scratch>`. Bằng chứng giả lập chỉ chứng minh luồng của mã khi dependency trả kết quả đó, không chứng minh Windows, OneDrive hoặc System Restore thật đã thực hiện hành vi tương ứng.

| Phép kiểm | Kết quả |
|---|---|
| Cú pháp Windows PowerShell 5.1 | 12 script, 0 lỗi parse. Không tương đương việc các thao tác hệ thống đều an toàn. |
| JavaScript nguồn đang dùng | Kiểm tra cả script ở hai landing page và hai report template. |
| Build baseline trong bản sao | Exit 0; sáu thành phẩm giống byte trước và sau build. |
| File tải qua nút trên trình duyệt | ZIP EN khớp byte; Markdown EN khớp nội dung sau chuẩn hóa newline. |
| Bố cục mặc định EN và VI | 12 trường hợp: 320, 390, 768, 1366, 1920, 2560 px cho mỗi ngôn ngữ; không tràn ngang, self-check không báo lỗi. |
| Nội dung mở rộng | EN mở 7 mục và full prompt ở 390/768/1366 px: không lỗi self-check. VI mở 7 mục và full prompt ở viewport 668×580: không lỗi self-check. |
| Luồng giao diện | Audit-only đổi đúng mode; role/note/report cập nhật prompt; reset xóa ghi chú và về mặc định; chuyển tab và tải file hoạt động. |
| Detector format | 18 dòng cảnh báo WRAP; chủ yếu là các dòng badge, nhãn và mục prompt có cấu trúc. Không tính chúng thành 18 lỗi sản phẩm. |
| Suite/CI/typecheck | Không có suite tự động hay workflow CI trong baseline. Không có dự án typed-language để chạy typecheck. |

Phép kiểm browser VI mở rộng ở hai kích thước định trước bị gián đoạn bởi công cụ; không lấy lượt đó làm bằng chứng đã đạt. Đã quan sát lại trạng thái mở rộng ở 668×580, khôi phục viewport và đóng tab. Server preview đã dừng. Chưa kiểm thử screen reader, forced WebGL fallback, hiệu năng trên máy yếu, hoạt động agent tích hợp hay toàn bộ ma trận Windows 10/11, x64/ARM64, Admin/non-Admin. Không chạy cleanup thật, khôi phục hệ thống thật, DISM, registry mutation hoặc thử xóa cloud trên máy người dùng.

Bản sao nguồn, script probe và fixture còn trong thư mục Temp riêng để tái hiện; không được đưa vào repo. Hai file tải qua trình duyệt ở Downloads. Không tuyên bố phép thử đã xóa hết mọi file tạm; các kết quả cần lưu lâu dài nằm trong JSON bằng chứng đã chuẩn hóa đường dẫn.

### Các nghi vấn không tính là lỗi

- GUID Downloads đã đối chiếu bằng máy và đúng; không kết luận từ cách GUID được hiển thị trong đầu ra công cụ.
- “Freed” bị chặn ở 0 khi dung lượng trống giảm, nhưng bảng trước/sau vẫn hiện 70 → 60 GB. Đây không được tính là một lỗi độc lập; có thể cải thiện cách diễn đạt delta sau này.
- Tài liệu lịch sử v2.0 có tên cũ là có chủ đích; không đề xuất xóa nguồn gốc chỉ để đạt kết quả tìm kiếm sạch.
- HTML tự chứa và WebGL/Canvas fallback phục vụ dùng offline; không đề xuất bỏ chúng chỉ để giảm số dòng.

## Đề xuất kiến trúc và sản phẩm

Các mục dưới đây là đề xuất, không cộng vào 15 phát hiện đã xác nhận.

1. **Một kế hoạch thao tác có định danh.** Agent tạo danh sách hành động, tham số, bằng chứng và cách hoàn tác; runtime kiểm tra precondition, phạm vi và đúng các item đã duyệt. Ghi journal theo phiên và theo item. Mục tiêu là giảm lệnh nguy hiểm do agent tự viết và lỗi mở rộng phạm vi. Một file approval do chính agent có quyền ghi không chứng minh được sự đồng ý của con người trước một agent có toàn quyền shell; phải mô tả đúng giới hạn này.
2. **Một mô hình dữ liệu có phiên bản.** Audit nên có `schemaVersion`, `sessionId`, định danh ổ hệ thống, trạng thái từng collector, lỗi, giới hạn đo và phân loại dữ liệu. Đề xuất chứa `measuredBytes`, `estimatedReclaimableBytes`, mức rủi ro và trạng thái hoàn tác. Report đọc mô hình đó thay cho suy đoán từ nhãn hiển thị.
3. **Một nguồn cho phần dùng chung.** Năm script và report template hiện có hai bản giống byte; CSS hai landing page giống nhau, tổng 25.506 byte mỗi bản. Có thể giữ nguồn chung trong `src/`, rồi build thành hai gói tự chứa. Prompt và skill dùng chung các khối chính sách, có phần adapter rõ cho mỗi cách sử dụng. Hiện prompt đầy đủ cho phép Recycle Bin ở `src/prompt-template.en.txt:37`, trong khi skill dùng helper quarantine ở `SKILL.md:65`; hai kênh cần cùng tiêu chuẩn nghiệm thu về mất dữ liệu, xung đột và rollback.
4. **Xác minh Restore Point mạnh hơn.** Helper hiện chỉ tìm theo Description. Khi stub không tạo điểm mới nhưng trả lại điểm cũ trùng tên, nó báo `Created=true`. Cần đối chiếu sequence/time trước và sau, kết quả API và tình trạng hoàn nguyên registry. Chưa tái hiện tình huống này trên dịch vụ System Restore thật, nên đây là đề xuất hardening có điều kiện, không phải bằng chứng rằng Windows đã tạo điểm giả.
5. **Kiểm thử liên tục từ những ca lỗi thật.** Đưa các ca F01–F14 thành regression tests có fixture riêng, kiểm tra checksum/bản nhúng/link/locale và build tái lập trong CI Windows. Thử thao tác có đặc quyền trên VM snapshot; không dùng dữ liệu cá nhân làm fixture. Ma trận hỗ trợ công bố phải phản ánh môi trường đã thử.
6. **Báo cáo giúp ra quyết định.** Hiện dung lượng cache, dữ liệu cá nhân, dữ liệu ứng dụng và VM thành nhóm riêng; hiển thị “chưa đo được” và “đo chưa hết”; có bản so sánh theo phiên và lệnh khôi phục theo item. Thêm bản xuất đã che username, đường dẫn riêng, tên ứng dụng nhạy cảm để người dùng tự chia sẻ khi cần.
7. **Hiệu năng giao diện theo dữ liệu đo.** Report Canvas có vòng vẽ riêng, chưa có cơ chế dừng khi phần biểu đồ ra ngoài viewport như landing page. Nên đo chi phí CPU trên máy yếu rồi thêm pause/quality budget và nút tắt hiệu ứng. Trên mobile, cân nhắc đặt lời giới thiệu và nút bắt đầu trước cảnh 3D; xác minh bằng số bước và khả năng tìm hành động chính, không chỉ bằng cảm nhận đẹp.
8. **Lời hứa và quyền riêng tư chính xác.** Tránh “100% reversible”, “luôn có đường quay lại” cho mọi thao tác khi có ResetBase, purge và lỗi phục hồi. Phân biệt script không upload dữ liệu với cách agent/provider xử lý đầu ra terminal; không có cơ sở để hứa toàn bộ phiên làm việc luôn nằm trên máy. Tuyên bố tương thích agent và tiết kiệm token nên gắn với phiên bản và phép đo cụ thể.

Đích đầu tiên hợp lý là một CLI/skill có runtime xác định, báo cáo trung thực và bộ kiểm thử tốt. Chưa có bằng chứng cần đổi sang ứng dụng desktop nặng, thêm backend, tài khoản, telemetry hoặc tối ưu tự động theo lịch. Các hướng đó chỉ nên mở lại khi nền an toàn đã đạt và có nhu cầu sử dụng cụ thể; tác vụ định kỳ nếu có nên bắt đầu ở chế độ kiểm tra chỉ đọc.

## Đối chiếu nguồn chính thức

- [Microsoft: Checkpoint-Computer](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer?view=powershell-5.1) xác nhận đây là lệnh tạo điểm khôi phục, không trả output và có giới hạn tần suất. Đề xuất kiểm tra sequence/time là suy luận thiết kế từ hợp đồng đó và probe của dự án; không coi một dòng stdout là chứng minh điểm mới tồn tại.
- [Microsoft: File Attribute Constants](https://learn.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants) mô tả reparse point và các cờ recall cho cả file/thư mục; việc đọc hoặc enumerate đối tượng recall có thể kéo dữ liệu từ xa. Điều này cần nằm trong bộ kiểm thử filesystem/cloud, không chỉ so tên thư mục.
- [Microsoft: Windows 10 Enterprise LTSC 2021](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-enterprise-ltsc-2021) công bố thời hạn hỗ trợ đến năm 2027, là phản ví dụ trực tiếp cho nhãn blanket tại F14.
- [W3C: Tabs Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/tabs/) quy định quan hệ tablist/tab/tabpanel, aria-selected/aria-controls và hành vi phím, dùng để đối chiếu F15. Chưa tuyên bố đạt WCAG từ việc sửa riêng widget này.

## Quyết định

**Action:** đề xuất thực hiện [kế hoạch hardening](../plan/hardening.md), ưu tiên các điều kiện có thể làm mất dữ liệu trước. Cập nhật mục lục để tìm được kết quả; không đổi mã thực thi hay các artifact công khai trong lượt audit này.

**Phản biện hướng đề xuất:** giữ toolkit nhẹ hiện tại giúp dễ dùng, ít dependency và dễ mở offline. Thêm runtime sẽ thất bại nếu chỉ trở thành một lớp bọc vẫn gọi lệnh tùy ý hoặc một hệ thống plugin quá lớn. Vì vậy bắt đầu từ quarantine/journal, định danh dữ liệu và một số hành động đã kiểm thử; mở rộng theo ca sử dụng, không xây nền tảng chung trước.

**Định cỡ kiểm soát:** người có thể gặp lỗi là người gọi helper trên file họ có quyền thao tác; chưa có số liệu về số người dùng hoặc tần suất. Xung đột tên, lỗi ghi đĩa và truyền nhầm thư mục là điều kiện sử dụng thông thường, không cần kẻ tấn công hoặc động cơ lạm dụng. Tác động có thể là xóa dữ liệu không phục hồi, nên kiểm tra một lần tại biên filesystem và journal có giá trị dù chưa biết tần suất; không cần thêm backend hay xác thực mạng để xử lý những lỗi này.

**Reopen:** nếu mục tiêu chuyển thành ứng dụng desktop độc lập hoặc đối tượng sử dụng khác, đánh giá lại UX và kiến trúc. Tần suất gặp các lỗi trên ngoài thực tế chưa được đo; mức ưu tiên P1 dựa vào khả năng mất dữ liệu không thể phục hồi, không dựa vào số người dùng ước đoán.

## Amendments

- 2026-10-28: chủ dự án đồng ý triển khai kế hoạch; kết quả và giới hạn kiểm chứng được ghi riêng trong [hardening validation](hardening-validation.md). Các phát hiện phía trên vẫn mô tả baseline `a0752aa`, không được viết lại thành lịch sử đã sạch.
