# Rased — دليل النشر السريع (Linux)

> المرجع الكامل في **[README.md](README.md)**. الحزمة هي `rased-api` (FastAPI + SQLite)
> + `rased-ui` (nginx) فقط (~250MB)، بدون قاعدة بيانات خارجية.

## البورتات
| البورت | الخدمة |
|--------|--------|
| **8002** | Rased API (FastAPI) |
| **8082** | Rased UI (Flutter Web) |

## أول تثبيت (الجهاز المركزي) — أمر واحد

١) تأكد أن واجهة الويب مبنية في `frontend/build/web` (ابنها على جهازك ثم انقل المجلد،
أو ابنها على السيرفر إن كان Flutter مثبتاً):
```bash
flutter build web --no-tree-shake-icons --dart-define=BACKEND_URL=http://YOUR_IP:8002
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

## إضافة جهاز (LXC آخر) — من داخل اللوحة

١) في اللوحة اضغط زر **(+)** أعلى الشاشة. عدّل الحقول واختر طريقة إحضار الكود؛ المفاتيح
معبّأة (ومغبّشة) والأوامر جاهزة للنسخ.

٢) أحضِر المشروع إلى الجهاز الجديد — إمّا **تنزيل من GitHub** (الأسهل، لا حاجة للنقل):
```bash
git clone --depth 1 https://github.com/abdulmalik-0/Rased.git ~/rased
```
أو **نسخ من الجهاز المركزي**:
```bash
scp -r ~/rased USER@NEW_MACHINE_IP:~/
```

٣) على الجهاز الجديد نفّذ المثبّت (المفاتيح معبّأة، والـ IP يُكتشف تلقائياً):
```bash
cd ~/rased && bash scripts/install-agent.sh --central http://CENTRAL_IP:8002 \
  --token <AGENT_TOKEN> --jwt <JWT_SECRET> --id lxc-2 --name "LXC 2"
```
يظهر الجهاز كتبويب جديد تلقائياً خلال ثوانٍ. ملاحظة: `.env` والأسرار مستثناة من Git (آمنة).

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
