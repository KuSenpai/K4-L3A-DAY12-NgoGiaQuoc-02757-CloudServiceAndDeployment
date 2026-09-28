# Thông Tin Deploy — Checkpoint 5

> `pytest tests/test_cp5.py` đọc file này để tìm địa chỉ service và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Ngô Gia Quốc |
| Mã học viên | 02757 |
| Repo | https://github.com/KuSenpai/K4-L3A-DAY12-NgoGiaQuoc-02757-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-production-78ea.up.railway.app |
| Platform | Railway (build từ `Dockerfile`, cấu hình trong `railway.toml`) |
| Ngày deploy | 2026-09-28 |

Project Railway `day12-agent` gồm 2 service:

- `day12-agent` — web service build từ Dockerfile, domain công khai ở trên
- `Redis` — Redis database của Railway, chỉ truy cập qua mạng nội bộ

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Railway tự gán, không set tay |
| `AGENT_API_KEY` | ✅ | đặt bằng `railway variables`, không nằm trong repo |
| `REDIS_URL` | ✅ | tham chiếu `${{Redis.REDIS_URL}}` tới Redis service của Railway |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

```bash
URL=https://day12-agent-production-78ea.up.railway.app

# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i $URL/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i $URL/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST $URL/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Chạy ngày 2026-09-28 vào bản deploy trên Railway:

```
--- /health
{"status":"ok","service":"day12-agent","version":"1.0.0"} [200]

--- /ready
{"status":"ready","redis":true} [200]

--- /ask không có key
{"detail":"invalid or missing API key"} [401]

--- /ask sai key
{"detail":"invalid or missing API key"} [401]

--- /ask có key
{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.","user_id":"cp5-check-1790587241","history_length":0,"cost_usd":2.145e-05,"tokens":{"in":3,"out":35}} [200]

--- rate limit: 14 lần tiếp theo cùng user (tổng 15 request, hạn mức 10/phút)
200 200 200 200 200 200 200 200 200 429 429 429 429 429
```

Request thứ 1–10 được phục vụ, từ request thứ 11 trả `429` — đúng hạn mức
`RATE_LIMIT_PER_MINUTE=10` với sliding window lưu trong Redis của Railway.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên Railway
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
