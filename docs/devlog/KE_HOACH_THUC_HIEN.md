# KẾ HOẠCH THỰC HIỆN CỦA HUYHOANG — từ plant P2 đến lúc nộp bài

> Đây là kế hoạch **cho bạn** (không phải cho Claude Code). Mỗi giai đoạn ghi rõ:
> **Bạn làm** · **Claude Code làm** · **Kiểm tra** · **Gửi gì** · **Xong khi**.
> Đánh dấu [x] vào ô khi xong. Thời gian là ước lượng thô.
> Tài liệu Claude Code dùng: `CLAUDE_CODE_BRIEF.md`, `TEST_PLAN_v2.md`, `MASTER_PLAN.md`, `PLANT_P2_SPEC.md`,
> `docs/REGISTER_P2.md`. Khi mâu thuẫn: `REGISTER_P2.md` > brief > MASTER_PLAN > file này (`PROTOCOL_LOCK.md` chỉ v1).
>
> *(đồng bộ 2026-09-25)* **Tác giả duy nhất, không có thầy/lab** (`ADVISOR_NOTES.md`): mọi chỗ "thầy" / "lab"
> dưới đây đã được thay theo bảng hệ quả trong `ADVISOR_NOTES.md` — bạn tự quyết, thông số từ tài liệu công bố.
>
> **Đồng bộ 2026-09-25 (quyết định (a)–(e) của bạn):** P2, v1 không vào bài; BRIDGE thay bằng kiểm tra nội bộ GĐ3;
> bộ điều khiển dùng mô hình lực gió bậc hai danh định; CỔNG G định nghĩa chính xác trong `REGISTER_P2.md` §0;
> N3 v1 bỏ, sửa X-segset thành hạ tầng P2 (GĐ5). Các chỗ Claude Code sửa trong file này đánh dấu *(đồng bộ)*.

---

## MỤC TIÊU (đọc lại mỗi khi phân vân)

Chứng minh **dự đoán nhiễu tải và nhiễu gió trước τ giây** cải thiện MOBADC cho UAV treo tải trong gió thật,
và chỉ ra **khi nào** mỗi loại dự đoán có tác dụng. Mọi việc khác (P2, kiểm chứng, IM-est, đối thủ) là để kết quả
này đáng tin. Vai trò IM-est, kết luận về gió, tên bài: **chỉ quyết khi có số trên P2**, theo tiêu chí viết trước.

---

## A. LUẬT CỦA BẠN (không bao giờ vi phạm)

1. **Không pull code khi MATLAB đang chạy batch.** Pull trước khi chạy, hoặc sáng hôm sau.
2. **Luôn dry-run trước khi chạy thật**, và chỉ chạy thật khi dry-run in đủ "field-list proof".
3. **Sáng nào cũng đọc `STOP_REASON.txt` và dòng `gate:` trước tiên.** Gate trượt → không đọc số khác.
4. **Không mở, không tải, không nhìn 16 ngày CONFIRM2** cho tới giai đoạn 10.
5. **Không để Claude Code tự quyết** những gì ghi "cần bạn quyết". *(đồng bộ)* Không chắc → ghi lại, tự quyết dựa trên tài liệu.
6. **Mọi thay đổi model Simulink:** bạn build trên MATLAB → chạy `verify_repro` → push `baseline1.slx` → báo hash.
7. **Tiêu chí quyết định viết trước khi chạy.** Thấy số rồi không đổi ngưỡng.
8. Trước mỗi đêm chạy dài: tắt Sleep, hoãn Windows Update, cắm sạc.

---

## B. LỆNH CHUẨN

**Cập nhật code (chỉ khi MATLAB không chạy gì):**
```
!git pull origin claude/main-vulnerability-check-hd94m7
bdclose('all'); clear functions; rehash path; setup_path
```

**Kiểm tra repo sạch (sau mọi thay đổi model):**
```
R0 = verify_repro(); assert(R0.pass)
check_results_numbers
check_all
!python3 tools/extract_eml.py baseline1.slx --check simulink_blocks
```

