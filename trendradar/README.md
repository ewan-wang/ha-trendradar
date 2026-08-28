# TrendRadar — Home Assistant Add-on

Home Assistant add-on wrapper around the official [TrendRadar](https://github.com/SANSAN0/TrendRadar) project.

TrendRadar is an AI-driven public-opinion & trend monitor with multi-platform aggregation, RSS subscriptions, keyword filtering, AI analysis / translation, and push notifications to many channels (Feishu, Telegram, DingTalk, WeCom, Email, ntfy, Bark, Slack, generic webhook, ...).

This add-on runs the upstream Docker image (`wantcat/trendradar`) inside Home Assistant OS, with config + data persisted under `/share/trendradar/` so they survive container restarts.

**v0.2.0+: bundled visual config editor** — the official
[TrendRadar visual config editor](https://sansan0.github.io/TrendRadar/)
runs inside the add-on itself, with one-click "保存到HA并重启"
(write all config files + auto-restart via HA Supervisor API).

---

## Installation

1. Make sure your Home Assistant instance can reach this repository URL.
2. In HA go to **Settings → Add-ons → Add-on Store → ⋮ (top-right) → Repositories**.
3. Paste this repository URL and submit.
4. The **TrendRadar** add-on will appear in the store.
5. Click it, then click **Install**.
6. Configure the options you need (see below), then **Start**.

> Two web UIs are exposed:
> - **Visual config editor** on port **8089** (`http://<ha-host>:8089`)
>   — also pinned as the add-on's default **OPEN WEB UI** button and
>   appearing as a sidebar entry "配置编辑器".
> - **TrendRadar news dashboard** on port **8080** (`http://<ha-host>:8080`)
>   — the actual reports / hot-topic views. Ingress is **not** used because
>   TrendRadar's UI is designed for full-page rendering.

---

## Editing configuration

You have **two complementary options**:

### A. Visual editor (recommended) — port 8089 / HA sidebar

Open the add-on's sidebar entry **配置编辑器** (or visit
`http://<ha-host>:8089`). You get the full upstream visual editor:

- Three tabs: `config.yaml`, `frequency_words.txt`, `timeline.yaml`
- Left side: raw YAML / text with syntax highlighting
- Right side: visual module-by-module editor with form widgets
- Sidebar (right edge): support links from the upstream project

When you click **保存到HA并重启** (the green button in the header):

1. The three files are POSTed to `/api/files` on the add-on's backend.
2. The backend writes them atomically to `/share/trendradar/config/`.
3. The backend POSTs to `http://supervisor/addons/self/restart` with the
   `SUPERVISOR_TOKEN` env var that HA provides to its add-ons.
4. Supervisor kills and restarts the container, picking up the new config.
5. Your browser auto-reloads the editor page after ~4s — done.

The upstream `script.js` is **unmodified**; a tiny inline shim at the end
of `index.html` redirects I/O from browser `localStorage` to our backend API
and exposes the `saveAndRestart` button.

### B. Direct file edit

Configs live under `/share/trendradar/config/` on the HA host. You can edit
them via SSH, the **File editor** add-on, or Samba:

```
/share/trendradar/config/config.yaml
/share/trendradar/config/frequency_words.txt
/share/trendradar/config/timeline.yaml
```

After editing, restart the add-on from **Info → Restart** for changes to apply.

---

## Configuration

All options below are exposed in the add-on's **Configuration** tab and forwarded
to the upstream container as environment variables.

### Core

| Option | Default | Description |
|---|---|---|
| `log_level` | `info` | HA Supervisor log level for this add-on. |
| `timezone` | `Asia/Shanghai` | `TZ` env var; affects cron schedule and timestamps. |
| `webserver_port` | `8080` | Container port for the Web UI (also mapped to host 8080). |
| `editor_port` | `8089` | Container port for the bundled visual config editor. |
| `cron_schedule` | `*/30 * * * *` | Standard cron expression. Validated upstream. |
| `run_mode` | `cron` | `cron` (loop) or `once` (single execution). |
| `immediate_run` | `true` | Run the pipeline once before entering the cron loop. |

### Notification channels (leave blank to disable)

Feishu, Telegram, DingTalk, WeCom, Email, ntfy, Bark, Slack, generic Webhook.
Each maps 1:1 to the upstream env vars `FEISHU_WEBHOOK_URL`, `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_CHAT_ID`, etc.

### AI

`ai_analysis_enabled`, `ai_api_key`, `ai_model`, `ai_api_base`.
`ai_model` uses LiteLLM format, e.g. `deepseek/deepseek-chat`, `openai/gpt-4o`.

### Remote storage (S3-compatible)

`s3_endpoint_url`, `s3_bucket_name`, `s3_access_key_id`, `s3_secret_access_key`, `s3_region`.

---

## Where the data lives

| Path (on the HA host) | Purpose |
|---|---|
| `/share/trendradar/config/` | All TrendRadar YAML / TXT config files. Edit freely. |
| `/share/trendradar/output/news/` | SQLite databases with collected news, one file per day. |

Defaults are seeded from the bundled `/usr/src/trendradar/defaults/` directory
on **first** run only. Your edits are never overwritten.

---

## Updating

Because this add-on is a thin wrapper around the upstream `wantcat/trendradar`
image, **updating the add-on pulls the latest upstream image** the next time HA
rebuilds it. You do not normally need to bump the add-on `version` to get
upstream fixes — just click **Rebuild** in the add-on **Info** tab, or reinstall.

If upstream makes a breaking change (new required config file, new env var
that has no default), bump the add-on `version` and update the seeded defaults
in `rootfs/usr/src/trendradar/defaults/`.

---

## Credits

All credit for TrendRadar itself goes to the original author
[SANSAN0/TrendRadar](https://github.com/SANSAN0/TrendRadar).

This add-on is **not** affiliated with the upstream project. It is a community
wrapper that makes TrendRadar runnable inside Home Assistant OS.