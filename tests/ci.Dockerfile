# Disposable Linux validation host. No Docker daemon or account data is mounted.
FROM ghcr.io/jdx/mise:2026.11.4@sha256:085be191bbe51dbe93894681b7f29f6c014ae267e7a365c0b8b6a2fdd882ac63 AS mise
FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git make fish zsh ruby openssh-client openssh-server \
    locales docker.io xz-utils && \
    locale-gen en_US.UTF-8 && install -d -m 0755 /run/sshd && \
    rm -rf /var/lib/apt/lists/*
COPY --from=mise /usr/local/bin/mise /usr/local/bin/mise
ENV MISE_CONFIG_DIR=/workspace/scripts/mise MISE_TRUSTED_CONFIG_PATHS=/workspace
WORKDIR /workspace
CMD ["make", "check"]
