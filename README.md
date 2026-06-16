# Rased — AI-Powered Server Dashboard

**راصد** — a lightweight, self-hosted dashboard to monitor Docker containers and
hosts across one or many machines, with on-demand AI log analysis. No external
database: the agent uses **SQLite**, so the whole stack is just two containers
(~250 MB total).

## Features

- **Live metrics** over WebSocket — containers (CPU/RAM/restarts) + host
  CPU/RAM/disk/load shown as circular gauges (psutil), with temperatures.
- **Multiple machines, one dashboard** — each agent registers itself and appears
  as its own **tab** (Proxmox + several LXCs).
- **Container actions** — restart / stop / start (admin only, enforced server-side).
- **AI container install** — describe a service *or* paste an image; the AI plans
  it, you review, one click installs it (admin, via the Docker SDK; taken host
  ports are auto-reassigned, unsafe host binds blocked). Toggle with
  `ALLOW_CONTAINER_DEPLOY`.
- **AI log analysis** — OpenAI-compatible providers (Ollama, LM Studio,
  **Anthropic/Claude**, OpenAI, custom). Logs sanitized before they reach a model.
- **AI chat with RAG** — ask trend questions; recent **24h history + alerts** are
  auto-injected so it can answer "why did CPU spike last night?". Conversations saved.
- **AI usage accounting** + optional **monthly token budget** per user.
- **Alerts inbox** — acknowledge / resolve, with **per-host thresholds** editable
  from the UI.
- **Notifications** — Slack / Discord / **Telegram** / generic webhook (auto-detected),
  with retry + cooldown. Plus **dead-agent** alerts and proactive AI triage.
- **Uptime + TLS-expiry checks**, **history** (host + per-container charts), **UPS** via NUT.
- **Auth, roles & audit** — email/password login + admin approval; first account is
  **admin**. **Token revocation** (logout / role change invalidates sessions) and an
  **audit log** of privileged actions.
- **Backups** — one-click SQLite backup (admin).
- **Bilingual UI** (Arabic + English, RTL), dark/light, accessible dialogs.
- **Deploy** — prebuilt multi-arch **GHCR images**, runtime-configurable backend
  URL (no rebuild per server), and one-line installers for central + agents.

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
- All nodes verify dashboard requests with a shared **JWT secret**. The central
  re-checks the token against the DB on every request (so logout / role change /
  approval take effect immediately); remote agents verify with the central via
  `/auth/verify` (cached ~30s, fail-open if the central is briefly unreachable).

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

- **RAG context:** the AI chat (`/ask`) auto-injects the last **24h** of host
  history (averages + peaks) and the **10 most recent alerts**, so it can answer
  trend questions. Optionally include a container's last log lines.
- **Usage & budget:** every AI call's token usage is logged. **Settings → Admin
  tools → AI usage** shows per-user totals. Set `AI_MONTHLY_TOKEN_BUDGET` (0 =
  unlimited) to cap monthly tokens per user.
- **AI container install:** the 🚀 button — **By image** (paste e.g.
  `linuxserver/jellyfin` → pull & run) or **Describe** (AI plans it → you review
  → install). Runs via the Docker SDK; taken host ports are auto-reassigned and
  sensitive host binds (`/`, `/etc`, `docker.sock`, …) are rejected.

## Alerts & notifications

Alerts fire for CPU / memory / disk / container-down / UPS / uptime / TLS-expiry /
anomaly / **dead agent**. View and triage them on the **Alerts** screen
(✓ = acknowledge, ✓✓ = resolve).

**Thresholds** are global by default and overridable **per host** from the
device-settings (⚙️) dialog (blank field = use the global default):

```env
CPU_ALERT_PERCENT=90      MEM_ALERT_PERCENT=90
DISK_ALERT_PERCENT=85     BATTERY_ALERT_PERCENT=30
ALERT_COOLDOWN_SECONDS=600   # min seconds between repeats of the same alert
```

**Channels** — set in the central `.env`, then `docker compose up -d`:

| Channel | Set | Detected by / sends |
|---------|-----|---------------------|
| Slack | `ALERT_WEBHOOK_URL=https://hooks.slack.com/services/…` | URL contains `hooks.slack.com` → `{text}` |
| Discord | `ALERT_WEBHOOK_URL=https://discord.com/api/webhooks/…` | URL contains `/api/webhooks` → `{content}` |
| Generic (n8n…) | `ALERT_WEBHOOK_URL=<any other url>` | full JSON `{level,kind,target,value,host_id,message,timestamp}` |
| Telegram | `TELEGRAM_BOT_TOKEN=…` + `TELEGRAM_CHAT_ID=…` | sent via the Bot API (works alongside the webhook) |

