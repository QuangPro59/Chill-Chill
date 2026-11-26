# Chill Chill x Seasons Gone

Hai game Godot trong một project: mở `project.godot` bằng Godot 4.7 (hoặc mới hơn) rồi nhấn F5.

Menu đầu tiên cho chọn:

1. **Chill Chill** (thư mục `chill_chill/`) — nông trại bốn mùa, vật nuôi, chơi 2 người cùng máy (F2).
2. **Seasons Gone** (các thư mục gốc: `world/`, `crops/`, `player/`, `ui/`...) — luân canh, chu trình nitơ, sâu bệnh.

Nhấn **F10** khi đang chơi để quay lại menu chọn game.

Ghi chú kỹ thuật:

- `game_switcher.gd` (autoload `GameSwitcher`) chuyển cảnh, đổi độ phân giải (Chill Chill 1280x720, Seasons Gone 640x360) và bật/tắt nhạc của Seasons Gone.
- Lần mở đầu tiên Godot sẽ tự nhập lại (import) toàn bộ ảnh và âm thanh, mất vài chục giây.
- Tài liệu riêng: `chill_chill/README.md`, `chill_chill/HUONG_DAN.md`, `README_SEASONS_GONE.md`.
- Giấy phép: Seasons Gone theo `LICENSE` (gốc); nguồn tài nguyên Chill Chill ở `chill_chill/ASSET_CREDITS.md`.

## Đã ghép vào Seasons Gone (từ Chill Chill)

**Bốn mùa** (`season/`): mỗi mùa có hiệu ứng riêng, thấy rõ ngay từ đầu.

- Xuân: cánh hoa bay, viền hồng nhẹ, cây cỏ xanh tươi.
- Hạ: nắng và tia sáng, đom đóm lấp lánh; tháng hạn hán có bụi và ánh cam nóng.
- Thu: lá vàng/đỏ/cam rơi, cây và cỏ trên bản đồ chuyển sang màu thu.
- Đông: tuyết rơi, viền sương giá, cây và cỏ phủ tuyết.
- Thời tiết ngẫu nhiên mỗi tháng (nắng, mưa, tuyết, sương giá, hạn hán); mưa làm cảnh tối và ẩm hơn. Khi sang mùa mới có dòng chữ thông báo giữa màn hình.
- Phím xem thử: **F3** nhảy sang mùa kế tiếp, **F4** đổi kiểu thời tiết.
- Phần này chỉ là hiệu ứng, không đổi công thức sinh trưởng của cây.

**Chơi 2 người** (`coop/`): nhấn **F2** để bật/tắt.

- Người 1: WASD để đi, chuột để trồng/nhổ, phím 1-0 chọn cây (như cũ).
- Người 2: phím mũi tên để đi, `/` hoặc Numpad 0 trồng, `.` hoặc Numpad . nhổ, `[` `]` (hoặc Numpad - +) đổi cây. Ô đích là ô trước mặt, có khung xanh đánh dấu.
- Chung vườn, kho và tiền; camera tự thu nhỏ khi hai người đi xa nhau.
