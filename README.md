# Rased — AI-Powered Server Dashboard

**راصد** — a self-hosted dashboard to monitor Docker containers and hosts across
one or many machines, with on-demand AI log analysis. Privacy-first: bring your
own AI (local Ollama / LM Studio, or cloud), and logs are sanitized before they
ever reach a model.

## Features

- **Live metrics** — Docker containers (CPU / RAM / restarts) + host CPU / RAM /
  disk / load (psutil), streamed via Supabase Realtime.
- **Multiple machines, one dashboard** — each agent self-registers and shows up
  as its own **tab** (great for Proxmox + several LXCs).
- **Container actions** — restart / stop / start (admin only).
- **AI log analysis** — per-container, OpenAI-compatible providers (Ollama, LM
  Studio, **Anthropic/Claude**, OpenAI, custom). Logs sanitized first.
- **AI chat** — ask questions about a server; **conversations are saved** so you
  can resume or review them later.
- **Proactive AI triage** — on a container crash, the agent summarizes the
  likely cause and sends it to your webhook.
- **Daily AI health digest** — optional, sent to your webhook.
- **Alerts → webhook** — CPU / RAM / disk / container-down / UPS / uptime / TLS
  expiry / anomalies, routed to n8n / Telegram / Slack.
- **Uptime + TLS checks** — HTTP availability and certificate-expiry monitoring.
- **History** — downsampled snapshots persisted to Supabase; 24h charts.
- **UPS** — power/battery status via NUT.
- **Auth & roles** — email/password login; first account is **admin**, others are
  **viewer** (read-only). Admins manage roles in the app.
- **Bilingual UI** — Arabic + English (full RTL), dark / light themes; choice
  persisted per browser.

## Architecture

```
   ┌──────────────┐   Realtime broadcast (per host_id)   ┌──────────────┐
   │  Flutter UI  │◄─────────────────────────────────────│              │
   │ (Web/Desktop)│   REST: /metrics /analyze /ask        │   Supabase   │
   └──────┬───────┘   /logs /actions  (per device api_url) │  Auth + RLS  │
          │                                                │  Realtime    │
          │ ┌──────────────────────────────┐  broadcast   │  Postgres    │
          ├─│ FastAPI agent  (host A / LXC) │──────────────►│  (settings,  │
          │ └──────────────────────────────┘  register     │  history,    │
          │ ┌──────────────────────────────┐               │  alerts,     │
          └─│ FastAPI agent  (host B / LXC) │──────────────►│  devices,    │
            └──────────────────────────────┘               │  ai_chats)   │
                 │         │                                └──────────────┘
              Docker     NUT (UPS)
```

- Each **agent** reads its local Docker socket, collects host metrics, and
  broadcasts to a shared Supabase channel tagged with its `host_id`.
- The **frontend** aggregates all hosts into tabs, and routes actions/logs to the
  selected device's `api_url`.
- One machine runs the **central** stack (Supabase + agent + UI nginx); extra
  machines run an **agent-only** container pointing at the central Supabase.

## Repository layout

```
backend/                 # FastAPI agent (Python)
  app/
    routers/             # /logs /analyze /actions /ask
    services/            # docker, host(psutil), nut, uptime, alerts,
                         #   history, broadcast, collector, ai_router, auth, device
  Dockerfile
frontend/                # Flutter (Web)
  lib/{config,models,providers,services,screens,widgets,l10n,theme}
supabase/migrations/     # 001..004 (run in order)
scripts/                 # *.sh (Linux), deploy-to-server.ps1/.sh
docker-compose.yml       # central: Supabase + Rased
docker-compose.rased.yml # central: rased-api + rased-ui
docker-compose.agent.yml # extra machine: agent only
```

## Prerequisites

- **Docker** + Docker Compose v2 (`docker compose version`)
- **git** + internet (first run fetches the Supabase template and builds images)
- **Flutter 3.16+** to build the web UI
- Free ports on the central host: **8082** (UI), **8002** (API), **8003** (Supabase/Kong)

---

## Quick start (single Linux host)

### 1. Get the code onto the host

```bash
git clone <your-repo> ~/projects/rased   # or copy the folder
cd ~/projects/rased
chmod +x scripts/*.sh
```

### 2. Create and edit `.env`

