# CLAUDE.md - hướng dẫn cho Claude làm việc trên repo này

Claude Code tự đọc file này khi mở repo. Đọc hết trước khi làm gì. Chi tiết bố cục và lệnh tái tạo từng bảng/hình:
`README.md`. Chuyển máy: `docs/MIGRATION.md`.

## 1. Dự án

Bài báo **PAW-MOBADC**: tái hiện và mở rộng MOBADC (Guo et al. 2020, *Control Engineering Practice* 102, 104560)
trên plant **P2** = quadrotor ghép con lắc cầu 3D (tải treo), gió đo thật NREL M5. Chỉ mô phỏng Simulink, không bay
thật. Không có lab: mọi thông số lấy từ tài liệu công bố (`docs/devlog/ADVISOR_NOTES.md`).
- **Tác giả** (từ 2026-10-07, bản nộp IJDC): Huy Hoang Tran (tác giả thứ nhất), Xuan Bach Nguyen (tác giả liên hệ),
  Xuan Hai Le (giám sát) - `paper/ijdc/title_page.tex`. Trước đó các tài liệu ghi "tác giả duy nhất" (đến 2026-10-07).
- **Tạp chí đích:** International Journal of Dynamics and Control (Springer, phản biện ẩn danh hai chiều).

- **C1** - bù trễ vòng: dự báo nhiễu tải qua trễ, B·e^{Aτ}·ξ̂ (= Bobtsov & Pyrkin 2012 (52)-(54) với L_u = 1, φ_u = 0) → PA-MOBADC.
- **C2** - lực cản gió của tải trong feed-forward gió đo: (1+K̂)·F̂_wQ, suy ra từ cân bằng lực của hệ ghép → PAW-MOBADC.
- **C3** - nghiên cứu oracle (bộ dự báo gió đóng băng `w4_frozen_20hz_t150_train2345_s0.pt`, không bao giờ train lại).
- Tên bộ điều khiển: bản đồ DUY NHẤT ở `analysis/p2_names.m` (PID = Classical, DO, ESO, MOBADC = L0, MOBADC-DC = L1,
  MOBADC-W = L2, MOBADC-W + preview = V, PA-MOBADC = L3, **PAW-MOBADC = L3_iii0 (đề xuất)**, INDI-DE = H3, MBP = L3_iii,
  oracle = O). Không tự đặt tên khác.
- Trạng thái: kết quả P2 và CONFIRM2 (14 ngày giữ lại, dùng ĐÚNG MỘT LẦN) đã xong. Lần chạy final trên GitHub
  (`docs/REGISTER_FINAL.md`, `docs/RESULTS_FINAL.md`) tái lập 39/39 số dev; CONFIRM3 không chạy (quyết định người dùng).
  Bản thảo `paper/manuscript.md` viết lại cho IJDC (lập luận, có phân tích bị chặn §4.5); bản LaTeX ẩn danh
  `paper/ijdc/manuscript.tex` sinh từ đó, trang tiêu đề `paper/ijdc/title_page.tex`.

## 2. Giao tiếp

- **Trả lời người dùng bằng tiếng Việt.** Code, commit, tài liệu kỹ thuật trong repo: tiếng Anh (devlog có thể tiếng Việt).
- Người dùng chạy MATLAB R2022b. Khi đưa lệnh MATLAB cho người dùng: **không đặt comment `%` trên dòng bắt đầu bằng `!`**.
- Người dùng muốn được duyệt KẾ HOẠCH trước khi xoá file bất kỳ.

## 3. Luật cứng (không được vi phạm)

1. **Không `git pull` / không sửa code mà MATLAB đang đọc khi MATLAB đang chạy batch** (script đêm `experiments/gd*.m`).
2. **Đăng ký trước, chạy sau.** Mọi phân tích/claim mới phải được ghi vào `docs/REGISTER_P2.md` (append only, không sửa
   mục cũ; sửa = thêm mục amendment) TRƯỚC khi mở dữ liệu. Sai lệch sau khi đã thấy dữ liệu → `docs/DEVIATIONS.md`.
   CONFIRM2 không được chạy lại cho claim mới. `PROTOCOL_LOCK.md` là khoá - không sửa.
