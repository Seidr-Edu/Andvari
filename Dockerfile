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

WORKDIR /app

COPY . .

RUN chmod +x ./andvari-run.sh ./gate_hard.sh ./gate_recon.sh ./scripts/verify_outcome_coverage.sh ./tests/run.sh

ENTRYPOINT ["./andvari-run.sh"]
CMD ["--help"]
