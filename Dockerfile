# Automated Pill Dispenser — software-first runtime
# Python edge vision + mock hardware + local Bronze/Silver/Gold medallion
FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    # Default OpenCV/MediaPipe to headless-friendly behavior in containers
    QT_QPA_PLATFORM=offscreen \
    MPLBACKEND=Agg

WORKDIR /app

# System libs for OpenCV / MediaPipe wheels + serial tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
        libgomp1 \
        libusb-1.0-0 \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps (headless OpenCV for container; GUI host can still use edge/requirements.txt)
COPY edge/requirements-docker.txt /tmp/requirements-docker.txt
RUN pip install -r /tmp/requirements-docker.txt

# Project source
COPY edge/ /app/edge/
COPY databricks/ /app/databricks/
COPY firmware/ /app/firmware/
COPY docs/ /app/docs/
COPY project.md README.md AGENTS.md /app/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /app/edge/logs/telemetry /app/databricks/sample_data \
    && useradd --create-home --uid 1000 --shell /bin/bash appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["smoke"]