**Push model sau khi build + kiểm tra PASS:**
```
!git add baseline1.slx
!git commit -m "<mô tả> - verify_repro PASS"
!git push origin claude/main-vulnerability-check-hd94m7
!git log -1 --format=%H
```

**Chạy qua đêm (mẫu):**
```
diary('<ten>_log.txt'); batch_robust('<KHỐI>'); diary off
```

**Mất điện / lỗi giữa chừng:** chạy lại đúng lệnh cũ (resume từ đoạn đã lưu).

---

## C. NHỊP LÀM VIỆC MỖI NGÀY

| lúc | việc |
|---|---|
| **Sáng** | Mở `STOP_REASON.txt` (nếu có) → đọc dòng `gate:` → gửi log cho Claude Code → gửi bảng tóm tắt cho mình (Claude chat) nếu cần diễn giải |
| **Ngày** | Đọc báo cáo của Claude Code theo mẫu §8 → quyết các mục "cần bạn quyết" → cho phép việc tiếp theo → đọc tài liệu / viết phần lý thuyết |
| **Tối** | Pull → dry-run → kiểm field-list → chạy thật → kiểm 5 phút đầu → để máy chạy |

---

## D. CÁC GIAI ĐOẠN

### GĐ 0 — Chuẩn bị và thống nhất hướng (tuần này)

- [x] Commit `MASTER_PLAN.md` và file này vào `docs/devlog/`.
- [x] Claude Code gắn tag `v1-final` (xác nhận bằng `!git tag` thấy `v1-final`). *(đồng bộ)* Tag đã tạo trong phiên
  Claude Code tại `d3a7633` nhưng proxy phiên chặn push tag → **bạn push tag từ máy** (lệnh trong báo cáo), rồi
  kiểm `!git ls-remote --tags origin v1-final`. **Xong:** tag trên remote (object `fac19dba…` → `d3a7633`).
- [ ] Tải 32 ngày exploration (lệnh trong báo cáo của Claude Code; kiểm dòng `65 -> 32 days`, `128 files`).
- [x] ~~Gặp thầy~~ — bỏ *(đồng bộ)*: tác giả duy nhất (`ADVISOR_NOTES.md`).
- **Xong khi:** tag + tài liệu + tải exploration xong; tham số phần cứng lấy từ tài liệu công bố (`PLANT_P2_SPEC.md` §2).

### GĐ 1 — Đặc tả plant P2 (vài ngày)

- **Claude Code làm:** viết `PLANT_P2_SPEC.md`: mọi thành phần, mọi tham số có nguồn hoặc "giả định + dải độ nhạy";
  mỗi thành phần ghi ảnh hưởng tới kết luận dự đoán và mức (bắt buộc / cần nếu IM-est / nên có).
- **Bạn làm:** đọc spec với **checklist**:
  - [ ] con lắc đơn 3D, dây cứng, tải chất điểm, F_d là nội lực (lên cả hai vật)
  - [ ] lực cản bậc hai cho tải và thân UAV; U_ref = 5 m/s (mốc khoá; trung vị T.U = 5.0898, lệch 1.8%); C_D·A hợp lý vật lý
  - [ ] *(đồng bộ 2026-09-25)* envelope P2 mới: giữ vị trí trước lực gió tĩnh (nghiêng ≤ 0.8·30°, lực đẩy
        ≤ 0.8·F_TOT_MAX), bảng U_max ở REGISTER_P2 §0.10; θ tải chỉ báo
  - [ ] trễ động cơ: hằng số thời gian + nguồn
  - [ ] cảm biến gió: nhiễu, trễ + nguồn; IMU: nhiễu, bias + nguồn (datasheet IMU Guo dùng)
  - [ ] tần số điều khiển vòng tư thế / vị trí + nguồn
  - [ ] giới hạn lực đẩy 21.6 N, góc nghiêng tối đa
  - [ ] mức m_p đề xuất (lực đẩy đỉnh ≤ ~85% giới hạn)
  - [ ] danh sách những gì KHÔNG mô hình hoá
  - [ ] *(đồng bộ)* F_d nội lực, c = 2 ζ_s ω_n m_L (định nghĩa với điểm treo cố định, quy ước; V2 khớp v1 khi UAV
        áp chuyển động); độ nhạy ζ_s phủ sự mơ hồ vòng kín
  - [ ] *(đồng bộ)* ý nghĩa K dưới lực cản bậc hai: K = 0 → C_D·A_L = 0; K = 0.5 → theo MASTER_PLAN (2.8)
  - [ ] *(đồng bộ)* bộ điều khiển dùng mô hình lực gió **bậc hai cùng dạng plant**, tham số danh định, vận tốc tương
        đối w − v_Q; **O = gió thật w(t+τ) qua chính mô hình lực đó**; cột phụ "oracle lực thật" báo riêng, không
        dùng cho CỔNG G; sai số tham số lực cản → Monte Carlo riêng (GĐ9)
  - [ ] *(đồng bộ)* m_p ∈ {0.25, 0.5, 0.65} + báo tỉ lệ bão hoà
  - [ ] *(đồng bộ)* `REGISTER_P2.md` §0 (D2–D4, CỔNG G, oracle, nhóm điều kiện) đã APPROVED — **trước GĐ3**
