# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   Stage 1 `builder`: cài dependency vào /install (có thể cần compiler)
#   Stage 2 `runtime`: chỉ copy kết quả đã cài + source, chạy bằng user thường
#
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder ───────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ copy requirements.txt trước: layer pip install được cache, sửa code
# không làm cài lại thư viện.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ───────────────────────────────────────────────
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# User thường, không có quyền root trong container
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Chỉ mang sang thư viện đã cài, không mang compiler/cache của builder
COPY --from=builder /install /usr/local

# Source code copy SAU cùng — thay đổi thường xuyên nhất
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser utils ./utils

USER appuser

EXPOSE 8000

# Shell form để ${PORT} được mở rộng lúc chạy (platform có thể gán cổng khác)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT', '8000') + '/health', timeout=4).read()" || exit 1

# 0.0.0.0 để bên ngoài container gọi vào được; ${PORT:-8000} vì cloud tự gán cổng
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
