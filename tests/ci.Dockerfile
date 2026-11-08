# Disposable Linux validation host. No Docker daemon or account data is mounted.
FROM ghcr.io/jdx/mise:2026.11.4@sha256:085be191bbe51dbe93894681b7f29f6c014ae267e7a365c0b8b6a2fdd882ac63 AS mise
FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git make fish zsh ruby openssh-client openssh-server \
    locales docker.io xz-utils libatomic1 && \
    locale-gen en_US.UTF-8 && install -d -m 0755 /run/sshd && \
    rm -rf /var/lib/apt/lists/*
COPY --from=mise /usr/local/bin/mise /usr/local/bin/mise
ENV MISE_CONFIG_DIR=/workspace/scripts/mise MISE_TRUSTED_CONFIG_PATHS=/workspace
WORKDIR /workspace
CMD ["make", "check"]
