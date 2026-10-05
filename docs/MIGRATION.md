# Chuyển repo sang máy khác mà không mất / hỏng dữ liệu

Git chỉ chứa code và tài liệu. **Dữ liệu không nằm trong git** (`.gitignore`), nên `git clone` trên máy mới là
KHÔNG đủ: phải chép nguyên thư mục. Quy trình: ghi SHA-256 mọi file trên máy cũ → chép → kiểm lại SHA-256 trên máy
mới → chạy các bước kiểm MATLAB.

## 0. Cần chuyển những gì

| thư mục / file | là gì | nếu mất |
|---|---|---|
| `E:\windataset\` (cả thư mục, kể cả `.git`) | repo + mọi file bị `.gitignore` loại | xem dưới |
| ├ `results/` | **39 file kết quả của bài** (`data/SHA256SUMS.txt`) + mọi lần chạy khác | **không thay thế được** - phải chạy lại hàng chục đêm |
| ├ `wind_real_t150_i*.mat`, `wind_expl_t150_i*.mat`, `wind_expl_t150_batch.json`, `wind_real_t150.mat`, `wind_sim_t150.mat` | đoạn gió đã xuất (dev + exploration) | xuất lại được từ M5 thô (`python/export_wind_sim.py`), mất nhiều giờ |
| ├ `wind_conf2/`, `wind_conf2_t150_batch.json` | 14 ngày CONFIRM2 đã xuất (Figure 3 đọc) | như trên, và phải trùng bit với bản đã dùng |
| ├ `m5/` và mọi thư mục/file khác không có trong git (`dataset/`, `wind_e0check/`, ...) | M5 thô (dev) và dữ liệu phụ | tải / sinh lại được, nhưng cứ chép nguyên |
| ├ `refs/` | PDF bài báo để đối chiếu công thức (không commit) | tải lại tay |
| ├ `.git/` | lịch sử, tag cục bộ (`paper-results-p2`), commit chưa push | mất tag / commit chưa push |
| `E:\m5_explore\` | M5 thô của 32 ngày exploration | tải lại được |
| `E:\m5_confirm2\`, `E:\m5_confirm2_excluded\` | M5 thô CONFIRM2 và 2 ngày bị loại (D23) | tải lại được; giữ để truy vết |

Không cần chép (MATLAB tự tạo lại): `slprj/`, `*.slxc`, `*.asv`, `__pycache__/`.

Nếu đã chạy `tools/local_tidy.py --apply`: đồ cũ (v1, checkpoint cũ, bộ gió tổng hợp, hình cũ) nằm ở
`E:\windataset_archive\` (ngoài repo) và log ở `logs/`. Thư mục lưu trữ không cần cho bài; chép nó (cùng cách,
có `folder_snapshot`) chỉ nếu muốn giữ, hoặc để lại trên ổ chép làm bản sao lưu.

## 1. Trên máy cũ - trước khi chép

1. **Chờ mọi batch MATLAB chạy xong, đóng MATLAB.**
2. Đẩy hết lên GitHub (trong PowerShell, tại `E:\windataset`):
   ```
   git status
   git add data/SHA256SUMS.txt
   git commit -m "data: SHA-256 of the 39 result files of the paper"
   git push origin claude/main-vulnerability-check-hd94m7
   git tag -a paper-results-p2 36907e3 -m "P2 results and CONFIRM2 complete"
   git push origin paper-results-p2
   ```
   Nếu `git status` còn file sửa đổi khác (ví dụ ` M baseline1.slx`): **đừng xoá/đừng reset** - hỏi Claude trước.
3. Ghi lại cấu hình (vào ổ chép, ví dụ `F:\move\`):
   ```
   mkdir F:\move
   git config --global core.autocrlf > F:\move\git_autocrlf.txt
   python --version > F:\move\python_version.txt
   python -m pip freeze > F:\move\pip_freeze.txt
   matlab -batch "ver" > F:\move\matlab_ver.txt
   ```
   `matlab_ver.txt` ghi bản MATLAB **và số Update** (ví dụ R2022b Update 5) cùng các toolbox - máy mới phải cài
   đúng như thế (xem mục 3).
4. Ghi SHA-256 của mọi file (mất một lúc với dữ liệu lớn; file ghi ra phải nằm NGOÀI thư mục được băm):
   ```
   python E:\windataset\tools\folder_snapshot.py --write F:\move\snap_windataset.txt E:\windataset
   python E:\windataset\tools\folder_snapshot.py --write F:\move\snap_m5_explore.txt E:\m5_explore
   python E:\windataset\tools\folder_snapshot.py --write F:\move\snap_m5_confirm2.txt E:\m5_confirm2
   python E:\windataset\tools\folder_snapshot.py --write F:\move\snap_m5_confirm2_excluded.txt E:\m5_confirm2_excluded
   ```
5. Chép bằng `robocopy` (giữ thời gian, có log, chạy lại được nếu đứt giữa chừng):
   ```
   robocopy E:\windataset F:\move\windataset /E /COPY:DAT /DCOPY:T /R:2 /W:5 /XD slprj /LOG:F:\move\rc_windataset.log /TEE
   robocopy E:\m5_explore F:\move\m5_explore /E /COPY:DAT /DCOPY:T /R:2 /W:5 /LOG:F:\move\rc_m5_explore.log /TEE
   robocopy E:\m5_confirm2 F:\move\m5_confirm2 /E /COPY:DAT /DCOPY:T /R:2 /W:5 /LOG:F:\move\rc_m5_confirm2.log /TEE
   robocopy E:\m5_confirm2_excluded F:\move\m5_confirm2_excluded /E /COPY:DAT /DCOPY:T /R:2 /W:5 /LOG:F:\move\rc_m5_confirm2_excluded.log /TEE
   ```
   Cuối mỗi log, cột `FAILED` phải là 0. Ổ chép nên là NTFS hoặc exFAT (FAT32 không chứa được file > 4 GB).
   **Không** chuyển qua OneDrive/Google Drive đồng bộ (dễ đồng bộ dở dang, đổi tên file trùng).
6. **Giữ nguyên máy cũ** cho đến khi bước 4 trên máy mới PASS.

## 2. Trên máy mới - cài đặt

- MATLAB **R2022b, cùng số Update** với `matlab_ver.txt`, cùng các toolbox trong đó (ít nhất Simulink). Bản khác có
  thể làm kết quả mô phỏng lệch ở chữ số cuối và `verify_p2_repro` sẽ FAIL.
- Python cùng phiên bản chính (`python_version.txt`), rồi: `python -m pip install numpy scipy torch`
  (hoặc đúng phiên bản theo `pip_freeze.txt`). torch chỉ cần cho bộ dự báo gió / xuất gió.
- Git, đăng nhập GitHub (`git push` thử được), cùng `core.autocrlf` như `git_autocrlf.txt`
  (`git config --global core.autocrlf <giá trị>`; nếu file rỗng thì không đặt).
- Claude Code (ứng dụng desktop tab Code, hoặc CLI) - mở trong thư mục repo; nó tự đọc `CLAUDE.md`.

## 3. Trên máy mới - chép về và kiểm

1. Chép về. **Nên giữ đúng đường dẫn cũ** (`E:\windataset`, `E:\m5_explore`, ...): code không cần (mọi đường dẫn
   tính từ `repo_root`), nhưng `docs/REGISTER_P2.md` và các lệnh xuất gió ghi các đường dẫn này. Không có ổ `E:` thì
   đặt chỗ khác cũng chạy được; khi xuất gió lại chỉ cần đổi tham số `--real-dir`.
   ```
   robocopy F:\move\windataset E:\windataset /E /COPY:DAT /DCOPY:T /R:2 /W:5 /LOG:F:\move\rc_back.log /TEE
   ```
   (tương tự cho 3 thư mục `m5_*`).
2. Kiểm từng byte - **cả 4 lệnh phải in `PASS`**:
   ```
   python E:\windataset\tools\folder_snapshot.py --check F:\move\snap_windataset.txt E:\windataset
   python E:\windataset\tools\folder_snapshot.py --check F:\move\snap_m5_explore.txt E:\m5_explore
   python E:\windataset\tools\folder_snapshot.py --check F:\move\snap_m5_confirm2.txt E:\m5_confirm2
   python E:\windataset\tools\folder_snapshot.py --check F:\move\snap_m5_confirm2_excluded.txt E:\m5_confirm2_excluded
   ```
   Báo `MISSING` / `DIFFERS` → chép lại đúng file đó từ ổ chép (hoặc máy cũ) rồi kiểm lại.
3. Git (PowerShell tại `E:\windataset`):
   ```
   git config --global --add safe.directory E:/windataset
   git status
   git fsck
   git fetch origin claude/main-vulnerability-check-hd94m7
   git status
   ```
   `safe.directory` sửa lỗi "detected dubious ownership" (thư mục chép từ máy khác có chủ sở hữu khác). `git status`
   phải sạch như trên máy cũ; nếu mọi file đều báo modified thì `core.autocrlf` khác máy cũ - sửa cấu hình, không commit.
4. MATLAB tại `E:\windataset`:
   ```
   setup_path
   check_all
   S = verify_p2_repro
   !python tools/data_manifest.py --check
   ```
   - `check_all`: 7/7 PASS.
   - `verify_p2_repro`: PASS, mọi |d| = 0 (lần đầu chậm vì Simulink dựng lại `slprj/`).
   - `data_manifest --check`: PASS (39 file trùng SHA-256).

   Nếu `verify_p2_repro` ra |d| khác 0 nhưng rất nhỏ (cỡ 1e-15 .. 1e-12): đó là khác biệt số học giữa hai máy
   (CPU / bản MATLAB), không phải hỏng dữ liệu (dữ liệu đã PASS ở bước 2). **Không ghi đè `results/`, không chạy
   lại kết quả** - báo Claude để ghi vào `docs/DEVIATIONS.md` và dùng máy cũ làm máy tham chiếu.
5. Khi mọi bước PASS: máy mới thay được máy cũ. Giữ ổ chép làm bản sao lưu cho đến khi `results/` lên Zenodo.