- **Cần bạn quyết:** các tham số phần cứng — *(đồng bộ)* từ tài liệu công bố (datasheet, tài liệu nền tảng).
- **Xong khi:** bạn ghi "APPROVED" vào spec.

### GĐ 2 — Code P2 và kiểm chứng (~1–2 tuần)

**2a. Hàm thuần (Octave, không đụng Simulink)**
- **Claude Code làm:** `plant_p2_derivative.m`, `verify_plant_p2.m` (V1–V7), unit test động cơ, cảm biến, rời rạc.
- **Kiểm tra:** bảng PASS/FAIL, mọi dòng PASS kèm số đo:
  - V1 treo tĩnh T = m_L g · V2 góc nhỏ khớp v1 · V3 năng lượng bảo toàn · V4 con lắc nón ω² = g/(L cos θ)
  - V5 ràng buộc dây · V6 động lượng bảo toàn (cả ζ_s = 0 và > 0) · V7 lực cản tại U_ref
- **Xong khi:** 7/7 PASS + unit test PASS.

**2b. Nối Simulink**
- **Claude Code làm:** thiết kế nối (Variant) → **bạn duyệt** → code build script.
- **Bạn làm:** chạy build trên MATLAB → kiểm tra repo sạch (mục B) → push slx → báo hash.
- **Kiểm tra:** chạy thử 1 lần circle trên P2: không lỗi; T_min > 0; lệch ràng buộc < 1e-6.
- **Xong khi:** P2 chạy được một đoạn circle đầy đủ, số hợp lý.

### GĐ 3 — Kiểm tra nội bộ (1–2 đêm; KHÔNG đưa vào bài)

- **Claude Code làm:** khối bật **từng thành phần P2 một** trên circle (5 đoạn **cố định của REGISTER_ROBUST §18.6**:
  i0000, i0319, i0453, i0715, i0900): chỉ con lắc 3D → + lực cản → + động cơ
  → + cảm biến → + rời rạc. Và các ca khó: hover có tải, T5 có tải không gió, T5 L 1.5, m_p lớn.
  *(đồng bộ)* Chỉ chẩn đoán, không vào bài; thay cho BRIDGE. Các ca dừng `X-esoatt` của v1 (X-hover, T5_L1p5,
  T5 sàn t = 3.22 s trên i0006, T5 exact-reference τ 0.14 trên i0705/i0770) nằm trong danh sách ca khó.
- **Kiểm tra:** mỗi thành phần đổi L2/L3 bao nhiêu; ca nào phân kỳ, ở góc lắc bao nhiêu, khối nào.
- **ĐIỂM QUYẾT ĐỊNH D1:** còn phân kỳ không?
  - Không → sang GĐ 5.
  - Có → GĐ 4.

### GĐ 4 — Sửa bộ điều khiển nếu còn phân kỳ (0–2 tuần, rủi ro cao nhất)

