# Bước 3 — tính r(i,j,a,0), chạy local trong Pluto

## Mình đang làm gì?

Bước 2 đã có hai bản HTML chạy hết, không lỗi: setA-09 (150 đỉnh, 750 cung) và setA-14 (250 đỉnh, 1.108 cung).
Bước 3 tính tỷ lệ lưu lượng trên từng cung vật lý của mỗi segment, theo calculating_r.pdf. Chưa chạy mô hình tối ưu hoặc benchmark.

## Cách chạy — chỉ cần giải nén và mở notebook

Giữ nguyên toàn bộ thư mục sau khi giải nén. Gói có sẵn hai net JSON đúng dữ liệu đã dùng để tính tham chiếu.

1. Trong Pluto local đang mở, chọn Open notebook → `Step03_setA09_r.jl`.
2. Chạy các cell và đợi phần Step 3 cuối notebook.
3. Kiểm tra `r_selftest_passed = true` và `r_reference_check.status = "PASSED"`.
4. Làm tương tự với `Step03_setA14_r.jl`.
5. Export HTML cho từng notebook và giữ file `.jl`. Gửi HTML để kiểm tra trước khi chốt bước 3.

Hai notebook mở rộng từ SOURCE nhúng trong hai bản HTML đã kiểm tra sạch lỗi của anh. Bản gốc không bị sửa.
Không cần copy code vào cell, cài solver, SSH hoặc dùng server.

Nếu notebook chỉ file JSON của anh ở thư mục khác, hãy trỏ lại file JSON trong cùng thư mục với notebook để khớp dữ liệu tham chiếu. Không thay riêng notebook mà bỏ quên `OrangeR.jl` và thư mục `results/`.

## Kết quả đã tính bằng Python độc lập

| Instance | Cặp đỉnh khác nhau có đường đi | Hệ số r khác 0 | Cặp có nhiều đường ngắn nhất |
|---|---:|---:|---:|
| setA-09 | 22.350 | 85.643 | 122 |
| setA-14 | 62.250 | 375.560 | 30 |

Mỗi cặp có đường đi đã qua kiểm tra chính xác: bảo toàn luồng từ nguồn đến đích, 0≤r≤1 và tổng r×metric bằng chiều dài đường ngắn nhất.
Python cũng đã được so sánh với liệt kê đường độc lập trên 600 cặp đỉnh graph nhỏ, gồm cung song song, metric thập phân và cặp không có đường đi.

**Giới hạn:** Máy tạo gói không có Julia. Phần Python đã chạy và kiểm tra; phần Julia mới chưa được thực thi ở đây. Notebook có selftest và đối chiếu tất cả khoảng cách/số đường cùng 20–21 cặp hệ số với bản Python. Vì vậy chưa tự đánh dấu bước 3 hoàn thành trước khi notebook local qua test.

## Công thức đúng theo PDF

Với a=(u,v), nếu dist(i,u)+metric(a)+dist(v,j)=dist(i,j), thì:

`r(i,j,a,0) = sigma(i,u) * sigma(v,j) / sigma(i,j)`.

Ngoài trường hợp đó, r=0. Sigma đếm số đường ngắn nhất; mỗi cung vật lý song song có ID riêng. Không gộp capacity hoặc làm mất các cung trước khi đếm đường.

Dijkstra chỉ đếm đường, không liệt kê chúng. Metric thập phân được scale chính xác thành số nguyên; khoảng cách và số đường dùng BigInt; r dùng Rational{BigInt}.
Quy tắc này là path-uniform theo calculating_r.pdf, không phải khẳng định nó luôn giống ECMP chia đều next-hop.

## Kết quả nằm đâu?

- `results/setA-09-r0-nonzero.csv`, `results/setA-14-r0-nonzero.csv`: **toàn bộ hệ số r khác 0 đã tính**, không phải chỉ vài mẫu.
- Cột CSV: i, j, arc_id, r_numerator, r_denominator. Tất cả là ID gốc; r = numerator/denominator.
- `results/*-shortest-data.csv`: tất cả khoảng cách, số đường và reachability của cặp đỉnh khác nhau.
- `results/*-r0-summary.json`: số đỉnh/cung, số hệ số, số cặp và các kiểm tra.
- Notebook local tự lưu thêm JSON/CSV bằng Julia vào `results/step03/` cạnh net JSON.
- `r0(i,j,a)` trong notebook truy vấn hệ số theo original IDs. Cặp không có đường đi bị từ chối, không coi r=0 là segment khả thi.
- `r_example` chọn cặp có số đường ngắn nhất lớn nhất để hiển thị hệ số chính xác.

CSV hệ số bỏ các giá trị 0 để tiết kiệm dung lượng. Chỉ diễn giải một hệ số vắng mặt là 0 khi cặp (i,j) có đường đi. Các trường hợp i=j không được dùng làm segment.

Để xuất toàn bộ r bằng Julia lần nữa, đổi `full=false` thành `full=true` ở cell `r_evidence`; có thể tốn thêm thời gian. Không bắt buộc làm việc này để xem hệ số hoặc chạy đối chiếu tham chiếu.

## Cách tái tính bằng Python (tùy chọn)

Không cần cài thêm package Python:

```bash
python3 compute_r.py setA-09-net.json --output results/recomputed
python3 compute_r.py setA-14-net.json --output results/recomputed
python3 -m unittest discover -s tests -p 'test_*.py'
```

Thời gian trong JSON là preprocessing của bước 3, không phải thời gian optimize! của thực nghiệm.
