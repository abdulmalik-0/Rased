# Rased — دليل النشر (Deploy) والبورتات

## خريطة البورتات على السيرفر

| البورت | الخدمة | الحالة على سيرفرك |
|--------|--------|-------------------|
| **8002** | **Rased API** (FastAPI) | جديد — لوحة Rased |
| **8082** | **Rased UI** (Flutter Web) | جديد — لوحة Rased |
| **8003** | **Supabase Kong** (API Gateway) | جديد — بديل 8000 الافتراضي |
| 8000 | ArSL Translator | محجوز — لا تلمسه |
| 8080 | Portfolio App | محجوز |
| 8081 | SearXNG | محجوز |
| 80 | Reservations App | محجوز |
| 5678 | n8n | محجوز |

داخل شبكة Docker `rased_default`، الاتصال الداخلي:

| من | إلى | العنوان |
|----|-----|---------|
| rased-api | Supabase | `http://kong:8000` |
| المتصفح / Flutter | Rased API | `http://<HOST>:8002` |
| المتصفح / Flutter | Supabase | `http://<HOST>:8003` |

---

## التثبيت الأول

### 1) جلب ملفات Supabase الرسمية

```powershell
cd c:\Users\atamimi\program
.\scripts\setup-supabase-docker.ps1
```

### 2) إنشاء `.env`

```powershell
copy .env.example .env
```

عدّل على الأقل:

- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `DASHBOARD_PASSWORD`
- `RASED_CORS_ORIGINS` — أضف IP السيرفر إن لزم
- `SUPABASE_PUBLIC_URL` / `API_EXTERNAL_URL` — مثلاً `http://YOUR_IP:8003`
- `SITE_URL` — مثلاً `http://YOUR_IP:8082`

(اختياري) توليد مفاتيح جديدة:

```bash
cd supabase/docker && sh ./utils/generate-keys.sh
```

ثم انسخ `ANON_KEY` و `SERVICE_ROLE_KEY` إلى `.env` وإلى build الـ Flutter.

### 3) بناء الواجهة

```powershell
cd frontend
flutter pub get
flutter build web `
  --dart-define=BACKEND_URL=http://YOUR_SERVER_IP:8002 `
  --dart-define=SUPABASE_URL=http://YOUR_SERVER_IP:8003 `
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env>
```

### 4) تشغيل الحاويات

```powershell
cd ..
.\scripts\up.ps1
.\scripts\run-migration.ps1
```

### 5) تفعيل Anonymous Auth

في Supabase Studio (عبر Kong): تأكد أن **Enable anonymous sign-ins** مفعّل — أو عبر `.env`:

```
ENABLE_ANONYMOUS_USERS=true
```

---

## الملفات المرجعية

| ملف | الغرض |
|-----|--------|
| `.env.example` | قالب موحّد لـ Supabase + Rased |
| `backend/.env.example` | تطوير API محلياً على 8002 |
| `frontend/.env.example` | قيم `--dart-define` للـ Flutter |
| `docker-compose.yml` | Supabase + شبكة واحدة |
| `docker-compose.rased.yml` | rased-api + rased-ui |

---

## أوامر مفيدة

```powershell
docker compose ps
docker compose logs -f rased-api
docker compose logs -f kong
docker compose down
```

---

## تطوير محلي بدون Docker (API فقط)

```powershell
cd backend
copy .env.example .env
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8002
```

Supabase يجب أن يعمل (Docker على 8003) أو استبدل `SUPABASE_URL` في `.env`.
