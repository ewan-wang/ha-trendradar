# Changelog

## 0.2.0 - Visual config editor

- **NEW**: Bundled the official TrendRadar visual config editor
  (`https://sansan0.github.io/TrendRadar/`) directly into the add-on UI.
- **NEW**: One-click "保存到HA并重启" button writes
  `config.yaml` / `frequency_words.txt` / `timeline.yaml` to the add-on's
  persistent data directory and automatically restarts the add-on via the
  HA Supervisor API.
- **NEW**: Sidebar entry "配置编辑器" appears in the Home Assistant frontend.
- **NEW**: New port `8089` mapped to host (configurable via `editor_port`
  option) serving the editor + JSON API.
- The upstream `script.js` is unmodified; a small inline shim redirects
  load/save from browser `localStorage` to the add-on's `/api/*` endpoints.

## 0.1.0 - Initial release

- First public release of the TrendRadar Home Assistant add-on.
- Wraps the official `wantcat/trendradar` Docker image as a HAOS add-on.
- Supports `linux/amd64` and `linux/aarch64`.
- Persists config and data under HA's `/share/trendradar/`.
- Defaults seeded from the upstream `config/` directory on first run.
- All major TrendRadar options exposed through the HA add-on configuration panel.