# Syrin clean: ghi chú bàn giao

Tài liệu này để một người hoặc một AI agent khác tiếp tục dự án mà không cần đọc lại toàn bộ lịch sử trao đổi. Phiên bản hiện tại: **v3.6** (28/10/2026).

Tên dự án hiện tại: **Syrin clean**. Repo và mã skill: `syrin-clean`. Xem [kiến trúc](docs/arch/project.md) để phân biệt nguồn với file sinh tự động và cách tiếp tục phiên hoặc khôi phục khu cách ly mang tên cũ.

## 1. Mục tiêu và yêu cầu của chủ dự án

Yêu cầu gốc: *"viết 1 siêu cấp prompt để gửi AI agent trên máy, giúp kiểm tra kỹ, tối ưu máy Windows nhanh mượt hơn và list những thứ rác, ít sử dụng, nên dọn để tôi chọn giải phóng ổ đĩa, làm thật cẩn thận"*. Qua các vòng, chủ dự án chốt thêm:

- Dùng được cho **mọi cấu hình** Windows, không gắn với một máy cụ thể.
- **Tự động hoàn toàn**: người dùng không tự gõ lệnh, chỉ đọc báo cáo, duyệt và bấm Yes ở UAC.
- **Tiết kiệm quota/credits** của agent nhưng không giảm chất lượng.
- Bước duyệt phải **dễ hiểu với người không rành máy tính**.
- Đóng gói thành **Agent Skill** (file zip) để nạp trước rồi mở phiên mới.
- Trang HTML phải **ấn tượng, không “AI slop”**, có hiệu ứng 3D hợp chủ đề, không dùng phần mô phỏng/ví dụ giả, chạy đúng ở **mọi độ phân giải**.
- Báo cáo 3D dựng từ **dữ liệu thật**; tính năng tốn quota phải có tùy chọn, **mặc định bật** báo cáo 3D.
- Có bản **tiếng Anh**.
- Chủ dự án muốn "hoàn hảo nhất có thể", không gấp, và cho phép sửa thẳng vào file mà không hỏi lại.

## 2. Thành phẩm hiện có

| Thành phẩm | Vị trí | Ghi chú |
|---|---|---|
| Skill tiếng Việt | `skill/vi/`, `dist/syrin-clean-skill-v3.6-vi.zip` | Hướng dẫn tiếng Việt |
| Skill tiếng Anh | `skill/en/`, `dist/syrin-clean-skill-v3.6-en.zip` | Hướng dẫn tiếng Anh, trả lời theo ngôn ngữ người dùng, ước tính ít token hơn 25–35% |
| Trang web VI / EN | `web/` | Tự chứa (chỉ cần mạng để tải font), nhúng sẵn zip skill, prompt, mẫu báo cáo |
| Prompt .md VI / EN | `prompts/` | Dành cho agent không hỗ trợ skill; có Phụ lục A (audit), B (mẫu báo cáo), C (make-report) |
| Prompt gốc (nguồn) | `src/prompt-template.*.txt` | Có chỗ giữ `__CUSTOM_CONTEXT__` cho hồ sơ ưu tiên |
| Tài liệu gốc v2.0 và prompt thiết kế tham khảo | `docs/history/`, `docs/references/` | Để đối chiếu |

## 3. Kiến trúc

### 3.1 Prompt và skill

- **Một prompt gốc cho mỗi ngôn ngữ** (`src/`). Phần 0: vận hành tự động và tiết kiệm. Phần 1: 10 quy tắc an toàn cứng. Giai đoạn 0 (kiểm toán chỉ đọc), 1 (thích ứng, đề xuất, màn hình duyệt), 2 (thực thi, hoàn tác, báo cáo).
- **Skill** được cắt từ prompt gốc: `SKILL.md` giữ Phần 0 + Phần 1 (luôn cần), `references/stage0..2` giữ từng giai đoạn (nạp khi tới bước đó). Các đoạn khác với prompt: mục 4b/4f dùng script trong `scripts/`, quy tắc 6 dùng `quarantine.ps1`, quy tắc 7b dùng `new-restorepoint.ps1`.
- **Hồ sơ ưu tiên**: các dòng `->` do trang web tạo (vai trò máy, phạm vi, mức dọn, ngân sách, mức tự chủ, báo cáo, ổ đích, danh sách cấm, ghi chú). Với skill, chúng nằm trong câu mở đầu; với prompt, chúng thay chỗ `__CUSTOM_CONTEXT__`. Nội dung các dòng này nằm trong biến JS `roleSnippets`, `scopeSnippets`... của mỗi trang.
- **Prompt .md** nhúng ba phụ lục; agent trích ra bằng regex neo theo dòng tiêu đề `## ... APPENDIX-X-...` (đã kiểm tra không bắt nhầm khối mã).

