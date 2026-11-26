# Hướng dẫn chơi Chill Chill

## Điều khiển

| Phím | Tác dụng |
| --- | --- |
| W, A, S, D hoặc phím mũi tên | Di chuyển |
| 1 | Cuốc đất |
| 2 | Chọn gieo hạt |
| 3 | Bình tưới |
| 4 | Thu hoạch |
| Q | Đổi loại hạt đang chọn |
| Space hoặc Enter | Dùng công cụ lên ô đất trước mặt |
| E | Tương tác với vật nuôi, quầy hàng hoặc cửa nhà |
| M | Bật/tắt hiệu ứng âm thanh |
| B | Bật/tắt nhạc nền |
| Esc | Đóng cửa hàng |

Các nút công cụ và âm thanh cũng có thể bấm bằng chuột.

## Trồng trọt

1. Đứng cạnh một ô trong khu vườn, quay nhân vật về phía ô muốn chăm.
2. Nhấn 1 rồi Space để xới đất.
3. Nhấn Q để chọn hạt hợp mùa, nhấn 2 rồi Space để gieo.
4. Nhấn 3 rồi Space để tưới; mỗi luống chỉ cần tưới một lần trong ngày.
5. Về cửa nhà và nhấn E để ngủ. Mưa cũng tưới cây; ngủ hồi phục toàn bộ năng lượng.
6. Khi cây trưởng thành, nhấn 4 rồi Space để thu hoạch.
7. Đến quầy mái sọc và nhấn E để bán toàn bộ sản phẩm.

Một giờ trong game tương đương 18 giây ngoài đời. Ngày bắt đầu lúc 07:00; nhân vật tự ngủ khi tới 22:00.

## Lịch mùa vụ

Mỗi mùa kéo dài 7 ngày, cả năm có 28 ngày và mùa Xuân bắt đầu lại sau mùa Đông.

| Mùa | Có thể gieo |
| --- | --- |
| Xuân | Cà rốt, củ cải, dâu |
| Hạ | Dâu |
| Thu | Cà rốt, củ cải |
| Đông | Củ cải |

Cà rốt cần 3 ngày được tưới, củ cải 4 ngày và dâu 5 ngày. Cây không lớn ngoài mùa phù hợp. Cây mùa Đông cần hai ngày tưới để tăng một giai đoạn. Trời mưa tự tưới luống có cây; tuyết không tưới. Nông sản đặc trưng mùa nhận thêm 5 xu mỗi món nếu bán trong mùa có thưởng: cà rốt mùa Thu, dâu mùa Hạ, củ cải mùa Đông.

## Vật nuôi và cửa hàng

- Đến gần vật nuôi rồi nhấn E. Nếu còn thức ăn, nhân vật cho ăn; nếu hết thì vuốt ve. Tình bạn tăng, trái tim pixel hiện trên đầu con vật.
- Bò cho sữa, cừu cho len, các loài chim cho trứng tối đa một lần mỗi ngày.
- Quầy hàng cho phép bán tất cả sản phẩm, mua 5 hạt giống của loại đang chọn với giá 18 xu hoặc mua 3 bó thức ăn giá 12 xu.
- Nhấn Q ngay trong cửa hàng cũng đổi loại hạt đang mua.

## Âm thanh, nhạc và lưu tiến trình

M tắt/bật hiệu ứng riêng cho cuốc đất, gieo hạt, tưới, thu hoạch, tiếng từng nhóm vật nuôi, giao dịch và ngủ. B tắt/bật nhạc nền mà không tắt hiệu ứng.

Game tự lưu ngày, xu, năng lượng, hạt giống, sản phẩm trong túi, trạng thái luống và tình bạn với vật nuôi trong thư mục dữ liệu người dùng của Godot. Bản lưu không nằm cạnh tệp dự án.

## Chạy trong Godot

Mở project.godot bằng Godot 4.7 trở lên rồi nhấn F5. Chọn Project → Run nếu phím tắt trên máy đã được đổi. Đóng cửa sổ game để thoát.

## Chơi hai người trên cùng một máy

Nhấn F2 hoặc bấm nút "CHƠI 2 NGƯỜI" ở góc dưới bên trái để bật hoặc tắt chế độ hai người.

| Việc | Người 1 | Người 2 |
| --- | --- | --- |
| Di chuyển | W, A, S, D | Mũi tên |
| Chọn công cụ | 1, 2, 3, 4 | Numpad 1, 2, 3, 4 |
| Dùng công cụ | Space | Enter |
| Đổi loại hạt | Q | Numpad + |
| Tương tác (vật nuôi, quầy, cửa nhà) | E | Numpad 0 |

Hai người dùng chung vườn, chuồng, tiền, hạt giống và hàng trong túi. Năng lượng, công cụ và loại hạt đang chọn là riêng của từng người. Ngủ ở nhà sẽ hồi năng lượng cho cả hai. Thông báo trên màn hình có tên người thực hiện khi chế độ hai người đang bật.
