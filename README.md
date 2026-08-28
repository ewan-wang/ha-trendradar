# TrendRadar — Home Assistant Add-on Repository

This repository contains a [Home Assistant](https://www.home-assistant.io/) add-on
that wraps the official [TrendRadar](https://github.com/SANSAN0/TrendRadar) Docker
image so it can be installed and managed from the HAOS Supervisor / Add-on Store.

> All credit for TrendRadar itself goes to
> [SANSAN0/TrendRadar](https://github.com/SANSAN0/TrendRadar). This repository
> only provides the add-on wrapper.

---

## Highlights

- **Visual config editor built in** — the official upstream editor
  (`https://sansan0.github.io/TrendRadar/`) is bundled inside the add-on,
  with a one-click **保存到HA并重启** button that writes all three config
  files to the persistent share and auto-restarts via the HA Supervisor API.
- **Sidebar entry** "配置编辑器" appears in the HA frontend.
- **Two web UIs** exposed on host ports:
  - `8089` — visual config editor (default **OPEN WEB UI** entry)
  - `8080` — TrendRadar's own news dashboard
- Persists config and data under HA's `/share/trendradar/`.
- Defaults seeded from the upstream `config/` directory on first run.
- All major TrendRadar options also exposed through the HA add-on
  Configuration tab for users who prefer plain YAML.

---

## Repository layout

```
trendradar-hass-addon/
├── repository.json                          # HA Supervisor repository descriptor
├── README.md                                # This file
└── trendradar/                              # The add-on
    ├── config.yaml                          # Add-on manifest (ports, options, schema, ...)
    ├── build.yaml                           # Build pipeline config (FROM which image per arch)
    ├── Dockerfile                            # FROM ${BUILD_FROM} + LABEL + COPY run.sh + COPY rootfs
    ├── run.sh                               # Seed defaults + launch editor webserver + exec upstream entrypoint
    ├── CHANGELOG.md
    ├── README.md                            # Per-addon install / config docs
    ├── icon.png / logo.png                  # Placeholder PNGs (replace before publishing)
    └── rootfs/                              # Files layered into the upstream image
        └── usr/src/trendradar/
            ├── defaults/                    # Default config files (seeded on first run)
            │   ├── config.yaml
            │   ├── frequency_words.txt
            │   ├── timeline.yaml
            │   ├── ai_analysis_prompt.txt
            │   ├── ai_translation_prompt.txt
            │   ├── ai_interests.txt
            │   ├── ai_filter/{prompt,extract_prompt,update_tags_prompt}.txt
            │   └── custom/{keyword,ai}/.gitkeep
            └── editor/                      # Bundled visual config editor
                ├── server.py                # Python stdlib webserver (read/write configs + Supervisor restart API)
                ├── index.html               # Upstream editor UI + inline I/O shim + "保存并重启" button
                └── assets/                  # Upstream editor assets (style.css, i18n.js, script.js, weixin.webp)
```

---

## How the add-on is wired

| Layer | What it does |
|---|---|
| `Dockerfile` | `FROM ${BUILD_FROM}` (= `wantcat/trendradar:latest`) → adds `io.hass.*` labels → `COPY run.sh /run.sh` → `COPY rootfs /` → `chmod a+x /run.sh` → `ENTRYPOINT ["/run.sh"]`. |
| `build.yaml` | Tells the HA build pipeline which upstream image to use per architecture. |
| `config.yaml` | Add-on manifest: ports (8080 + 8089), options, schema, maps, `init: false`, `panel: true` (sidebar entry). |
| `run.sh` | First-run config seeding → symlink `/app/{config,output}` → persistent dirs → env-var forwarding → launch editor webserver via `setsid nohup &` → `exec /entrypoint.sh` (upstream). |
| `editor/server.py` | Python stdlib webserver on port 8089 serving the editor HTML and `/api/*` (file I/O + Supervisor restart). |
| `editor/index.html` | Upstream visual editor + tiny inline shim that redirects I/O from `localStorage` to `/api/*` and adds the "保存到HA并重启" button. |

---

## Installation in Home Assistant

1. **Settings → Add-ons → Add-on Store → ⋮ (top-right) → Repositories**.
2. Paste this repository's Git URL and submit.
3. The **TrendRadar** add-on appears in the store — click **Install**.
4. Open the **Configuration** tab and set what you need (TZ, cron, notification webhooks, AI keys, ...).
5. **Start** the add-on.
6. **Recommended first step**: open the sidebar entry **配置编辑器** (or visit
   `http://<ha-host>:8089`) to tweak `config.yaml` / `timeline.yaml` /
   `frequency_words.txt` visually. Click **保存到HA并重启** to apply.
7. Browse TrendRadar's news dashboard at `http://<ha-host>:8080`.

Detailed per-addon docs: see [`trendradar/README.md`](./trendradar/README.md).

---

## Before publishing — checklist

- [ ] **Replace `icon.png` and `logo.png`** in `trendradar/` with real TrendRadar icons (current placeholders are 1×1 transparent PNGs).
- [x] **`repository.json` is already configured** for `ewan <yf.wang.dev@gmail.com>` → `https://github.com/ewan/ha-trendradar` (adjust if your GitHub login differs).
- [ ] Bump `version` in `trendradar/config.yaml` when you re-release.
- [ ] Update `trendradar/CHANGELOG.md`.
- [ ] Decide whether to track the upstream image by `:latest` (current setting) or pin to a digest for reproducibility.

---

## License

The wrapper code in this repository is provided as-is for community use.
TrendRadar itself is GPL-3.0 — see [SANSAN0/TrendRadar](https://github.com/SANSAN0/TrendRadar).