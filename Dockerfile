FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gradle \
    maven \
    openjdk-21-jdk-headless \
    perl \
    python3 \
    ripgrep \
  && rm -rf /var/lib/apt/lists/*

# Create a dedicated non-root user for service mode
RUN groupadd -r andvari && useradd -r -g andvari -d /app -s /bin/bash andvari

# Pre-create /run so the non-root user can write to it at container start
RUN mkdir -p /run && chown andvari:andvari /run

WORKDIR /app

COPY . .

RUN chmod +x \
    ./andvari-run.sh \
    ./andvari-service.sh \
    ./gate_hard.sh \
    ./gate_recon.sh \
    ./scripts/verify_outcome_coverage.sh \
    ./tests/run.sh

# Provider CLIs (codex, claude) are NOT baked into the image.
# Mount /opt/provider/bin read-only at container run time.

USER andvari

ENTRYPOINT ["./andvari-service.sh"]
