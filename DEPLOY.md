# Rased — دليل النشر السريع (Linux)

> المرجع الكامل في **[README.md](README.md)**. الحزمة هي `rased-api` (FastAPI + SQLite)
> + `rased-ui` (nginx) فقط (~250MB)، بدون قاعدة بيانات خارجية.

## البورتات
| البورت | الخدمة |
|--------|--------|
| **8002** | Rased API (FastAPI) |
| **8082** | Rased UI (React Web) |

## أول تثبيت (الجهاز المركزي) — أمر واحد

١) ابنِ واجهة الويب (React) في `web/dist` (على جهازك ثم انقل المجلد، أو على السيرفر إن كان Node مثبتاً):
```bash
cd web && npm install
VITE_BACKEND_URL=http://YOUR_IP:8002 npm run build
cd ..
```

٢) من مجلد المشروع على السيرفر، نفّذ المثبّت. يسألك عن الـ IP فقط، ويولّد المفاتيح
العشوائية تلقائياً، ثم يبني ويشغّل كل شيء:
```bash
chmod +x scripts/*.sh
bash scripts/install.sh
sudo ufw allow 8082/tcp && sudo ufw allow 8002/tcp   # عند الحاجة
```

٣) افتح `http://YOUR_IP:8082` ← **أنشئ حساباً** (أول حساب = admin) ← من زر المساعدة (؟)
يوجد شرح كامل داخل الموقع، ومن الإعدادات تضبط مزوّد الـ AI.

## إضافة جهاز (LXC آخر) — أمر واحد

١) في اللوحة اضغط زر **(+)**، عدّل المعرّف/الاسم، وانسخ الأمر (المفاتيح مغبّشة، والنسخ يأخذ الأمر الحقيقي).

٢) الصق الأمر الواحد على الجهاز الجديد (لينكس). يحمّل Rased من GitHub ويشغّل الوكيل بنفسه:
```bash
curl -fsSL https://raw.githubusercontent.com/abdulmalik-0/Rased/main/scripts/bootstrap-agent.sh \
  | bash -s -- --central http://CENTRAL_IP:8002 --token <AGENT_TOKEN> --jwt <JWT_SECRET> \
               --id lxc-2 --name "LXC 2"
```
يظهر كتبويب جديد خلال ثوانٍ. الأمر **يثبّت git وDocker تلقائياً** إن لزم (شغّله كـ root أو عبر sudo). (`.env` والأسرار مستثناة من Git — آمن.)

## التحديث لاحقاً
انقل `backend` + `frontend/build/web` + `scripts` + `docker-compose*.yml`، ثم:
```bash
cd ~/rased && chmod +x scripts/*.sh
bash scripts/install.sh        # يحافظ على .env الموجود ويعيد التشغيل
```
البيانات في الـ Docker volume `rased-data` وتبقى عبر التحديثات.

## أوامر مفيدة
```bash
docker compose ps
docker compose logs -f rased-api
docker compose down            # إيقاف (يحفظ البيانات)
docker compose down -v         # حذف كل شيء بما فيه قاعدة البيانات
```
