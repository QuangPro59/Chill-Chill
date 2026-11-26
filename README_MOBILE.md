# Nông trại đôi — bản mobile cho cặp đôi

Game nông trại thư giãn dành cho hai người chơi chung một thiết bị (điện thoại hoặc máy tính bảng, nằm ngang). Nền tảng là Seasons Gone, thêm bốn mùa, chơi 2 người và điều khiển cảm ứng.

## Cách chơi trên điện thoại

- **Cần điều khiển trái (xanh):** Người 1 di chuyển. **Cần phải (hồng):** Người 2 di chuyển.
- Mỗi người có 3 nút: **Trồng**, **Nhổ**, **Đổi cây**. Cây được trồng vào ô ngay trước mặt nhân vật, có khung màu đánh dấu ô đó.
- Người 1 có thể chạm thẳng vào ô đất gần mình để trồng; chạm vào thanh cây phía dưới để chọn loại cây.
- Nút **NEXT MONTH** ở góc phải trên để sang tháng mới (cây lớn, mùa và thời tiết đổi).
- Lần đầu vào game sẽ hỏi tên hai người (mặc định "Anh" và "Em"), tên hiện trên đầu nhân vật.

## Thanh gắn kết

Thanh trái tim ở giữa phía trên tăng khi hai người đứng gần nhau (và +10 mỗi lần sang tháng). Mỗi 100 điểm lên một cấp và nhận 50 tiền. Điểm được lưu tự động, không có thua cuộc hay áp lực thời gian.

## Chạy thử trên máy tính

- Mở `project.godot` bằng Godot 4.7+, nhấn F5. Bàn phím: P1 WASD, E trồng, Q nhổ, Z/C đổi cây (hoặc chuột); P2 mũi tên, `/` trồng, `.` nhổ, `[` `]` đổi cây. F2 bật/tắt người chơi thứ hai.
- Muốn thấy cần điều khiển cảm ứng trên máy tính: Project Settings → Input Devices → Pointing → bật **Emulate Touch From Mouse** (và tắt **Emulate Mouse From Touch** khi thử).
- F10 quay lại menu chọn game cũ (có cả Chill Chill, chỉ chơi được bằng bàn phím).

## Xuất ra Android

1. Cài Godot export templates (Editor → Manage Export Templates), JDK 17 và Android SDK, rồi khai báo đường dẫn trong Editor → Editor Settings → Export → Android.
2. Project → Export → Add… → Android. Tạo hoặc chọn debug keystore.
3. Chọn kiến trúc arm64-v8a, bật export APK hoặc AAB, nhấn Export Project (hoặc cắm điện thoại và dùng Remote Debug).
4. Project đã đặt sẵn hướng ngang, giữ màn hình sáng, nén ảnh ETC2/ASTC và bộ vẽ GL Compatibility cho máy yếu.

Ghi chú: thư mục `addons/` (bảng điều khiển debug Panku, không dùng) đã được bỏ để nhẹ bản cài.
