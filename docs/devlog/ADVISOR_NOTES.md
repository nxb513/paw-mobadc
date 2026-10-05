# ADVISOR_NOTES — quyết định về tư cách tác giả và phạm vi

> Ghi theo lời user. Các file kế hoạch (`MASTER_PLAN.md`, `KE_HOACH_THUC_HIEN.md`, brief, `TEST_PLAN_v2.md`) tham
> chiếu file này thay cho mọi bước "hỏi thầy / gặp thầy / lab".

---

## 2026-09-25 — quyết định của user

1. **Tác giả duy nhất.** Không có thầy hướng dẫn hay phòng lab cung cấp thông số hoặc duyệt kết quả.
2. **Thông số lấy từ tài liệu công bố** (datasheet hãng, tài liệu nền tảng, bài báo), mỗi số ghi nguồn trong
   `PLANT_P2_SPEC.md` §2. Số không có nguồn công bố → "giả định" kèm dải độ nhạy lấy từ tài liệu.
3. **v1 bỏ khỏi bài.** Lưu trữ ở tag `v1-final` (`d3a7633`, tag object `fac19dba…`, đã lên remote). Mọi thứ
   cũ/sai bỏ (danh sách cắt đề xuất: `TEST_PLAN_v2.md` §0.2, chờ duyệt).
4. **Chỉ mô phỏng Simulink**, không bay thật, không SITL/HIL.
5. **Một máy** (máy của user chạy MATLAB) → ngân sách chạy đêm là ràng buộc khi thiết kế khối.

## Hệ quả cho kế hoạch (áp dụng ngay)

| chỗ cũ | thay bằng |
|---|---|
| GĐ0 "gặp thầy", KE_HOACH mục E | bỏ; các câu hỏi mục E do user tự quyết dựa trên tài liệu |
| "tham số phần cứng: hỏi thầy / lab" | tài liệu công bố (`PLANT_P2_SPEC.md` §2) |
| GĐ4 "quá 2 tuần → hỏi thầy" | quá 2 tuần → user quyết: khai báo giới hạn hoặc tiếp tục |
| D2 FAIL "xem lại hướng cùng thầy" | user tự xem lại hướng |
| GĐ9 lý thuyết "thầy duyệt" | user tự kiểm; Claude Code hỗ trợ suy dẫn và kiểm |
| GĐ11 chọn tạp chí, D5 "cùng thầy" | user quyết một mình |
| `PROTOCOL_LOCK.md` là tầng cao nhất | phạm vi v1 (lưu trữ ở `v1-final`); P2 do `docs/REGISTER_P2.md` quản lý |

Thứ bậc cho P2 từ nay: **`docs/REGISTER_P2.md` > `CLAUDE_CODE_BRIEF.md` > `MASTER_PLAN.md` > `KE_HOACH_THUC_HIEN.md`**.
`PROTOCOL_LOCK.md` chỉ quản lý các kết quả v1 đã lưu trữ.

## Lý do bỏ v1 (danh sách, cập nhật 2026-09-25)

1. Hai con lắc phẳng độc lập theo x, y (không phải con lắc cầu); mỗi trục mang đủ m_p g (AUDIT C2).
2. UAV không mang trọng lượng tải (`payload_z_on = 0`); bật `payload_z_on = 1` thì phân kỳ (`I-3.5`, `X-esoatt`).
3. Lực gió tuyến tính `K_w·w`, không có vận tốc tương đối; damping con lắc không là nội lực.
4. Không có trễ động cơ, cảm biến, rời rạc (hồi tiếp trạng thái sạch, liên tục).
5. **Lỗi dấu lực căng dây** trong `payload_pendulum_output.m` (+a·sinθ thay vì −a·sinθ): lực ngang lên UAV sai
   2·m_p·a·sin²θ (bậc θ²); kênh thẳng đứng bỏ hẳn số hạng này. Phát hiện bởi V2b (GĐ2a); chi tiết:
   `docs/REGISTER_ROBUST.md` §27. Code v1 **không sửa** (đóng băng ở `v1-final`).

