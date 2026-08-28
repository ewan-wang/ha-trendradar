ARG BUILD_FROM
FROM ${BUILD_FROM}

# ---- HA build-time labels (required for Supervisor to recognize this as an addon) ----
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Home Assistant Community Add-ons" \
    org.opencontainers.image.authors="TrendRadar Hass-Addons Maintainer" \
    org.opencontainers.image.url="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/trendradar/README.md" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}"

# ---- Layer our wrapper on top of the upstream image ----
# 1. /run.sh  — seed default configs + exec upstream entrypoint
# 2. /usr/src/trendradar/defaults/ — bundled default config files (seeded on first run)
COPY run.sh /run.sh
COPY rootfs /
RUN chmod a+x /run.sh

# Override the upstream ENTRYPOINT so our wrapper runs first.
# Without this, the container would jump straight into /entrypoint.sh and never
# seed defaults / forward addon options as env vars.
ENTRYPOINT ["/run.sh"]