```bash
cp .env.example .env
nano .env
```
Set at minimum (replace `YOUR_IP` with the host's LAN IP, e.g. `192.168.100.100`):

```
POSTGRES_PASSWORD=change-me
DASHBOARD_PASSWORD=change-me
RASED_CORS_ORIGINS=http://YOUR_IP:8082
SUPABASE_PUBLIC_URL=http://YOUR_IP:8003
API_EXTERNAL_URL=http://YOUR_IP:8003
SITE_URL=http://YOUR_IP:8082
RASED_PUBLIC_BASE_URL=http://YOUR_IP:8002
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=true   # lets sign-up work without SMTP
```
> Keep `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY` consistent. If you change
> `JWT_SECRET` you **must** regenerate `ANON_KEY`/`SERVICE_ROLE_KEY` to match
> (see *Supabase keys* below) and rebuild the web app.

### 3. Build the Flutter web app

The web build **bakes in** the URLs + anon key, so build with the host's IP:

```bash
cd frontend
flutter pub get
flutter build web --no-tree-shake-icons \
  --dart-define=BACKEND_URL=http://YOUR_IP:8002 \
  --dart-define=SUPABASE_URL=http://YOUR_IP:8003 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env>
cd ..
```

### 4. Start the stack

```bash
bash scripts/up.sh
```
This fetches the Supabase template (first run), builds the agent image, starts
everything, fixes web file permissions, and (re)binds the UI. Wait until
`docker compose ps` shows `supabase-db` **healthy**.

### 5. Apply database migrations (first time)

```bash
bash scripts/run-migration.sh        # applies 001 → 004
docker compose restart rest          # reload PostgREST schema cache
```

### 6. Open the firewall (LAN)

```bash
# ufw
sudo ufw allow 8082/tcp && sudo ufw allow 8002/tcp && sudo ufw allow 8003/tcp
# firewalld
sudo firewall-cmd --add-port=8082/tcp --add-port=8002/tcp --add-port=8003/tcp --permanent && sudo firewall-cmd --reload
```

### 7. First login

Open **http://YOUR_IP:8082** → **Create account**. The first account becomes
**admin** automatically. Open **Settings → AI Provider** to configure a model.

| URL | What |
|-----|------|
| http://YOUR_IP:8082 | Dashboard |
| http://YOUR_IP:8002/docs | Agent API docs |
| http://YOUR_IP:8003 | Supabase Studio (`supabase` / `DASHBOARD_PASSWORD`) |

---

## Adding more machines (multi-device tabs)

Each extra machine/LXC runs an **agent only**, pointing at the central Supabase.
It appears as a new tab automatically.

On the new machine, copy `backend/`, `docker-compose.agent.yml`, and
`.env.agent.example`, then:

```bash
cp .env.agent.example .env.agent
nano .env.agent
```
Set:
```
RASED_HOST_ID=lxc-2                              # unique per machine
RASED_HOST_NAME=LXC 2
RASED_PUBLIC_BASE_URL=http://THIS_LXC_IP:8002   # so the UI can manage it
SUPABASE_URL=http://CENTRAL_IP:8003             # the central Supabase
SERVICE_ROLE_KEY=<same as central .env>
JWT_SECRET=<same as central .env>
RASED_CORS_ORIGINS=http://CENTRAL_IP:8082
```
Then:
```bash
docker compose --env-file .env.agent -f docker-compose.agent.yml up -d --build
sudo ufw allow 8002/tcp   # so the dashboard can reach this agent
```
Within seconds a new tab appears. Repeat for each machine.

> `.env.agent` holds secrets and is gitignored. `SERVICE_ROLE_KEY` / `JWT_SECRET`
> **must match** the central values.

---

## AI providers

Configure in **Settings → AI Provider**. The agent calls the provider, so URLs
must be reachable **from the agent container** (use `host.docker.internal`, not
`localhost`, for services on the same host).

| Provider | Base URL | Model example | API key |
|----------|----------|---------------|---------|
| Ollama | `http://host.docker.internal:11434/v1` | `llama3.2` | — |
| LM Studio | `http://<lm-studio-ip>:1234/v1` | (loaded model) | — |
| Anthropic (Claude) | `https://api.anthropic.com/v1` | `claude-sonnet-4-...` | required |
| OpenAI / cloud | `https://api.openai.com/v1` | `gpt-4o` | required |
| Custom | any OpenAI-compatible `/v1` | — | optional |

> Anthropic works via its **OpenAI-compatible** endpoint (`/v1/chat/completions`).
> LM Studio: enable **Serve on Local Network** (Developer → Server).

**Server-side AI** (for autonomous *daily digest* + *proactive triage*) is set via
agent env (`AI_BASE_URL`, `AI_MODEL`, `AI_API_KEY`) and is separate from the
per-user on-demand config.

---

## Users & roles

- **First account = admin.** All later accounts = **viewer** (read-only: can view
  metrics, logs, charts, and use AI chat, but cannot start/stop/restart containers).
- Admins see a **Users** screen (group icon) to promote/demote accounts.
- Enforced in the backend: `POST /actions/*` requires a valid admin JWT.

To promote a user manually (Supabase Studio → SQL):
```sql
update public.profiles set role='admin' where email='person@example.com';
```

---

## AI chat (saved conversations)

The chat icon opens a full conversation view. The side drawer lists past
conversations (per device); `+` starts a new one. Each exchange is saved to
`ai_chats` (per user, RLS-protected) so you can resume or review later.

---

## Alerts, uptime, history, digest

Set on the **agent** via env (see `.env.example`); everything degrades gracefully
if unset.

```env
ALERT_WEBHOOK_URL=https://your-n8n/webhook/rased   # n8n / Telegram / Slack
CPU_ALERT_PERCENT=90
MEM_ALERT_PERCENT=90
DISK_ALERT_PERCENT=85
UPTIME_CHECKS=Portfolio|https://example.com, Search|https://search.example.com
SSL_ALERT_DAYS=14
HISTORY_ENABLED=true
AI_BASE_URL=http://host.docker.internal:11434/v1
AI_MODEL=llama3.2
DIGEST_ENABLED=true
DIGEST_HOUR_UTC=8
```
Prune history periodically: `SELECT public.prune_metrics_history(14);`

---

## UPS via NUT

Point the agent at a NUT server (`upsd`):
```env
NUT_HOST=host.docker.internal   # or the NUT host's IP (e.g. a Proxmox host)
NUT_PORT=3493
NUT_UPS_NAME=ups                # from `upsc -l`
```
If NUT runs on a **Proxmox host** while Rased runs in an LXC, set `NUT_HOST` to the
Proxmox IP and make `upsd` listen on the network — add to `/etc/nut/upsd.conf`:
```
LISTEN 127.0.0.1 3493
LISTEN <proxmox-ip> 3493
```
then `systemctl restart nut-server`. (Some UPS models don't report
`battery.charge`; status OL/OB still works.)

---

## Host metrics inside a container

On Linux, the agent reads the host's `/proc`, so **CPU / RAM / load are
host-accurate**. Disk shows the host's backing filesystem as `/`.

---

## Updating an existing deployment

Build the web app (step 3), then ship only what changed (never overwrites the
server `.env`):

```bash
# from the repo root on your build machine
tar -czf rased-update.tar.gz backend/app backend/requirements.txt \
    frontend/build/web scripts supabase/migrations \
    docker-compose.agent.yml .env.agent.example
scp rased-update.tar.gz user@CENTRAL_IP:~/

# on the central host
cd ~/projects/rased
tar -xzf ~/rased-update.tar.gz
chmod +x scripts/*.sh
bash scripts/up.sh                 # rebuild agent + rebind UI
bash scripts/run-migration.sh      # apply any new migrations
docker compose restart rest        # reload schema cache
```
Then hard-refresh the browser (Ctrl+Shift+R).

---

## Supabase keys (production)

The default demo `ANON_KEY` / `SERVICE_ROLE_KEY` match the default `JWT_SECRET`
and are public — fine for a closed LAN, **not** for production. To generate your
own, sign them with your `JWT_SECRET` using the JWT generator in the
[Supabase self-hosting docs](https://supabase.com/docs/guides/self-hosting/docker),
put them in `.env`, and rebuild the web app with the new `ANON_KEY`.

---

## Migrations

| File | Creates |
|------|---------|
| `001_initial.sql` | `settings` (encrypted api_key), RLS, `upsert_settings`/`get_settings_decrypted` |
| `002_metrics_history.sql` | `metrics_history`, `alerts`, `prune_metrics_history()` |
| `003_auth_roles.sql` | `profiles`, `is_admin()`, `ensure_profile()` (first user = admin) |
| `004_devices_and_chats.sql` | `devices` (agent registry), `ai_chats` (saved conversations) |

`run-migration.sh` applies all in order (idempotent). After applying, always
`docker compose restart rest` so PostgREST reloads its schema cache.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission denied` on docker | `sudo usermod -aG docker $USER`, re-login (or use sudo) |
| UI returns **403** | Web files unreadable / stale mount: `chmod -R a+rX frontend/build/web` then `docker compose up -d --force-recreate rased-ui` (built into `up.sh`) |
| `Could not find the table/function … in the schema cache` (PGRST205/202) | Run `bash scripts/run-migration.sh` then `docker compose restart rest` |
| `function pgp_sym_encrypt … does not exist` | Re-apply migrations (the RPCs use `search_path = public, extensions`) + restart `rest` |
| `null value in column "user_id"` on save | Not signed in — log in (anonymous is disabled; use email/password) |
| Login: `permission denied to set parameter` during migration | Already fixed — the encryption key is a function fallback, not `ALTER DATABASE` |
| Sign-up stuck | Ensure `ENABLE_EMAIL_AUTOCONFIRM=true`, then `docker compose up -d --force-recreate auth` |
| UPS shows disconnected | Verify `NUT_HOST`/`NUT_UPS_NAME` in `.env`, port 3493 reachable, `upsd` LISTENs on the network |
| Packaged on Windows → odd values on Linux | Fix CRLF: `sed -i 's/\r$//' .env supabase/migrations/*.sql` |
| Restart everything | `bash scripts/up.sh` |

---

## Security notes

- API keys encrypted at rest (pgcrypto) with RLS; logs sanitized before AI.
- Container actions require an **admin** JWT (verified server-side).
- Use `service_role` only on the agent, never in the frontend.
- Change `POSTGRES_PASSWORD` / `DASHBOARD_PASSWORD` before first start; rotate the
  demo Supabase keys for anything beyond a closed LAN.

## License

MIT