Delivery retries 3× with backoff; the central node sends (agents forward metrics to it).

## Backups

**Settings → Admin tools → Backup DB** (or `GET /admin/backup`) downloads a
WAL-safe copy of `rased.db`. There's no restore endpoint — to restore: stop the
stack, replace `/data/rased.db` (in the `rased-data` volume) with the backup,
restart. Keep your `ENCRYPTION_KEY` with the backup or stored AI keys can't be
decrypted. Old history/alerts are pruned daily (`HISTORY_RETAIN_DAYS`,
`ALERT_RETAIN_DAYS`).

## Users & roles

First account = **admin** (auto-approved); later accounts = **viewer** and stay
**pending until an admin approves** them on the **Users** screen (where roles are
also changed). `POST /actions/*` and deploys require an admin JWT.

- **Token revocation:** logging out, or changing a user's role/approval, bumps a
  per-user `token_version` so existing sessions are invalidated immediately.
- **Audit log:** privileged actions (container actions, deploys, user/role/approval
  changes, settings, backups) are recorded — `GET /audit` (admin).

## UPS via NUT

```env
NUT_HOST=host.docker.internal   # or a Proxmox host's IP
NUT_UPS_NAME=ups                # from `upsc -l`
```
If NUT runs on a Proxmox host and Rased in an LXC, point `NUT_HOST` at the
Proxmox IP and make `upsd` LISTEN on the network (`/etc/nut/upsd.conf`).

---

## Updating an existing deployment

Simplest is to pull the GHCR images (`docker compose -f docker-compose.images.yml
pull && … up -d`). To ship a source build instead, build the web app (step 1),
then send only what changed (never overwrites the server `.env`):
```bash
tar -czf rased-update.tar.gz backend/app backend/Dockerfile backend/requirements.txt \
    web/dist scripts docker-compose.yml docker-compose.agent.yml
scp rased-update.tar.gz user@CENTRAL_IP:~/projects/rased/
# on the central host:
cd ~/projects/rased && tar --no-same-owner -xzf rased-update.tar.gz
chmod -R a+rX web/dist && docker compose up -d --build
docker compose up -d --force-recreate rased-ui
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
| `BACKEND_URL` | UI image only: backend URL injected at runtime (GHCR/images compose) |
| `ALERT_WEBHOOK_URL` | Slack/Discord/generic alert webhook (auto-detected) |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | Telegram alert channel (optional) |
| `CPU/MEM/DISK/BATTERY_ALERT_PERCENT`, `ALERT_COOLDOWN_SECONDS` | Global alert thresholds |
| `AI_MONTHLY_TOKEN_BUDGET` | Per-user monthly AI token cap (0 = unlimited) |
| `ALLOW_CONTAINER_DEPLOY` | Enable/disable the AI Install button (default true) |
| `HISTORY_RETAIN_DAYS`, `ALERT_RETAIN_DAYS` | Daily prune windows |
| `RASED_REF` | Agent bootstrap: pin a release tag/branch |
| `UPTIME_CHECKS`, `AI_*`, `NUT_*`, `DIGEST_*` | Optional features |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission denied` on docker | `sudo usermod -aG docker $USER`, re-login |
| UI returns **403** | `chmod -R a+rX web/dist` then re-run `up.sh` (built in) |
| Can't sign in / 401 on save | Token expired — sign in again |
| New device tab missing | Check the agent's `CENTRAL_INGEST_URL`, `AGENT_TOKEN`, and that 8002 is reachable |
| Actions fail on a remote device | Its `RASED_PUBLIC_BASE_URL` must be reachable from your browser, and `JWT_SECRET` must match central |
| Packaged on Windows → odd values | Fix CRLF: `sed -i 's/\r$//' .env` |
| Reset everything | DB lives in the `rased-data` volume; `docker compose down -v` wipes it |

## Security notes

- Passwords hashed with bcrypt; AI keys encrypted at rest (Fernet); logs
  sanitized before AI.
- Container actions and deploys require an **admin** JWT; the central re-checks
  the token (version/role/approval) against the DB every request.
- The backend **refuses to start** with the shipped `change-me` `JWT_SECRET` /
  `ENCRYPTION_KEY`. `scripts/install.sh` and `bootstrap-central.sh` generate
  random ones; keep them stable.
- AI-install rejects unsafe host bind mounts; privileged actions are audited.
- Change `JWT_SECRET`, `ENCRYPTION_KEY`, `AGENT_TOKEN` before exposing.

## License

MIT
