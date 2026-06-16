# Rased — AI-Powered Server Dashboard

**راصد** — a lightweight, self-hosted dashboard to monitor Docker containers and
hosts across one or many machines, with on-demand AI log analysis. No external
database: the agent uses **SQLite**, so the whole stack is just two containers
(~250 MB total).

## Features

- **Live metrics** over WebSocket — containers (CPU/RAM/restarts) + host
  CPU/RAM/disk/load (psutil).
- **Multiple machines, one dashboard** — each agent registers itself and appears
  as its own **tab** (Proxmox + several LXCs).
- **Container actions** — restart / stop / start (admin only, enforced server-side).
- **AI log analysis** — OpenAI-compatible providers (Ollama, LM Studio,
  **Anthropic/Claude**, OpenAI, custom). Logs sanitized before they reach a model.
- **AI chat** — ask about a server; **conversations are saved** to resume/review.
  Analyses are auto-saved as conversations too.
- **AI replies in your UI language** (Arabic ⇄ English).
- **Proactive AI triage** on container crashes + optional **daily AI digest**.
- **Alerts → webhook** (n8n / Telegram / Slack): CPU/RAM/disk/down/UPS/uptime/TLS/anomaly.
- **Uptime + TLS-expiry checks**, **history** (24h/7d/30d charts), **UPS** via NUT.
- **Auth & roles** — email/password login; first account is **admin**, others
  **viewer** (read-only). Admins manage roles in-app.
- **Bilingual UI** (Arabic + English, RTL), dark/light themes, persisted.

## Architecture

```
            WebSocket (live, all hosts)        ┌──────────────────────────┐
 ┌────────────┐  REST: auth/settings/users/    │  CENTRAL rased-api        │
 │  React UI  │◄─devices/history/chats─────────│  FastAPI + SQLite (/data) │
 └─────┬──────┘  actions/logs/analyze/ask      │  + WebSocket + auth(JWT)  │
       │            (to a device's api_url)     └─────────┬────────────────┘
       │                                            ▲     │ Docker + NUT (local)
       │   POST /ingest/metrics (AGENT_TOKEN)       │
       │ ┌──────────────────────────┐               │
       └─│ remote agent (LXC #2)     │───────────────┘
         │ FastAPI (no DB) + Docker  │   metrics every few seconds
         └──────────────────────────┘
```

- The **central** node runs the API + SQLite + WebSocket + the UI (nginx).
- **Remote** agents run only `rased-api` and POST their metrics to the central
  node; the dashboard shows each as a tab and routes actions to its `api_url`.
- All nodes verify dashboard requests with a shared **JWT secret** (role is in
  the token — no DB lookup needed on remote agents).

## Repository layout

```
backend/   FastAPI agent (Python) — app/db.py (SQLite), services/, routers/
web/       React + Vite + Tailwind + Tremor UI (src/, builds to web/dist) — the active UI
frontend/  legacy Flutter UI (no longer served; kept for reference)
scripts/   install.sh (central), bootstrap-agent.sh + install-agent.sh (extra machine), up.sh
docker-compose.yml        central: rased-api + rased-ui (+ sqlite volume)
docker-compose.agent.yml  extra machine: agent only
```

## Prerequisites

- **Docker** + Compose v2 (`docker compose version`)
- **Node 20+** to build the web UI (`cd web && npm install && npm run build`)
- Free ports on the central host: **8082** (UI), **8002** (API)

---

## Quick start (single host)

### Fastest: one command (prebuilt GHCR images, no build)

```bash
curl -fsSL https://raw.githubusercontent.com/abdulmalik-0/Rased/main/scripts/bootstrap-central.sh | bash
```
Installs Docker if missing, generates `.env` with random secrets (asks only for the
server IP), pulls `ghcr.io/abdulmalik-0/rased-{api,ui}`, and starts everything. The UI
image reads the backend URL at runtime — no rebuild per server. Then open
`http://YOUR_IP:8082` and create the first (admin) account.

### Or build from source

### 1. Build the web UI (once)

The UI is React + Tailwind + Tremor (in `web/`). Only the backend URL is baked in:
```bash
cd web && npm install
VITE_BACKEND_URL=http://YOUR_IP:8002 npm run build   # outputs web/dist
cd ..
```

### 2. Install & start — one command

```bash
chmod +x scripts/*.sh
bash scripts/install.sh
# firewall (LAN), if needed:
sudo ufw allow 8082/tcp && sudo ufw allow 8002/tcp
```
`install.sh` asks only for the server **IP**, generates random secrets into `.env`,
then builds and starts both containers. There are **no migrations** — SQLite
initializes itself. (Prefer manual config? `cp .env.example .env`, edit it, then `bash scripts/up.sh`.)

Open **http://YOUR_IP:8082** → **Create account** (first account = **admin**).
The in-app **Help (?)** button explains everything; **Settings → AI Provider** sets the model.