3. **Liêm chính trích dẫn:**
   - Không bao giờ bịa số phương trình, số trang, DOI. Chưa chắc → ghi `CẦN TÌM` / `CẦN KIỂM`.
   - `docs/EQUATIONS_TABLE.md`: mỗi phương trình có loại [A] lấy nguyên từ bài X, [B] suy ra/điều chỉnh từ nguồn
     (ghi nguồn + thay đổi), [C] lựa chọn thiết kế/định nghĩa của mình ("we choose / we define"). Không dán nhãn
     "của mình" cho thứ đã có trong tài liệu; không dùng công thức không có cơ sở khoa học.
   - **Không claim "novel", "for the first time", "the first to"...** (`tools/check_equations.py` bắt lỗi này).
   - Mọi bài được trích đã đọc toàn văn (`docs/READING_LOG.md`; Gomiero 2026 và Li & Zhu 2023 trước chỉ có tóm tắt,
     đã đọc toàn văn 2026-10-07). Bản thảo KHÔNG ghi "full text not accessible" / "cited from abstract".
   - Sách giáo khoa trích theo chương (`[@key, chap. n]`).
4. **Số trong bản thảo phải lấy từ `docs/RESULTS_P2.md`, `paper/tables/tables_p2.md` hoặc `docs/RESULTS_FINAL.md`**
   (`tools/check_propagation.py` kiểm; làm tròn half-up được chấp nhận ở Highlights/Abstract/Introduction/Results/
   Conclusion). Trích dẫn chỉ khi đã đọc toàn văn (`docs/READING_LOG.md`, `tools/check_reading.py --final`).
5. **File sinh tự động - không sửa tay:** `docs/RESULTS_P2.md` (`make_results_p2`), `docs/RESULTS_FINAL.md`
   (`make_results_final`), `paper/tables/tables_p2.md` (`make_p2_tables`), `paper/figures/*` (`make_p2_figures`),
   `paper/ijdc/manuscript.tex` (`python paper/ijdc/build_tex.py`), bảng tên trong README (`python tools/readme_names.py --write`),
   `data/SHA256SUMS.txt` (`python tools/data_manifest.py --write`).
6. **Không commit:** PDF trong `refs/` (bản quyền), dữ liệu gió, mọi `.mat` (trừ `field_grid_K050.mat`), `results/`,
   `.pt` (trừ cặp đóng băng). Xem `.gitignore`.
7. **Không bao giờ xoá `results/`** - dữ liệu duy nhất, không thay thế được (SHA-256 ở `data/SHA256SUMS.txt`).
8. **Git:** làm trên nhánh `claude/main-vulnerability-check-hd94m7`. Không đụng `main` khi chưa có cho phép RÕ RÀNG
   (main = 36ef5b9 là tổ tiên của nhánh, fast-forward được). Không tạo PR nếu không được yêu cầu. Mỗi bước một commit.
   Không ghi tên/mã model AI trong commit, code, tài liệu. Tag: `v1-final` (nghiên cứu v1 con lắc phẳng, đã xoá
   khỏi nhánh), `data-verified-2026-09-12`, `paper-results-p2` (trên 36907e3).
9. Trước khi xoá file: grep cả tên file trong chuỗi (`load('x.mat')`), không chỉ call graph.

## 4. Quy trình làm việc

Mọi lệnh MATLAB chạy từ gốc repo, sau `setup_path`. Claude chạy MATLAB trên máy người dùng bằng:

    matlab -batch "setup_path; check_all"

| việc | lệnh |
|---|---|
| sinh lại số của bài | `make_results_p2` → `docs/RESULTS_P2.md` |
| bảng 1-6 | `make_p2_tables` → `paper/tables/tables_p2.md` |
| hình 1-9 | `make_p2_figures` (hoặc `make_p2_figures('Only', [3 9])`) → `paper/figures/` |
| 7 bước kiểm (không mô phỏng) | `check_all` - phải 7/7 PASS: syntax, protocol_lock, check_retracted, check_propagation, extract_eml, check_equations, check_names |
| tái lập | `S = verify_p2_repro` (14 mô phỏng: Hình 3, 9 bit-for-bit \|d\| = 0; D2 dòng 1 đúng đến chữ số in, \|d\| ≤ 1.04e-7 m, REGISTER_P2 §65); `verify_p2_repro('Quick', true)` = 4 mô phỏng (chỉ D2 dòng 1) |
| dữ liệu kết quả | `python tools/data_manifest.py --check` |
| kiểm văn bản (không cần MATLAB) | `python tools/check_names.py`, `check_equations.py`, `check_propagation.py`, `check_retracted.py`, `readme_names.py --check` |
| khối Simulink ↔ nguồn | `python tools/extract_eml.py baseline1.slx --check simulink_blocks` |
| render bản thảo | `pandoc paper/manuscript.md --citeproc -o out.docx` (bib + csl khai báo trong YAML) |
| bản nộp IJDC | `python paper/ijdc/build_tex.py` → `paper/ijdc/manuscript.tex`; PDF: CI `.github/workflows/ijdc.yml`, artifact `ijdc-pdf`; zip nộp (phẳng, kiểm ẩn danh): `python paper/ijdc/make_bundle.py`, artifact `ijdc-latex-zip` (CI biên dịch thử zip trong thư mục trống) |

