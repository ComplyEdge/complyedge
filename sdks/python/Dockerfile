# TrustLint offline MCP (stdio) for Glama release / Docker MCP hosts.
# Build context: this directory (sdks/python) — DF-01, beside the server.
#
#   docker build -t complyedge-mcp .
#   docker run -i --rm complyedge-mcp
#
# Glama introspects tools/list over stdio. No HTTP port, no API key.

FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY pyproject.toml README.md LICENSE ./
COPY complyedge ./complyedge

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir ".[mcp]" \
    && useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app

USER appuser

# Official Registry / Glama install-true path: stdio TrustLint MCP.
ENTRYPOINT ["python", "-m", "complyedge.mcp_server"]
