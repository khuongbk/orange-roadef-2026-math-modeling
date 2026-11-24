# Bước 4 — section Data đọc đủ ba JSON, kỳ 0

## Đang làm bước nào?

Bước 2 và 3 đã được kiểm tra trên setA-09 và setA-14 bằng các HTML anh gửi.
Bước 4 ghép các dữ liệu cần cho mô hình: r(i,j,a,0), c(a), v(d,0), MaxSeg.
Chưa chạy solver hoặc thí nghiệm. Làm trên local trong Pluto như bước 3.

## Cách chạy

1. Giải nén và giữ nguyên cả thư mục `step04_data/`.
2. Trong Pluto, mở `Step04_setA09_Data.jl`.
3. Cần thấy:
   - `data_selftest_passed = true`
   - `data_reference_check.status = "PASSED"`
   - `data_evidence.status = "SAVED"`
4. Mở và chạy tương tự `Step04_setA14_Data.jl`.
5. Export hai HTML, lưu vào folder bằng chứng bước 4 của anh (`results/step4/` trong repo nếu anh tiếp tục cách tổ chức hiện tại).
6. Gửi HTML để kiểm tra trước khi chốt bước 4 và chuyển bước 5.

Không cần copy code thủ công hoặc thêm package ngoài JSON3 đã dùng ở bước 3.
Không sửa notebook/HTML bằng chứng của bước 2–3.

## Kết quả cần thấy

| Instance | Đỉnh | Cung | Demand | MaxSeg |
|---|---:|---:|---:|---:|
| setA-09 | 150 | 750 | 200 | 6 |
| setA-14 | 250 | 1.108 | 600 | 6 |

`data_reference_check` kiểm tra toàn bộ capacity/metric và toàn bộ traffic/endpoints kỳ 0, ID gốc, MaxSeg và SHA256 cả ba JSON. Một số hệ số r và hệ số tải chuẩn hóa v*r/c cũng được đối chiếu với Python độc lập.

## Mapping Data

| Đầu vào | Tham số |
|---|---|
| net.nodes, net.links | V, A, ID gốc, metric và capacity c(a) |
| Tính shortest paths trên graph kỳ 0 | r(i,j,a,0), dùng lại OrangeR đã kiểm tra ở bước 3 |
| tm.demands[k].v[1] trong Julia | v(d,0), demand ID d=k-1 |
| scenario.max_segments | MaxSeg |

Metric dùng tính shortest paths; capacity dùng chia tải. Không thay thế hai đại lượng cho nhau.
Kỳ 0 lấy phần tử thứ nhất của vector traffic. Intervention kỳ sau được lưu lại, không xóa cung tại kỳ 0. Không đưa budget vào mô hình kỳ 0.

## Giao diện tái sử dụng cho bước 5

```julia
M = include("OrangeParameters.jl")
D0 = M.load_parameters("data/setA-09")
D0.c[a]                   # capacity, original physical arc ID
D0.v[(d,0)]               # period-0 traffic, zero-based demand ID
D0.MaxSeg
M.r(D0,i,j,a,0)           # exact path-uniform coefficient
M.load_coefficient(D0,d,i,j,a)  # v(d,0)*r(i,j,a,0)/c(a)
```

Hệ số r được tính theo truy vấn từ các bảng distances/path counts, không dựng tensor đặc. Không coi cặp không có đường đi là segment miễn phí.
Không sửa hoặc thay solver v6/v7 hiện có; bước 5 sẽ xác định cách đưa Data này vào mô hình được kiểm thử.

## File được tạo khi chạy Julia

Trong thư mục đã giải nén:

- `results/step04/setA-09-data-summary.json`
- `results/step04/setA-09-capacity.csv`
- `results/step04/setA-09-traffic0.csv`
- Ba file tương ứng cho setA-14.

Lưu kèm cả folder code/data để chạy lại được. Các CSV có hậu tố `reference` là bản Python tính sẵn; chúng không phải bằng chứng rằng Julia đã chạy thành công.

## Phạm vi kiểm tra hiện tại

- Python đã kiểm tra hai bộ dữ liệu ba JSON, tạo tham chiếu chính xác cho toàn bộ capacity và traffic kỳ 0.
- Test Python đã qua: lấy đúng kỳ 0 thay vì kỳ 1, v*r/c, capacity không hợp lệ, traffic âm/sai độ dài, ID sai và intervention sai.
- `OrangeR.jl` giữ nguyên byte so với gói bước 3 anh đã chạy thành công.
- Máy tạo gói chưa có Julia: module ghép Data và notebook bước 4 vẫn cần chạy các cell kiểm tra trên local trước khi đánh dấu hoàn thành.
- `results/SetA_instance_sizes.csv` có kích thước 20 SetA lấy từ JSON. Chưa tuyên bố đã chạy notebook Julia cho cả 20 instance.

## Tái tạo tham chiếu Python (tùy chọn)

```bash
python3 build_reference.py
python3 -m unittest discover -s tests -p 'test_*.py'
```
