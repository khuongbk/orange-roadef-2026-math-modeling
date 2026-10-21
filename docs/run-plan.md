# Kế hoạch chạy Julia và thực nghiệm

Ngày lập: 2026-10-21. Xác minh pipeline trước, chạy thử có giới hạn, chỉ mở rộng sau khi kiểm tra nghiệm và mô hình.

## Đã hoàn thành

1. Julia 1.13.2, Python hệ thống 3.12.3; dependencies instantiate/precompile thành công. Giữ Manifest.toml để tái lập môi trường; không cập nhật packages giữa cùng một thực nghiệm. JSON3 có cảnh báo deprecated nhưng không gây lỗi mẫu.
2. Inventory: đủ 20 instances / 60 JSON. Python: 2 tests qua. Julia: 6 assertions qua, gồm forwarding và MILP hai thời kỳ với budget 0.
3. Audit SetA-01 cả hai thời kỳ: baseline không waypoint t=0 = 1.0000006861063466; t=1 = 0.5663266666666666. Arc ID 22 bị ngắt ở t=1.
4. Chạy mẫu SetA-01, `single`, `path_uniform`, seed 1, một luồng, giới hạn solver 60 giây. Đối chiếu độc lập bằng Python đủ 40 tuyến; tất cả qua.

| Đại lượng mẫu một thời kỳ | Kết quả |
|---|---:|
| Nút / cung / demands | 20 / 80 / 40 |
| Biến nhị phân / tổng biến | 15,200 / 16,001 |
| Trạng thái | OPTIMAL |
| MLU / cận tốt nhất | 0.929383899821109 |
| Gap | 0% |
| Giảm MLU so với baseline | 7.0617% |
| Tiền xử lý | 0.120 s |
| Dựng mô hình | 5.445 s |
| optimize! wall elapsed | 2.730 s |
| Thời gian ghi trong script, sau imports | 19.746 s |

Giới hạn 60 giây chỉ áp dụng solver, không bao gồm toàn bộ pipeline. Lượt đầu có chi phí JIT; các thời gian trên không phải benchmark trung bình. HiGHS báo khoảng 1 giây nội bộ, khác đồng hồ bao quanh optimize!. Timer của script không bao gồm khởi động Julia/imports.

Chỉ một demand dùng một waypoint. MLU 0.929384 tương đương tải lớn nhất khoảng 92.94% dung lượng cung.

Artifacts: [JSON](../results/raw/smoke-2026-10-21/setA-01-1period-seed1-path_uniform.json), [audit baseline](../results/data-audit.json), [summary](../results/tables/summary.csv).

## Chạy tiếp — đề xuất, chưa thực hiện

1. **SetA-01 hai thời kỳ:** giới hạn 60 giây, seed 1, một luồng, `path_uniform`; lưu JSON riêng. Kiểm tra tải arc bị ngắt, `budget_used_1`, độ dài tuyến và MLU bằng Python độc lập. Nếu hết giờ phải ghi rõ có/không incumbent, cận và gap.
2. **Tăng quy mô:** SetA-02 rồi SetA-03 một thời kỳ, mỗi mẫu 60 giây; thử hai thời kỳ nếu dựng mô hình vừa RAM và có nghiệm. Đánh giá từng lượt trước khi chuyển mẫu, không khởi chạy batch dài ngay.
3. **Đóng gói kiểm tra:** chuyển route check ad-hoc thành script nhận prefix + JSON, lưu báo cáo, bổ sung regression tests trước thực nghiệm chính thức.
4. **Chốt với thầy:** mục tiêu MLU hay từ điển đầy đủ, cấm lặp waypoint và cách đếm thay đổi giữa thời kỳ. Nếu cần sửa, cập nhật mô hình, code và tests đồng thời.
5. **Đánh giá scaling:** ước lượng số biến trước mỗi mẫu, đo dựng mô hình/RAM. Guard hiện từ chối trên 1,000,000 biến nhị phân ước lượng. Không bỏ guard để chạy mù; nghiên cứu sparse/candidate-path hoặc decomposition khi vượt giới hạn.
6. **Thực nghiệm chính thức:** chỉ chạy Step 6/9 sau các kiểm tra trên. Config hiện 20 instances × 10 repetitions: ngân sách solver tối đa 100 giờ + 200 giờ, chưa tính preprocessing/build. Chạy tuần tự, giữ JSON, logs lỗi, coverage và summary. Không khẳng định dense baseline giải được toàn bộ 20 instances.

## Điều kiện đưa kết quả vào báo cáo

- Có JSON, thiết lập, phiên bản môi trường, nghiệm khả thi và kiểm tra độc lập.
- Phân biệt OPTIMAL với TIME_LIMIT có incumbent; không coi thiếu incumbent là MLU 0.
- Chỉ gọi tối ưu đối với mô hình đã giải. Mẫu hiện là **MLU baseline**, không chứng minh tối ưu mục tiêu từ điển đầy đủ của đề.
- Trung bình cần nhiều lượt thật cùng số samples và thất bại; một smoke run không đại diện hiệu năng toàn bộ SetA.