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

```bash
cd ~/rased                    # حيث نقلت المشروع على السيرفر
chmod +x scripts/*.sh         # أول مرة فقط
./scripts/setup-supabase-docker.sh
```

### 2) إنشاء `.env`

```bash
cp .env.example .env
```

عدّل على الأقل:

- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `DASHBOARD_PASSWORD`
- `RASED_CORS_ORIGINS` — أضف IP السيرفر إن لزم
- `SUPABASE_PUBLIC_URL` / `API_EXTERNAL_URL` — مثلاً `http://YOUR_IP:8003`
- `SITE_URL` — مثلاً `http://YOUR_IP:8082`

اختياري (ميزات 2.0):

- `RASED_HOST_NAME` — الاسم الظاهر للخادم في اللوحة
- `ALERT_WEBHOOK_URL` — وجّهه إلى webhook في n8n لتوزيع التنبيهات (Telegram/بريد…)
- `UPTIME_CHECKS` — مثل `Portfolio|https://example.com, SearXNG|https://search.example.com`
- `AI_BASE_URL` / `AI_MODEL` — لتفعيل التشخيص الاستباقي والملخّص اليومي بالذكاء
- `DIGEST_ENABLED=true` + `DIGEST_HOUR_UTC` — للملخّص اليومي

(اختياري) توليد مفاتيح خاصة: القالب الرسمي قد لا يأتي بسكربت توليد، فولّد `ANON_KEY` و`SERVICE_ROLE_KEY` من `JWT_SECRET` عبر مولّد JWT في [توثيق Supabase self-hosting](https://supabase.com/docs/guides/self-hosting/docker)، ثم ضعهما في `.env` ومرّر `ANON_KEY` في build الـ Flutter. (إن غيّرت `JWT_SECRET` يلزم إعادة توليد المفتاحين وإعادة بناء الواجهة.)

### 3) بناء الواجهة

```bash
cd frontend
flutter pub get
flutter build web \
  --dart-define=BACKEND_URL=http://YOUR_SERVER_IP:8002 \
  --dart-define=SUPABASE_URL=http://YOUR_SERVER_IP:8003 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY from .env>
```

### 4) تشغيل الحاويات

```bash
cd ..
./scripts/up.sh
./scripts/run-migration.sh
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

```bash
docker compose ps
docker compose logs -f rased-api
docker compose logs -f kong
docker compose down
```

---

## تطوير محلي بدون Docker (API فقط)

```bash
cd backend
cp .env.example .env
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8002
```

Supabase يجب أن يعمل (Docker على 8003) أو استبدل `SUPABASE_URL` في `.env`.