### 3.2 Script (Windows PowerShell 5.1)

`audit.ps1` (chỉ đọc, `-OutDir`, `-Quiet`, ghi `audit.json` + `audit-report.html`), `run-elevated.ps1`, `new-restorepoint.ps1`, `quarantine.ps1`, `make-report.ps1` (`-Lang vi|en`, `-Template`, `-Baseline`). Quy ước: lưu UTF-8 có BOM, chuỗi trong code là ASCII, không dùng `Win32_Product`/`wmic`/counter tiếng Anh, không hard-code `C:`.

### 3.3 Báo cáo 3D

`assets/report-template.html` (song ngữ, chạy offline, Canvas 2D). `make-report.ps1` thay các chỗ giữ `/*__AUDIT__*/null`, `/*__BASELINE__*/null`, `/*__PROPOSALS__*/null`, `/*__LANG__*/'vi'` bằng dữ liệu thật (đã thoát `</`). Mỗi nhóm rác trong `radar` là một cụm hạt, kích thước theo GB; dữ liệu cá nhân màu vàng.

### 3.4 Trang web

- **Hướng thiết kế**: nền tối ám xanh, màu nhấn xanh ngọc `#34d399`, font Bricolage Grotesque + Be Vietnam Pro. Theo luật của taste-skill và impeccable: không gradient trang trí, không glassmorphism, không emoji làm icon, không đánh số 01/02, không nhãn nhỏ trên tiêu đề, không số liệu giả.
- **Cảnh 3D** (`#scene3d` WebGL + `#sceneOverlay` 2D): ~9.000 hạt trên máy tính, ~3.600 trên điện thoại, tự về Canvas 2D (1.500/650 hạt) nếu không có WebGL hoặc mất context, tự giảm số hạt nếu khung hình trung bình trên 26 ms. Tiến độ cuộn `P` nội suy theo tâm ba khối `.sb` (P = 0,2 / 0,52 / 1). Mốc thời gian: quét 0,03–0,34; gom cách ly 0,38–0,56; xoáy biến mất 0,56–0,76; xếp tầng từ dưới lên 0,57–0,98. Cùng một công thức có trong shader và trong hàm `particles2D`, sửa một chỗ phải sửa cả hai.
- **Chống chồng chữ**: cột lưới `minmax(0, 1fr)`, chữ lớn theo container query (`cqi`) và thuộc tính `data-fit` (JS tự thu nhỏ đến khi vừa), line-height ≥ 1,06 cho dấu tiếng Việt, dòng trạng thái nằm ngoài canvas. Mở trang với `?check` để có bảng liệt kê tràn khung, chồng chữ, chữ chạm cảnh 3D.
- **Hiệu ứng khác**: tiêu đề lật mở 3D khi cuộn, danh sách “Agent không bao giờ làm” lật lên rồi gạch đỏ theo từng dòng, khối nghiêng theo chuột, chữ cuối trang đổ khối 3D. Tôn trọng `prefers-reduced-motion`; nếu JS lỗi thì nội dung vẫn hiện sau 3 giây.
- **Nội dung nhúng trong JS** (do `tools/build.py` cập nhật): `basePromptTemplate`, `skillZipB64`, `skillZipEnB64`, `reportTpl`, `makeReportPs`, và khối `<pre id='auditCmds'>`.

## 4. Những quyết định quan trọng và lý do

- **Restore Point**: `-RestorePointType` không vượt được giới hạn 24 giờ; phải tạm đặt `SystemRestorePointCreationFrequency = 0`, tạo, trả lại giá trị cũ rồi xác minh.
- **Laptop**: không tắt Hibernate; `/type reduced` cũng bỏ chế độ ngủ đông nên chỉ là mục thận trọng.
- **Xóa mềm bằng khu cách ly**, không dùng Thùng rác trong skill: Thùng rác có thể bật hộp thoại làm treo agent hoặc xóa hẳn file quá lớn. Dung lượng chỉ được giải phóng khi người dùng duyệt `-Purge`, và bảng duyệt phải nói rõ điều này.
- **Tắt app khởi động qua `StartupApproved`** (giống Task Manager) thay vì xóa khóa Run; dịch vụ bên thứ ba chuyển Manual chứ không Disabled.
- **Tiết kiệm quota**: script lớn, đầu ra nhỏ, tối đa 2 lần thử mỗi lệnh, báo cáo sinh bằng script, bảng chat 6 cột còn bảng kỹ thuật vào `proposals.csv`.
- **Màn hình duyệt**: gợi ý nhanh, nhóm có tên thường, 6 cột lời thường, mã con cho từng file, bản xác nhận 6 ý, chấp nhận câu nói tự nhiên nhưng phải nhắc lại mã và không bao giờ đoán theo hướng làm nhiều hơn.
- **Không dùng video nền** từ prompt thiết kế Aurora: không chắc nội dung hợp chủ đề và trang sẽ phụ thuộc mạng.

