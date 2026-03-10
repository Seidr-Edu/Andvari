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
RUN groupadd --gid 10001 andvari \
  && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin andvari \
  && mkdir -p /run \
  && chown -R andvari:andvari /run

WORKDIR /app

COPY . .

RUN chmod +x \
    ./andvari-run.sh \
    ./andvari-service.sh \
    ./gate_hard.sh \
    ./gate_recon.sh \
    ./scripts/verify_outcome_coverage.sh \
    ./tests/run.sh \
  && chown -R andvari:andvari /app

# Provider CLIs (codex, claude) are NOT baked into the image.
# Mount /opt/provider/bin read-only at container run time.

USER andvari

ENV HOME=/home/andvari

ENTRYPOINT ["./andvari-service.sh"]
