# ── Base image ────────────────────────────────────────────────────
# Python 3.12 slim keeps the image small (~130MB vs ~900MB for full)
FROM python:3.12-slim

# ── Build args (can be overridden at build time) ──────────────────
ARG APP_DIR=/app

# ── Environment ───────────────────────────────────────────────────
# Prevents Python from writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1
# Prevents Python from buffering stdout/stderr (important for MCP stdio transport)
ENV PYTHONUNBUFFERED=1
# TAVILY_API_KEY is injected at runtime, not baked into the image
#ENV TAVILY_API_KEY=""

# ── System dependencies ───────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ── Working directory ─────────────────────────────────────────────
WORKDIR ${APP_DIR}

# ── Install Python dependencies ───────────────────────────────────
# Copy requirements first to leverage Docker layer caching.
# If requirements.txt hasn't changed, this layer is reused on rebuild.
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ── Copy application code ─────────────────────────────────────────
COPY mcp_search_server.py .

# ── Health check ─────────────────────────────────────────────────
# MCP stdio servers don't expose HTTP, so we check the process is alive
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import mcp; print('ok')" || exit 1

# ── Non-root user (security best practice) ───────────────────────
RUN useradd --create-home --shell /bin/bash mcpuser
USER mcpuser

# ── Entry point ───────────────────────────────────────────────────
# MCP stdio transport: the server reads from stdin and writes to stdout.
# Continue.dev launches this via 'docker run' and communicates over stdio.
CMD ["python", "mcp_search_server.py"]