CI GitHub (`.github/workflows/checks.yml`) chạy các bước kiểm văn bản mỗi lần push. Sau mỗi thay đổi: chạy các
bước kiểm liên quan, rồi mới commit/push.

Sửa mã Simulink: không sửa tay trong `baseline1.slx` rồi bỏ đó - nguồn của mọi MATLAB Function block nằm ở
`simulink_blocks/`, mỗi `build/build_*.m` chèn một thành phần; `extract_eml --check` phải PASS.

## 5. Việc còn mở (cập nhật 2026-10-04)

- Máy cũ đã kiểm xong (2026-10-04, REGISTER_P2 §65): `check_all` 7/7, `data_manifest --check` PASS,
  `verify_p2_repro` PASS (Hình 3, 9 |d| = 0; D2 dòng 1 ≤ 1.04e-7 m). Tag `paper-results-p2` đã có trên
  GitHub (→ 36907e3). Việc tiếp: chuyển máy theo `docs/MIGRATION.md`; trên máy mới chạy lại `folder_snapshot --check`,
  `check_all`, `verify_p2_repro`.
- MATLAB R2022b trên máy cũ crash nhiều lần ngày 2026-10-04 (0xc0000374, heap corruption trong ntdll), cả khi chỉ nạp
  model; nguyên nhân chưa rõ, không phải code. Cách chạy an toàn: mỗi bước một `matlab -batch` riêng trong PowerShell,
  `verify_p2_repro` tách 3 phần: `verify_p2_repro('Quick', true)`, `make_p2_figures('Only', 3, 'Save', false)`,
  `make_p2_figures('Only', 9, 'Save', false)` (REGISTER_P2 §66.3-66.4). Khi MATLAB hỏi khôi phục autosave của
  `baseline1`: luôn chọn KHÔNG (khôi phục ghi đè `baseline1.slx`). Không cập nhật bản MATLAB khi chưa kiểm lại.
- Fingerprint P2: model vừa dựng (`c965867910b8…`) và cùng model nạp từ file (`fae8c428ca30…`) khác nhau - chỉ so
  cùng loại (`build_p2_plant('FingerprintOf', file)`, `verification/model_fingerprint.m`; REGISTER_P2 §66.1). Bảng
  "file kết quả -> model": §66.2, §66.4-66.5 (đủ 39 file).
- Nhóm dọn 1 (5 file chẩn đoán) và nhóm 2 (code H4) đã xoá và kiểm (§66.4); nhóm 3 (phần v1 trong model) giữ, lý do ở
  README.
- Đã dọn file không theo dõi trên máy cũ (`tools/local_tidy.py --apply`): 2357 file sang `E:\windataset_archive\`,
  28 log vào `logs/`, 169 file cache xoá; journal `E:\windataset_archive\tidy_journal.tsv` (`--undo` trả lại).
- Trước khi nộp: số trang bản IEEE của Sreenath (1 dòng CẦN KIỂM trong EQUATIONS_TABLE); người dùng tick các dòng
  EQUATIONS_TABLE; vẽ lại hình 3-9 theo kiểu IJDC từ 39 file kết quả gốc (máy mới chưa có `results/` gốc); đưa
  `results/` lên Zenodo. `check_reading.py --final` đã PASS (2026-10-07): mọi bài được trích đã đọc toàn văn.
  Tạp chí đã chọn (IJDC); phân tích bị chặn đã có (bản thảo §4.5).
- Bước 6 dọn repo (fast-forward `main`, đổi nhánh mặc định): CHƯA làm, chờ người dùng cho phép rõ ràng.