## 5. Đã kiểm thử và chưa kiểm thử

Kiểm chứng khi đổi tên, ngày 28/10/2026, trên Windows:

- Build lại đủ hai ZIP, hai trang HTML và hai prompt Markdown; JavaScript qua `node --check`.
- Phân tích cú pháp cả 12 script bằng Windows PowerShell 5.1.19041.6456; giữ BOM UTF-8.
- Cài từng ZIP vào hồ sơ người dùng tạm, kiểm tra đủ 10 file khớp từng byte trong mỗi thư mục `.claude/skills/syrin-clean` và `.agents/skills/syrin-clean`.
- Chạy `make-report.ps1 -NoOpen` cho EN/VI bằng dữ liệu thử, có baseline và CSV tiếng Việt; kiểm tra dữ liệu nhúng, ngôn ngữ, thoát chuỗi đóng thẻ script và cú pháp JavaScript.
- Đối chiếu ZIP nhúng trong trang với file `dist/`, ba phụ lục với nguồn, liên kết nội bộ và ID HTML. Kiểm tra logic tạo hồ sơ, đặt lại và tải ZIP/Markdown/PowerShell bằng Node với DOM giả lập.
- Chưa kiểm chứng hiển thị trong trình duyệt: trình duyệt tích hợp chặn URL `file://`. Kiểm tra Node không chứng minh bố cục hay WebGL.

Các kiểm tra này không chạy dọn máy, tạo Restore Point, nâng quyền hay cài skill vào hồ sơ người dùng thật. Ma trận Windows và kiểm thử thực thi bên dưới vẫn còn mở.

Đã làm trước khi bàn giao (trong sandbox không có Windows và trình duyệt):

- `node --check` toàn bộ JavaScript của hai trang và mẫu báo cáo; chạy logic trang với DOM giả lập (tùy chọn, tạo prompt, tải file, nút chạy thử, đường WebGL và đường 2D).
- Vẽ lại cảnh 3D ra ảnh ở 8 mốc cuộn và sửa qua 5 vòng (xem `docs/images/scene-sequence.png`); vẽ thử báo cáo 3D với dữ liệu giả lập (`docs/images/report-scene.png`).
- Cân đối thẻ HTML, không trùng id, regex trích phụ lục A/B/C đúng khối.

Chưa làm (việc cần làm trước khi phát hành rộng):

- **Chạy thật các script PowerShell** trên Windows 10 và 11 (x64, ARM64; Home và Pro; có và không có Admin).
- **Biên dịch shader WebGL trên GPU thật** (nếu lỗi, trang tự về 2D).
- **Kiểm tra giao diện trong trình duyệt** ở 390, 768, 1366, 1920, 2560 px bằng `?check`.
- Chạy skill với Claude Code, Codex, Copilot, Cursor, Gemini CLI để xác nhận skill được nạp và gọi đúng.

## 6. Việc còn mở, theo thứ tự ưu tiên

1. Chạy thử chế độ “Chỉ kiểm tra” trên máy thật, sửa lỗi script nếu có (đọc `log.txt`, `audit.json`).
2. Kiểm tra `?check` ở các kích thước phổ biến, sửa chỗ còn báo.
3. Ký số script và quy trình phát hành tự động (GitHub Actions chạy `tools/build.py`).
4. Cân nhắc gom JS/CSS chung của hai trang ra file riêng nếu chuyển sang host trực tuyến (hiện nhúng để mở offline).
5. Tác vụ kiểm tra sức khỏe hằng tháng chỉ đọc như một trình cài đặt tùy chọn.

## 7. Cách tiếp tục công việc

| Muốn sửa | Sửa ở đâu | Sau đó |
|---|---|---|
| Nội dung prompt | `src/prompt-template.vi.txt` / `.en.txt` | Nếu sửa phần có trong skill, sửa cả `skill/*/syrin-clean/SKILL.md` hoặc `references/` tương ứng; chạy `python tools/build.py` |
| Script | `skill/vi/.../scripts/` và `skill/en/.../scripts/` (giữ giống nhau) | `python tools/build.py` |
| Mẫu báo cáo 3D | `skill/*/syrin-clean/assets/report-template.html` (giữ giống nhau) | `python tools/build.py` |
| Giao diện, hồ sơ ưu tiên, cảnh 3D | `web/*.html` (sửa trực tiếp, hai trang dùng chung CSS/JS) | Mở `?check`, chạy `python tools/build.py` để đồng bộ nội dung nhúng |

`tools/build.py` không đổi giao diện; nó chỉ đóng gói zip, nhúng lại nội dung vào trang và tạo lại file .md.