- **Claude Code làm:** chẩn đoán có ngân sách (mỗi vòng bạn duyệt): lệnh góc nghiêng suy biến / bão hoà,
  DO/ESO tần số cao, gain ESO tư thế.
- **Bạn làm:** duyệt từng vòng; **nếu quá 2 tuần chưa ra → bạn quyết** *(đồng bộ)* (có thể khai báo giới hạn thay vì sửa).
- **Xong khi:** hover có tải và m_p đã chọn chạy không phân kỳ, hoặc bạn quyết khai báo giới hạn.

### GĐ 5 — Đăng ký giao thức P2 (vài ngày)

- **Claude Code làm:** `REGISTER_P2.md` (phần giao thức, sau §0): tập dev theo envelope P2 (cố định, in danh sách),
  mỗi quỹ đạo một bảng, quy tắc τ (biết trước → τ\* đo; không biết → τ danh định), chuẩn báo cáo (pooled + SE paired
  + trung vị ngày + LOO). *(đồng bộ)* Hạ tầng `X-segset` (thay N3 v1): pool trên tập đăng ký, mỗi quỹ đạo một bảng.
  Ngưỡng D2–D4 đã nằm ở §0 (đăng ký trước GĐ3), GĐ5 không đổi chúng.
- **Bạn làm:** đọc, kiểm các ngưỡng **trước** khi có bất kỳ số P2 nào. Ghi "APPROVED".

### GĐ 6 — Kết quả lõi trên P2 (~1–2 tuần chạy đêm)

| đêm | khối | trả lời |
|---|---|---|
| 1–2 | τ\* theo điều kiện (quy trình N0P, lưới 0:20:400 + mịn 10 ms), bắt đầu bằng circle | horizon dự đoán |
| 3 | bảng chính circle: L0, L1, L2, L3, F2, P, O, V, VP | dự đoán tải có tác dụng không |
| 4 | tách cơ chế: tải bật/tắt; độ nhạy LOO | dự đoán lực tải thật hay không |

- **ĐIỂM QUYẾT ĐỊNH D2:** L3 so với L2 ≤ −30% và giữ dấu khi bỏ từng đoạn? (định nghĩa chính xác: `REGISTER_P2.md` §0)
  - Có → tiếp.
  - Không → **dừng, bạn xem lại hướng bài.** *(đồng bộ)*

### GĐ 7 — Gió quyết định + tải diện rộng (~1–2 tuần, song song)

**Nhánh gió:**
| khối | trả lời |
|---|---|
| N5-A (K = 0, gió yếu/vừa/mạnh) | dự đoán gió lên thân UAV khi gió mạnh |
| N5-B (K = 0.5, yếu/vừa; mạnh báo từng đoạn) | kịch bản đầy đủ |
| N6-oracle | gió → dao động tải có dư địa không |
| N4b-P2 (base, trễ 200 ms, L 1.5, K 1.0) | bản đồ dư địa trên P2 |

**Nhánh tải:**
| khối | trả lời |
|---|---|
| N3-P2 (circle / hình số 8 / hình vuông; N3 v1 đã bỏ) | cần đúng tần số; dự đoán vs preview |
| N2 (L 0.5 / 1.0 / 1.5) | chiều dài dây |
| khối lượng tải m_p ∈ {0.25, 0.5, 0.65} + tỉ lệ bão hoà | tải nặng nhẹ |
| hover có tải | Test 1 của Guo |
| N1c (cộng hưởng), N4a (ζ) | giới hạn, độ bền |
| ngưỡng góc lắc | bộ điều khiển chịu tới đâu |

