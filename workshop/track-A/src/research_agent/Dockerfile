# syntax=docker/dockerfile:1.7
FROM --platform=linux/amd64 python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

# Copy the whole track-A workspace so personas/, skills/, tools/, src/ are all available.
COPY . /app

ENV PYTHONPATH=/app

EXPOSE 8087

CMD ["python", "-m", "src.research_agent.main"]
