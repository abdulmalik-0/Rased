# AI-Powered Server Dashboard

نظام مراقبة خوادم Docker مع لوحة تحكم تفاعلية وتحليل سجلات بالذكاء الاصطناعي عند الطلب.

## Architecture

```
┌─────────────────┐     Realtime Broadcast      ┌──────────────┐
│  Flutter UI     │◄────────────────────────────│   Supabase   │
│  (Web/Desktop)  │     (metrics channel)       │              │
└────────┬────────┘                             │  settings +  │
         │ REST /analyze, /logs                │  RLS + Auth  │
         ▼                                     └──────▲───────┘
┌─────────────────┐                                  │
│  FastAPI Agent  │──────────────────────────────────┘
│  (on host)      │   Broadcast metrics every 3s
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
 Docker     NUT (UPS)
```

## Project Structure

```
├── backend/          # Python FastAPI agent
├── frontend/         # Flutter (Web & Desktop)
├── supabase/         # SQL migrations
├── docker-compose.yml
└── README.md
```

## Prerequisites

- **Docker** (for running containers + agent socket access)
- **Python 3.12+** (local backend development)
- **Flutter 3.16+** (frontend — Web & Desktop)
- **Supabase project** (Auth, Realtime Broadcast, PostgreSQL)

## 1. Supabase Setup

### Create project

1. Create a project at [supabase.com](https://supabase.com)
2. Enable **Anonymous sign-ins** (Authentication → Providers → Anonymous) for quick start, or configure email/OAuth
3. Enable **Realtime Broadcast** (Project Settings → API → Realtime)

### Run SQL migration

Open **SQL Editor** in Supabase and run the full script:

```bash
# File location
supabase/migrations/001_initial.sql
```

This creates:

- `settings` table with **encrypted** `api_key` (pgcrypto)
- RLS policies (users can only access their own settings)
- RPC functions: `upsert_settings()`, `get_settings_decrypted()`

### Set encryption key (production)

```sql
ALTER DATABASE postgres SET app.settings_encryption_key = 'your-32-char-secret-key-here!!';
```

> Change the default dev key before going to production.

### Copy API keys

From **Project Settings → API**:

| Key | Used by |
|-----|---------|
| `URL` | Backend + Frontend |
| `anon` key | Frontend |
| `service_role` key | Backend (broadcast only) |

## 2. Backend Setup

### Local development

```bash
cd backend
python -m venv .venv

# Windows
.venv\Scripts\activate

# Linux/macOS
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Edit .env with your Supabase credentials
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (broadcast) |
| `SUPABASE_BROADCAST_CHANNEL` | Channel name (default: `server-metrics`) |
| `METRICS_INTERVAL_SECONDS` | Poll interval (default: `3`) |
| `NUT_HOST` / `NUT_PORT` | NUT server for UPS |
| `CORS_ORIGINS` | Allowed frontend origins |

### Run

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8002
```

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/metrics` | Current Docker + UPS metrics (REST fallback) |
| `GET` | `/logs/{container_id}?tail=100` | Container logs (sanitized copy included) |
| `POST` | `/analyze` | Fetch logs, sanitize, send to AI provider |

### Data Sanitization

Before any log data reaches an AI provider, the backend redacts:

- IP addresses → `[REDACTED_IP]`
- Emails → `[REDACTED_EMAIL]`
- API keys / tokens / JWTs → `[REDACTED_TOKEN]`

Run tests:

```bash
cd backend
python -m unittest tests.test_sanitization
```

## 3. Frontend Setup

### Initialize Flutter project files

If `frontend/` was cloned without platform folders:

```bash
cd frontend
flutter create . --platforms=web,windows,linux,macos
flutter pub get
```

### Configure

Pass credentials at build/run time:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://localhost:8003 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env> \
  --dart-define=BACKEND_URL=http://localhost:8002
```

### Build for production

```bash
flutter build web \
  --dart-define=SUPABASE_URL=http://localhost:8003 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env> \
  --dart-define=BACKEND_URL=http://localhost:8002
```

Defaults in `lib/config/app_config.dart` already use ports **8002** / **8003** / **8082** (UI via nginx).

## 4. Docker Compose (Full Stack — Rased + Local Supabase)

**Port map** (avoids conflicts with 8000/8080/8081/80/5678 on your server):

| Service | Host port |
|---------|-----------|
| Rased UI | **8082** |
| Rased API | **8002** |
| Supabase Kong | **8003** |

See **[DEPLOY.md](DEPLOY.md)** for the full Arabic/English deploy guide.

```powershell
.\scripts\setup-supabase-docker.ps1
copy .env.example .env
# Build Flutter web with dart-define (see frontend/.env.example)
.\scripts\up.ps1
.\scripts\run-migration.ps1
```

| Service | URL |
|---------|-----|
| Rased UI | http://localhost:8082 |
| Rased API | http://localhost:8002 |
| API Docs | http://localhost:8002/docs |
| Supabase API (Kong) | http://localhost:8003 |

Inside Docker, `rased-api` uses `SUPABASE_URL=http://kong:8000`. The backend container mounts `/var/run/docker.sock` to read container metrics.

## 5. AI Provider Configuration

In the app **Settings** page:

| Provider | Auto-filled Base URL |
|----------|---------------------|
| Ollama | `http://localhost:11434/v1` |
| LM Studio | `http://localhost:1234/v1` |
| Cloud API | (manual — e.g. `https://api.openai.com/v1`) |
| Custom | (manual) |

Settings are stored encrypted in Supabase. When analyzing logs, the frontend sends the AI config to the backend, which calls the provider using the **OpenAI Chat Completions** standard.

### Example: Ollama

```bash
ollama serve
ollama pull llama3.2
```

Settings: Provider = Ollama, Model = `llama3.2`, API Key = (empty)

## 6. NUT (UPS) Setup (Optional)

Install [Network UPS Tools](https://networkupstools.org/) on the host:

```bash
# Linux example
sudo apt install nut
# Configure /etc/nut/ups.conf and upsd
```

Point backend env vars to your NUT server. If unavailable, the dashboard shows "NUT disconnected" gracefully.

## Security Notes

- API keys encrypted at rest via `pgp_sym_encrypt`
- RLS enforced on all settings rows
- Logs sanitized **before** AI analysis (never send raw secrets)
- Use `service_role` key **only** on the backend agent, never in the frontend
- Rotate `app.settings_encryption_key` in production

## License

MIT
