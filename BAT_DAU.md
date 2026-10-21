# Bắt đầu cùng bộ khung này

## Đã chạy mẫu trên máy anh — 2026-10-21

- Julia 1.13.2; dependencies cài thành công, đã có `Manifest.toml`.
- Kiểm kê đủ 20 instances; Python 2/2 tests qua; Julia 6/6 assertions qua.
- SetA-01, `single`, `path_uniform`, seed 1, một luồng, giới hạn solver 60 giây: **OPTIMAL**, gap 0%.
- MLU = **0.929383899821109**; baseline không waypoint = 1.0000006861063466; giảm **7.06%**.
- Đủ 40 tuyến qua kiểm tra Julia và đối chiếu Python độc lập.
- [JSON mẫu](results/raw/smoke-2026-10-21/setA-01-1period-seed1-path_uniform.json), [bảng tổng hợp](results/tables/summary.csv), [kế hoạch chạy tiếp](docs/run-plan.md).

Đây là tối ưu của mô hình MLU baseline hiện tại, chưa phải mục tiêu từ điển đầy đủ. Chưa chạy batch Step 6/9 hay mẫu thực tế hai thời kỳ. Không cần cài lại dependencies cho mỗi lượt chạy.

1. Giải nén; mở terminal tại thư mục dự án.
2. Cài Julia (1.10 trở lên) và Python 3 nếu chưa có.
3. Chạy lần lượt:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
python3 scripts/inventory.py
python3 -m unittest discover -s test -p 'test_*.py' -v
julia --project=. test/runtests.jl
julia --project=. scripts/run.jl data/raw/SetA/setA-01 single 60 1 path_uniform
```

Gửi lại log của lệnh Julia đầu tiên bị lỗi; nếu tất cả qua, gửi JSON trong `results/raw/` để mình kiểm tra nghiệm và viết phần kết quả.

## Làm song song mô hình, code và báo cáo

- Mỗi thay đổi công thức: cập nhật `docs/model-t0.md`, rồi `src/OrangeASR.jl`.
- Mỗi lần chạy: giữ JSON gốc; tổng hợp bằng `python3 scripts/summarize.py`.
- Mỗi kết luận: ghi căn cứ vào `docs/progress.md`, đưa nội dung đã xác minh vào `report/report.md`.
- Trước thực nghiệm dài: xác nhận mục tiêu MLU, giả thiết tuyến không lặp waypoint và phạm vi Step 9 với thầy.