- **ĐIỂM QUYẾT ĐỊNH D3 = CỔNG G:** oracle gió ≥ 10% ở ≥ 1 nhóm điều kiện **và** bộ dự đoán bắt ≥ 50%?
  *(đồng bộ)* Chính xác (`REGISTER_P2.md` §0): nhóm có dư địa ⇔ h = 1 − O/L3 pooled ≥ 10% **và** giữ dấu LOO **và**
  trung vị theo ngày ≥ 5%; bắt được ⇔ c = (L3 − P)/(L3 − O) ≥ 0.5 pooled **và** (L3 − P) giữ dấu LOO. Chỉ các nhóm
  điều kiện liệt kê TRƯỚC trong §0.
  - **Có (gió mạnh):** tải + gió là đóng góp chính; IM-est là mục mở rộng.
  - **Không (gió yếu):** tải + IM-est là chính; gió là kết quả âm có bản đồ điều kiện.

### GĐ 8 — IM-est (1 tuần nếu phụ, 3–4 tuần nếu chính)

- Thứ tự: R-U1b (T5 ở τ\* đúng; *(đồng bộ)* **đăng ký lại trên P2** trước GĐ8) → nối online (Variant đã có) → A-CP1.5 → A-slot → A-CP2 → A-step → A-CP3 → A-CP4.
- **Bạn làm trước khi chấm held-out:** đặt ngưỡng X (vd "lấy lại ≥ 30% lợi ích của exact-frequency").
- **ĐIỂM QUYẾT ĐỊNH D4:** chấm held-out (tham chiếu không dừng, 3 seed) **một lần**.

### GĐ 9 — Làm bài đủ mạnh cho Q cao (vài tuần – 2 tháng)

- [ ] **Lý thuyết:** ổn định vòng kín có dự đoán, chặn sai số theo τ và độ lệch tần số; (IM-est chính) hội tụ ước lượng tần số.
  **Bạn làm chính**, Claude hỗ trợ suy dẫn và kiểm. *(đồng bộ: không có thầy duyệt)*
- [ ] **Đối thủ (2–3):** INDI, DOB thích nghi tần số (Marino–Tomei), điều khiển có phản hồi góc tải hoặc MPC. Tune công bằng, đăng ký trước.
- [ ] **Monte Carlo:** sai số tham số (m_Q, m_L, L, J, ζ, C_D·A, trễ cảm biến) × nhiều đoạn gió.
- [ ] **Kiểm tài liệu tham khảo:** mọi [?] → [✓] trên Google Scholar / IEEE Xplore.

### GĐ 10 — Xác nhận trên CONFIRM2 (1–2 đêm)

- **Bạn làm:** lúc này mới tải 16 ngày CONFIRM2. Chạy **một lần** các claim đã đăng ký. Không chạy lại, không sửa gì sau khi thấy số.
- **Xong khi:** có bảng confirm cho mọi claim chính (HIT/MISS đều báo).

### GĐ 11 — Viết và nộp

- [ ] Chọn tạp chí *(đồng bộ: bạn quyết)* (kiểm SJR hiện tại, đọc vài bài gần đây xem có nhận bài chỉ mô phỏng không).
- [ ] Tên bài + câu đóng góp theo kết quả D2–D4 (**D5**, bạn quyết).
- [ ] Hình, bảng từ `fig_data` (không vẽ tay số).
- [ ] **Bảng phương trình `docs/EQUATIONS_TABLE.md`** (quyết định của user 2026-09-29): MỘT bảng gồm mọi phương trình
  bài dùng - nhãn, dạng LaTeX, loại [A] lấy nguyên / [B] điều chỉnh (ghi thay đổi) / [C] của tác giả (chỉ khi đã tra
  tài liệu, ghi từ khoá/nơi tra/ngày), nguồn + số phương trình + link, ô kiểm [ ] ĐÚNG [ ] SAI. Kiến thức sách giáo khoa
  → [A]. Không bịa số phương trình/DOI (không chắc → "CẦN TÌM"). Kèm tool kiểm mọi phương trình có nhãn trong bản thảo
  có dòng trong bảng (gắn vào chuỗi kiểm P2). Các mục MOBADC lấy từ `docs/MOBADC_FIDELITY.md` (đã kiểm).
- [ ] Mục Giới hạn: những gì P2 không mô hình hoá, chỉ mô phỏng, các giới hạn đã tìm (góc lắc, cộng hưởng, gió rối gần biên).
- [ ] Code + dữ liệu công khai (repo), ghi commit hash của mọi kết quả.
- [ ] Thầy đọc bản thảo → sửa → nộp.

