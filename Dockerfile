ARG DEBIAN_FRONTEND=noninteractive

# Stage 1: base OS + system packages
FROM debian:bookworm-slim AS base

ARG DEBIAN_FRONTEND
ARG NODE_MAJOR=22

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    gcc \
    g++ \
    make \
    libc-dev \
    libsdl2-2.0-0 \
    imagemagick \
    python3-dev \
    libffi-dev \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    xz-utils \
    tk-dev \
    libboost-python-dev \
    libboost-system-dev \
    libboost-iostreams-dev \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: install uv + pebble-tool
FROM base AS pebble-install

ARG UV_VERSION=0.7.8
ARG PEBBLE_TOOL_VERSION
ARG PEBBLE_PYTHON_VERSION=3.13

ENV UV_TOOL_DIR=/opt/uv-tools
ENV PATH="/opt/uv-tools/pebble-tool/bin:/root/.local/bin:${PATH}"

# Install uv
RUN curl -LsSf "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-installer.sh" \
    | UV_INSTALL_DIR=/usr/local/bin sh

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash pebble
RUN mkdir -p /opt/uv-tools && chown pebble:pebble /opt/uv-tools
RUN mkdir -p /work && chown pebble:pebble /work

USER pebble
ENV HOME=/home/pebble
ENV UV_TOOL_DIR=/opt/uv-tools
ENV PATH="/opt/uv-tools/pebble-tool/bin:/home/pebble/.local/bin:${PATH}"

# Install pebble-tool via uv.
# stpyv8 (pulled in via pypkjs) has no Linux arm64 wheels; source build requires
# --no-build-isolation-package so its own settings.py is importable during setup.
RUN if [ -n "$PEBBLE_TOOL_VERSION" ]; then \
      uv tool install "pebble-tool==${PEBBLE_TOOL_VERSION}" \
          --python "${PEBBLE_PYTHON_VERSION}" \
          --no-build-isolation-package stpyv8; \
    else \
      uv tool install pebble-tool \
          --python "${PEBBLE_PYTHON_VERSION}" \
          --no-build-isolation-package stpyv8; \
    fi \
    && pebble --version

# Stage 3: install Pebble SDK (large layer — ARM toolchain + SDK headers)
FROM pebble-install AS sdk-install

ARG PEBBLE_SDK_VERSION

ENV PEBBLE_HOME=/home/pebble/.pebble-sdk

# Opt out of analytics before any SDK command
RUN mkdir -p "${PEBBLE_HOME}" \
    && printf '{"analytics": false}\n' > "${PEBBLE_HOME}/NO_TRACKING"

# Install SDK (downloads arm-none-eabi toolchain + SDK resources)
RUN if [ -n "$PEBBLE_SDK_VERSION" ]; then \
      pebble sdk install "${PEBBLE_SDK_VERSION}"; \
    else \
      pebble sdk install latest; \
    fi \
    && pebble sdk list

# Stage 4: final image
FROM sdk-install AS final

ARG PEBBLE_TOOL_VERSION
ARG PEBBLE_SDK_VERSION

LABEL org.opencontainers.image.source="https://github.com/gregolsky/docker-pebble-sdk" \
      org.opencontainers.image.description="Maintained Docker image for Pebble watch development — uv + pebble-tool + Pebble SDK" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.pebble.tool.version="${PEBBLE_TOOL_VERSION}" \
      io.pebble.sdk.version="${PEBBLE_SDK_VERSION}"

ENV SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy \
    PEBBLE_HOME=/home/pebble/.pebble-sdk \
    UV_TOOL_DIR=/opt/uv-tools \
    PATH="/opt/uv-tools/pebble-tool/bin:/home/pebble/.local/bin:${PATH}"

WORKDIR /work

COPY --chown=pebble:pebble scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["pebble", "build"]
