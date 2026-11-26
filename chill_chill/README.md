# Chill Chill — Nông trại bốn mùa

Chill Chill là game nông trại 2D pixel art góc nhìn từ trên xuống, viết bằng GDScript cho Godot 4.7 trở lên. Game có nhân vật nông dân nữ, đàn vật nuôi hoạt ảnh, cây trồng theo mùa, thời tiết, nhạc nền vòng lặp và hiệu ứng âm thanh theo hành động.

## Mở game

1. Cài Godot Engine 4.3 trở lên.
2. Trong Godot Project Manager chọn Import, rồi mở tệp project.godot trong thư mục dự án.
3. Nhấn F5 để chạy game chính. Nhấn F6 để chạy cảnh hiện tại.

Trên Windows có thể dùng CHAY_GAME.bat nếu lệnh godot hoặc godot4 đã nằm trong PATH.

## Chơi nhanh

- Di chuyển tới vườn và đứng sát một ô đất, quay mặt về ô đó.
- Dùng 1 để cuốc, 2 để gieo, 3 để tưới, 4 để thu hoạch; nhấn Space để dùng công cụ.
- Nhấn Q để đổi loại hạt. Gieo loại cây hợp mùa rồi tưới cây mỗi ngày.
- Nhấn E cạnh cửa nhà để ngủ; ngày mới hồi năng lượng và cây được tưới sẽ lớn.
- Nhấn E cạnh quầy để bán nông sản hoặc mua hạt giống và thức ăn.
- Đến gần con vật, nhấn E để cho ăn, vuốt ve và nhận sản phẩm.
- Game tự lưu ngày, tiền, hạt giống, nông sản, luống cây và tình bạn với vật nuôi.

## Chơi hai người trên cùng một máy

Nhấn F2 hoặc bấm nút "CHƠI 2 NGƯỜI" ở góc dưới bên trái để bật hoặc tắt chế độ hai người.

- Người 1: W A S D di chuyển, 1–4 chọn công cụ, Space dùng công cụ, Q đổi hạt, E tương tác.
- Người 2: mũi tên di chuyển, Numpad 1–4 chọn công cụ, Enter dùng công cụ, Numpad + đổi hạt, Numpad 0 tương tác. Cần bật NumLock để dùng Numpad.
- Vườn, chuồng, tiền, hạt giống và hàng trong túi dùng chung. Năng lượng, công cụ và loại hạt đang chọn là riêng của từng người. Ngủ ở nhà hồi năng lượng cho cả hai.
- Khi tắt chế độ hai người, một người chơi vẫn dùng được cả hai bộ phím.
- Camera tự thu nhỏ khi hai người đi xa nhau. Dấu tam giác vàng trên đầu là Người 1, dấu xanh là Người 2.
- Nút công cụ bằng chuột trên HUD chỉ đổi công cụ cho Người 1.

## Bốn mùa

Mỗi mùa kéo dài 7 ngày; bốn mùa tạo thành một năm. Mùa và thời tiết thay đổi màu cỏ, tán cây, mặt hồ và khung trời. Mưa tự tưới cây; tuyết phủ vườn vào mùa đông.

- Xuân: cà rốt, củ cải, dâu.
- Hạ: dâu.
- Thu: cà rốt, củ cải.
- Đông: củ cải; cây lớn chậm hơn, cần hai lần tưới ngày để tăng một giai đoạn.

Cà rốt cần 3 ngày tưới, củ cải 4 ngày và dâu 5 ngày. Nông sản đặc trưng mùa được cộng 5 xu mỗi món khi bán trong đúng mùa.

## Âm thanh

- Bật/tắt hiệu ứng bằng M.
- Bật/tắt nhạc nền bằng B.
- Nhạc Chill Chill là một vòng giai điệu thư giãn được tổng hợp riêng cho dự án. Mỗi công cụ, vật nuôi, giao dịch và lúc ngủ có âm thanh riêng.

## Tệp chính

- project.godot — cài đặt dự án.
- main.tscn — cảnh game.
- main.gd — bản đồ, nhân vật, mùa vụ, vật nuôi, giao diện và lưu tiến trình.
- sky_card.gd — khung trời pixel đổi theo mùa, thời tiết và giờ trong ngày.
- assets — sprite cây, sprite vật nuôi, nhạc nền và hiệu ứng âm thanh.
- HUONG_DAN.md — hướng dẫn chơi chi tiết.
- ASSET_CREDITS.md — nguồn và ghi chú giấy phép.

Game không cần plugin hoặc kết nối mạng.
