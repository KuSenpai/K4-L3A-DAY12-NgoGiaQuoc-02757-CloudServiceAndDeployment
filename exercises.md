# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder "Câu trả lời của bạn" bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Ngô Gia Quốc  Mã học viên: 2A202602757

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi deploy lên Railway, nếu quên set `AGENT_API_KEY` thì app báo
> `ValidationError` và deploy fail ngay, mình thấy lỗi trong build log và sửa
> luôn. Nếu mặc định là `"changeme"`, app vẫn chạy "bình thường" trên URL
> public, ai đoán được `changeme` (khóa mặc định rất dễ đoán) là gọi `/ask`
> miễn phí bằng tiền của mình — và mình chỉ biết khi nhìn hóa đơn.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T10:09:15.860485+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
> 1. Lọc/tổng hợp theo trường: ví dụ cộng `cost_usd` theo `user_id` để biết
>    user nào tiêu nhiều tiền nhất hôm nay.
> 2. Đếm và cảnh báo: đếm số dòng `level="error"` trong 5 phút để tính tỷ lệ
>    lỗi và đặt alert. (Railway còn tự tách các trường này ra để lọc.)

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh ~1.46GB, gần hết là base image: `python:3.11` bản đầy đủ chứa sẵn
> compiler (gcc), header, git, thư viện dev của Debian… mà lúc chạy app không
> cần. Bản multi-stage dùng `python:3.11-slim` và chỉ copy `/install` (thư
> viện đã cài) từ stage builder sang. `docker history` cho thấy layer
> `pip install` của bản đầu nặng 95MB vì còn giữ cache pip; bản mới dùng
> `--no-cache-dir` nên bỏ được phần đó.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Mình đổi `SERVICE_VERSION` trong `main.py` rồi build lại: các layer
> `COPY requirements.txt`, `RUN pip install`, `useradd`,
> `COPY --from=builder /install` đều `CACHED`; chỉ `COPY app` và `COPY utils`
> chạy lại (mất ~0.1s). Nếu `COPY . .` đứng trước `pip install` thì sửa một
> ký tự cũng làm layer COPY đổi → mọi layer sau nó mất cache → cài lại toàn bộ
> thư viện mỗi lần build.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Lỗ hổng trong code (vd. thư viện bị RCE) → kẻ tấn công chạy lệnh trong
> container với quyền của process → nếu là root thì đọc/sửa được mọi file,
> cài tool, và root trong container cũng là uid 0 trên host → chỉ cần thêm
> một lỗi cấu hình (mount volume, docker socket, lỗ hổng kernel) là thoát ra
> thành root trên host. `USER appuser` cắt ở bước 2: process chỉ là uid 10001
> không có quyền gì, nên leo thang khó hơn nhiều.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa 20 request: gửi 10 request lúc 10:00:59 (hết quota phút 10:00), rồi
> bộ đếm reset lúc 10:01:00, gửi tiếp 10 request lúc 10:01:01. Sliding window
> luôn nhìn 60 giây gần nhất nên lúc 10:01:01 vẫn thấy 10 request cũ → chặn 429.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn **số request trong thời gian ngắn** (429), cost guard
> giới hạn **tổng tiền trong tháng** (402).
> - Rate limit cho qua, cost guard chặn: user gọi đều 5 request/phút nhưng
>   mỗi câu hỏi rất dài (nhiều token), sau vài ngày tổng chi phí vượt $10.
> - Rate limit chặn, cost guard cho qua: một script spam 50 câu "hi" trong 1
>   phút — rất rẻ, còn xa ngân sách, nhưng vượt 10 request/phút nên bị 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis mất kết nối → cả 3 container cùng trả 503 ở health check.
> 2. Orchestrator coi cả 3 là "chết" → restart cả 3 cùng lúc.
> 3. Trong lúc khởi động lại không có container nào phục vụ → toàn bộ service
>    sập, kể cả những request không cần Redis.
> 4. Redis quay lại sau 30s nhưng container vẫn đang restart → downtime kéo dài
>    hơn sự cố gốc. Tách ra thì chỉ `/ready` 503 → LB tạm ngừng gửi traffic,
>    không restart, Redis về là phục vụ lại ngay.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với Redis, mình gọi 3 lần cùng user và thấy `history_length` tăng đều
> 0 → 2 → 4 (mình chạy với compose 1 agent và trên Railway; scale 3 chưa chạy
> được vì compose map cố định cổng 8000:8000). Nếu dùng dict, mỗi container
> có dict riêng nên con số nhảy lung tung tùy request rơi vào container nào,
> vd. 0 → 0 → 2 → 0 → 4, và mất sạch khi container restart.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi: `railway login` báo
> `invalid peer certificate: UnknownIssuer`, sau đó pytest CP5 cũng báo
> `CERTIFICATE_VERIFY_FAILED`, dù mở URL trên trình duyệt vẫn được.
> Tìm nguyên nhân: đổi mạng vẫn lỗi nên nghi do máy; xem issuer của chứng chỉ
> mà Python nhận được thì là `Avast Web/Mail Shield Root` — Avast giải mã
> HTTPS rồi ký lại, trình duyệt tin vì Avast cài root vào kho Windows, còn
> CLI/Python dùng bộ CA riêng nên không tin.
> Sửa: chạy lệnh trong terminal không bị conda đặt `SSL_CERT_FILE` để login
> Railway; khi chạy test thì trỏ `SSL_CERT_FILE` tới bundle có thêm root của
> Avast (hoặc tắt HTTPS scanning của Avast).
