# syntax=docker/dockerfile:1.7

FROM scratch AS sdk-archives
COPY docker-sdks/ /

FROM ubuntu:24.04

ARG TARGETARCH
ARG VERSION=dev
ARG REVISION=unknown

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL org.opencontainers.image.title="musl-cross" \
      org.opencontainers.image.description="Linux-hosted musl cross-compilers for ARM, AArch64, x86, and MIPS targets" \
      org.opencontainers.image.source="https://github.com/okning/musl-cross" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        cmake \
        file \
        make \
        ninja-build \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,from=sdk-archives,source=/,target=/tmp/sdk,ro \
    set -eux; \
    case "${TARGETARCH}" in \
      amd64) host_arch=x86_64 ;; \
      arm64) host_arch=aarch64 ;; \
      *) echo "unsupported image architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    cd /tmp/sdk; \
    sha256sum --check ./*.sha256; \
    mkdir -p /opt/musl-cross; \
    for target in arm armv5 arm6 armv7 aarch64 x86 amd64 mips mipsel mips64 mips64el; do \
      archive="musl-${target}-${host_arch}-linux.tar.gz"; \
      tar -xzf "${archive}" -C /opt/musl-cross; \
      mv "/opt/musl-cross/musl-${target}-${host_arch}-linux" "/opt/musl-cross/${target}"; \
      ( \
        cd "/opt/musl-cross/${target}"; \
        ./relocate-sdk.sh; \
        . ./environment-setup; \
        test "${CXX}" != no; \
        "${CC}" --version >/dev/null; \
        "${CXX}" --version >/dev/null; \
        test -x ./smoke-test; \
        test -x ./smoke-test-cxx; \
      ); \
    done

COPY --chmod=0755 docker/musl-cross-entrypoint.sh /usr/local/bin/musl-cross

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/musl-cross"]
CMD ["bash"]
