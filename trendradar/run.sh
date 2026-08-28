#!/usr/bin/env bash
# TrendRadar Hass-Addon wrapper.
#
# Responsibilities:
#   1. Replace /app/config and /app/output with symlinks into HA's /share/trendradar/
#      so configuration + data survive container restarts and HA reinstalls.
#   2. Seed default config files from /usr/src/trendradar/defaults/ on first run
#      (the upstream entrypoint.sh exits 1 if config files are missing).
#   3. Forward HA addon options as environment variables to the upstream container.
#   4. Hand off to the upstream entrypoint.sh unchanged (which manages supercronic).

set -e

DEFAULTS_DIR="/usr/src/trendradar/defaults"
DATA_ROOT="/share/trendradar"
CONFIG_DIR="${DATA_ROOT}/config"
OUTPUT_DIR="${DATA_ROOT}/output"

# --------------------------------------------------------------------------------------
# 1. Prepare persistent dirs under HA's /share (mounted via `map: [share:rw]` in config.yaml)
# --------------------------------------------------------------------------------------
mkdir -p "${CONFIG_DIR}" "${OUTPUT_DIR}"

# --------------------------------------------------------------------------------------
# 2. Seed default config files if they don't already exist.
#    Existing user-edited files are NEVER overwritten.
# --------------------------------------------------------------------------------------
if command -v rsync >/dev/null 2>&1; then
    # rsync handles nested directories (ai_filter/, custom/) cleanly
    rsync -a --ignore-existing "${DEFAULTS_DIR}/" "${CONFIG_DIR}/"
else
    # Fallback: cp -rn (GNU) skips existing files
    cp -rn "${DEFAULTS_DIR}/." "${CONFIG_DIR}/" 2>/dev/null || \
    find "${DEFAULTS_DIR}" -type f -exec sh -c '
        for f; do
            rel="${f#'"${DEFAULTS_DIR}"'/}"
            dest="'"${CONFIG_DIR}"'${rel}"
            mkdir -p "$(dirname "${dest}")"
            [ -f "${dest}" ] || cp "${f}" "${dest}"
        done
    ' _ {} +
fi

# --------------------------------------------------------------------------------------
# 3. Redirect /app/config and /app/output to the persistent dirs.
#    The upstream Dockerfile creates these as empty dirs; we replace them with symlinks.
# --------------------------------------------------------------------------------------
rm -rf /app/config /app/output
ln -s "${CONFIG_DIR}" /app/config
ln -s "${OUTPUT_DIR}"  /app/output

# --------------------------------------------------------------------------------------
# 4. Forward HA addon options as environment variables.
#    HA Supervisor does NOT auto-export every option as an env var; we do it manually.
#    Unknown / future options are forwarded too via the catch-all block.
# --------------------------------------------------------------------------------------
export TZ="${TZ:-${TIMEZONE:-Asia/Shanghai}}"
export WEBSERVER_PORT="${WEBSERVER_PORT:-8080}"
export CRON_SCHEDULE="${CRON_SCHEDULE:-*/30 * * * *}"
export RUN_MODE="${RUN_MODE:-cron}"
export IMMEDIATE_RUN="${IMMEDIATE_RUN:-true}"

# Notification channels
export FEISHU_WEBHOOK_URL="${FEISHU_WEBHOOK_URL:-}"
export TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
export TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
export DINGTALK_WEBHOOK_URL="${DINGTALK_WEBHOOK_URL:-}"
export WEWORK_WEBHOOK_URL="${WEWORK_WEBHOOK_URL:-}"
export WEWORK_MSG_TYPE="${WEWORK_MSG_TYPE:-}"
export EMAIL_FROM="${EMAIL_FROM:-}"
export EMAIL_PASSWORD="${EMAIL_PASSWORD:-}"
export EMAIL_TO="${EMAIL_TO:-}"
export EMAIL_SMTP_SERVER="${EMAIL_SMTP_SERVER:-}"
export EMAIL_SMTP_PORT="${EMAIL_SMTP_PORT:-}"
export NTFY_SERVER_URL="${NTFY_SERVER_URL:-https://ntfy.sh}"
export NTFY_TOPIC="${NTFY_TOPIC:-}"
export NTFY_TOKEN="${NTFY_TOKEN:-}"
export BARK_URL="${BARK_URL:-}"
export SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
export GENERIC_WEBHOOK_URL="${GENERIC_WEBHOOK_URL:-}"
export GENERIC_WEBHOOK_TEMPLATE="${GENERIC_WEBHOOK_TEMPLATE:-}"

# AI config
export AI_ANALYSIS_ENABLED="${AI_ANALYSIS_ENABLED:-false}"
export AI_API_KEY="${AI_API_KEY:-}"
export AI_MODEL="${AI_MODEL:-}"
export AI_API_BASE="${AI_API_BASE:-}"

# S3 remote storage
export S3_ENDPOINT_URL="${S3_ENDPOINT_URL:-}"
export S3_BUCKET_NAME="${S3_BUCKET_NAME:-}"
export S3_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID:-}"
export S3_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY:-}"
export S3_REGION="${S3_REGION:-}"

# Logging — HA Supervisor captures stdout/stderr automatically and shows it in the Log tab.
# The upstream image is based on python:3.12-slim-bookworm (no bashio), so we use plain echo.
echo "[trendradar-hass-addon] Starting TrendRadar (TZ=${TZ}, port=${WEBSERVER_PORT}, cron='${CRON_SCHEDULE}')..."
echo "[trendradar-hass-addon] Config dir: ${CONFIG_DIR}"
echo "[trendradar-hass-addon] Output dir: ${OUTPUT_DIR}"

# --------------------------------------------------------------------------------------
# 4.5. Start the visual config editor webserver in the background.
#       - setsid puts it in a new session so it survives the upcoming `exec` of /entrypoint.sh
#         (which replaces this shell with supercronic as PID 1).
#       - setsid+nohup make it immune to SIGHUP from the dying shell.
#       - Logs go to /var/log/editor.log which HA Supervisor also captures (since vmlog).
# --------------------------------------------------------------------------------------
EDITOR_PORT="${EDITOR_PORT:-8089}"
mkdir -p /var/log
setsid nohup python3 -u /usr/src/trendradar/editor/server.py \
    > /var/log/editor.log 2>&1 < /dev/null &
EDITOR_PID=$!
disown ${EDITOR_PID} 2>/dev/null || true
echo "[trendradar-hass-addon] Editor webserver starting on port ${EDITOR_PORT} (PID ${EDITOR_PID}); logs → /var/log/editor.log"
# Give it a brief moment to bind before the upstream entrypoint potentially races on port setup.
sleep 1

# --------------------------------------------------------------------------------------
# 5. Hand off to the upstream entrypoint.
#    `exec` replaces this shell so supercronic becomes PID 1 (matches upstream behavior).
# --------------------------------------------------------------------------------------
exec /entrypoint.sh "$@"