---

## E. CHƯƠNG TRÌNH GẶP THẦY (GĐ 0)

> *(đồng bộ 2026-09-25)* **Không áp dụng** — tác giả duy nhất (`ADVISOR_NOTES.md`). Giữ để truy vết: câu 1 đã
> quyết (P2, bỏ v1); câu 2 → tài liệu công bố; câu 3–6 bạn tự quyết.

Mang theo: kết quả SENS (−50.8% vững LOO), phép tách tắt tải, N4b (gió lên thân không có dư địa), kế hoạch này.

1. **Chuyển toàn bộ sang plant P2** (con lắc đơn 3D, lực cản bậc hai, động cơ, cảm biến) và bỏ v1 khỏi bài — thầy đồng ý?
2. **Tham số phần cứng:** hằng số thời gian động cơ, IMU, tần số điều khiển, cảm biến gió — lab có số thật không?
3. **IM-est** là đóng góp (chính hay phụ tuỳ kết quả gió) — thầy thấy đủ mới không?
4. **Tạp chí mục tiêu:** nhận bài mô phỏng + lý thuyết hay cần thực nghiệm / SITL?
5. **Phần lý thuyết:** thầy có hướng chứng minh ổn định nào gợi ý không?
6. **Thời hạn:** mốc nộp mong muốn?

---

## F. KHI GẶP SỰ CỐ

| sự cố | làm gì |
|---|---|
| `verify_repro` không REPRODUCED | dừng mọi thứ, gửi log cho Claude Code |
| gate trượt | không đọc số khác; gửi log |
| dry-run thiếu field-list | không chạy thật |
| batch báo lỗi giữa chừng | gửi log; chạy lại lệnh cũ nếu lỗi do mất điện |
| phân kỳ bất thường | ghi lại đoạn, quỹ đạo, τ; gửi Claude Code; không tự sửa |
| Claude Code đề xuất việc ngoài plan | hỏi: phục vụ mục tiêu nào? không rõ → không cho làm |
| kết quả "đẹp bất ngờ" | kiểm lại điều kiện (tập đoạn, K, τ, metric) trước khi tin |
| quá thời gian dự kiến 2 tuần ở một giai đoạn | bạn quyết: khai báo giới hạn hoặc tiếp tục *(đồng bộ)* |

---

## G. MỐC THỜI GIAN (thô, phụ thuộc GĐ 4)

| tuần | giai đoạn |
|---|---|
| 1 | GĐ 0–1 |
| 2–3 | GĐ 2 |
| 3–4 | GĐ 3–5 (+ GĐ 4 nếu cần: +0–2 tuần) |
| 5–7 | GĐ 6–7 |
| 8–10 | GĐ 8 |
| 11–15 | GĐ 9 |
| 16 | GĐ 10 |
| 17+ | GĐ 11 |

---

## H. BẢNG THEO DÕI NHANH

| GĐ | việc | trạng thái | ngày |
|---|---|---|---|
| 0 | tag v1-final ✔ · đồng bộ tài liệu ✔ · tải exploration · ~~gặp thầy~~ (bỏ) | ⬜ | |
| 1 | REGISTER_P2 §0 + PLANT_P2_SPEC approved | ⬜ | |
| 2a | V1–V7 PASS | ⬜ | |
| 2b | P2 chạy trong Simulink | ⬜ | |
| 3 | kiểm tra nội bộ · D1 | ⬜ | |
| 4 | sửa ESO (nếu cần) | ⬜ | |
| 5 | REGISTER_P2 approved | ⬜ | |
| 6 | τ\* + bảng chính · D2 | ⬜ | |
| 7 | gió + tải diện rộng · D3 (CỔNG G) | ⬜ | |
| 8 | IM-est · D4 | ⬜ | |
| 9 | lý thuyết · đối thủ · Monte Carlo · tài liệu | ⬜ | |
| 10 | CONFIRM2 | ⬜ | |
| 11 | viết · D5 · nộp | ⬜ | |