| URL | What |
|-----|------|
| http://YOUR_IP:8082 | Dashboard |
| http://YOUR_IP:8002/docs | Agent API docs |

---

## Adding more machines (multi-device tabs)

**One command.** In the dashboard press **(+) Add device**, tweak the id/name, and copy
the command (secrets are masked; Copy copies the real one). On the new Linux machine
just paste it — it downloads Rased from GitHub and starts the agent itself:
```bash
curl -fsSL https://raw.githubusercontent.com/abdulmalik-0/Rased/main/scripts/bootstrap-agent.sh \
  | bash -s -- --central http://CENTRAL_IP:8002 --token <AGENT_TOKEN> --jwt <JWT_SECRET> \
               --id lxc-2 --name "LXC 2"
sudo ufw allow 8002/tcp  # so the dashboard can manage this agent
```
It auto-installs git & Docker if missing (run as root or with sudo). Prefer not to pipe to
bash? `git clone` the repo then run `bash scripts/install-agent.sh` with the same flags.
It appears as a new tab within seconds. `AGENT_TOKEN` and `JWT_SECRET` **must match**
the central values (the Add-device screen fills them for you). `.env.agent` holds
secrets and is gitignored.

---

## AI providers

Configure in **Settings → AI Provider**. The agent calls the provider, so use
`host.docker.internal` (not `localhost`) for services on the same host.

| Provider | Base URL | Model example | Key |
|----------|----------|---------------|-----|
| Ollama | `http://host.docker.internal:11434/v1` | `llama3.2` | — |
| LM Studio | `http://<ip>:1234/v1` | (loaded model) | — |
| Anthropic (Claude) | `https://api.anthropic.com/v1` | `claude-sonnet-4-...` | required |
| OpenAI / cloud | `https://api.openai.com/v1` | `gpt-4o` | required |

`AI_BASE_URL`/`AI_MODEL`/`AI_API_KEY` env enable the autonomous **digest +
triage** (separate from the per-user on-demand config).

## Users & roles

First account = **admin**; later accounts = **viewer** (read-only). Admins get a
**Users** screen to change roles. `POST /actions/*` requires an admin JWT.

## UPS via NUT

```env
NUT_HOST=host.docker.internal   # or a Proxmox host's IP
NUT_UPS_NAME=ups                # from `upsc -l`
```
If NUT runs on a Proxmox host and Rased in an LXC, point `NUT_HOST` at the
Proxmox IP and make `upsd` LISTEN on the network (`/etc/nut/upsd.conf`).

---

## Updating an existing deployment

Build the web app (step 2), then ship only what changed (never overwrites the
server `.env`):
```bash
tar -czf rased-update.tar.gz backend/app backend/requirements.txt \
    frontend/build/web scripts docker-compose.yml docker-compose.agent.yml \
    .env.example .env.agent.example README.md
scp rased-update.tar.gz user@CENTRAL_IP:~/
# on the central host:
cd ~/projects/rased && tar -xzf ~/rased-update.tar.gz
chmod +x scripts/*.sh && bash scripts/up.sh
```
Then hard-refresh the browser (Ctrl+Shift+R). Data (SQLite) lives in the
`rased-data` Docker volume and survives updates.

---

## Configuration (key env vars)

| Var | Purpose |
|-----|---------|
| `JWT_SECRET` | Signs/verifies login tokens (same on all nodes) |
| `ENCRYPTION_KEY` | Encrypts stored AI API keys (central) |
| `AGENT_TOKEN` | Shared secret for remote→central `/ingest` |
| `RASED_PUBLIC_BASE_URL` | This agent's reachable URL (for routing actions) |
| `CENTRAL_INGEST_URL` | Set on remote agents → makes them "remote" |
| `RASED_CORS_ORIGINS` | Allowed UI origin(s) |
| `ALERT_WEBHOOK_URL`, `UPTIME_CHECKS`, `AI_*`, `NUT_*` | Optional features |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission denied` on docker | `sudo usermod -aG docker $USER`, re-login |
| UI returns **403** | `chmod -R a+rX frontend/build/web` then re-run `up.sh` (built in) |
| Can't sign in / 401 on save | Token expired — sign in again |
| New device tab missing | Check the agent's `CENTRAL_INGEST_URL`, `AGENT_TOKEN`, and that 8002 is reachable |
| Actions fail on a remote device | Its `RASED_PUBLIC_BASE_URL` must be reachable from your browser, and `JWT_SECRET` must match central |
| Packaged on Windows → odd values | Fix CRLF: `sed -i 's/\r$//' .env` |
| Reset everything | DB lives in the `rased-data` volume; `docker compose down -v` wipes it |

## Security notes

- Passwords hashed with bcrypt; AI keys encrypted at rest (Fernet); logs
  sanitized before AI.
- Container actions require an **admin** JWT (verified on every node).
- Change `JWT_SECRET`, `ENCRYPTION_KEY`, `AGENT_TOKEN` before exposing.

## License

MIT
