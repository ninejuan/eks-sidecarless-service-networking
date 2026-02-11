FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY main.py ./
COPY src ./src

EXPOSE 8082

CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8082"]
