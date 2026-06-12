import {
  Battery,
  KeyRound,
  Link2,
  PlusSquare,
  Rocket,
  Server,
  Sparkles,
  TimerReset,
  UserPlus,
  type LucideIcon,
} from 'lucide-react'
import { useCopy } from '../lib/useCopy'
import { useI18n } from '../lib/i18n'

interface Section {
  icon: LucideIcon
  title: string
  body: string
  code?: string
}

export default function Help() {
  const { t, lang } = useI18n()
  const copy = useCopy()
  const ar = lang === 'ar'
  const sections: Section[] = [
    {
      icon: Server,
      title: ar ? 'ما هو راصد؟' : 'What is Rased?',
      body: ar
        ? 'لوحة لمراقبة خوادمك وحاويات Docker مع تحليل السجلات بالذكاء. كل جهاز كتبويب، مع رسوم حيّة وتنبيهات وUPS وسجل.'
        : 'A dashboard for your servers and Docker containers with AI log analysis. Each machine is a tab, with live charts, alerts, UPS and history.',
    },
    {
      icon: UserPlus,
      title: ar ? 'أول دخول' : 'First login',
      body: ar
        ? 'أول حساب تسجّله يصبح "أدمن" تلقائياً. الحسابات التالية تحتاج موافقتك من شاشة المستخدمين.'
        : 'The first account becomes admin automatically. Later accounts need your approval from the Users screen.',
    },
    {
      icon: Sparkles,
      title: ar ? 'إعداد الذكاء' : 'AI setup',
      body: ar
        ? 'من الإعدادات اختر المزوّد (Ollama، LM Studio، Anthropic، OpenAI، مخصّص) وأدخل الرابط والموديل والمفتاح. ثم حلّل سجلات الحاويات أو اسأل المساعد.'
        : 'In Settings pick a provider (Ollama, LM Studio, Anthropic, OpenAI, custom) and enter URL, model and key. Then analyze container logs or ask the assistant.',
    },
    {
      icon: PlusSquare,
      title: ar ? 'إضافة جهاز (LXC)' : 'Add a machine (LXC)',
      body: ar
        ? 'اضغط زر (+) في اللوحة. الصق الأمر الواحد على الجهاز الجديد — يثبّت كل شيء ويظهر كتبويب.'
        : 'Press the (+) button on the dashboard. Paste the one command on the new machine — it installs everything and appears as a tab.',
    },
    {
      icon: Rocket,
      title: ar ? 'اقتراح حاوية بالذكاء' : 'AI deploy suggestion',
      body: ar
        ? 'زر 🚀 (أدمن): صِف خدمة فيقترح الذكاء أمر docker جاهزاً تنسخه وتشغّله بنفسك. لا ينفّذ شيئاً.'
        : 'The 🚀 button (admin): describe a service and the AI suggests a ready docker command for you to copy and run. It never executes.',
    },
    {
      icon: Link2,
      title: ar ? 'روابط الحاويات' : 'Container links',
      body: ar
        ? 'الأدمن يضيف رابطاً مخصّصاً لكل حاوية من زر "تعديل الرابط". والمنافذ المكشوفة تصير روابط قابلة للنقر.'
        : 'An admin can add a custom link per container via "Edit link". Exposed ports become clickable links.',
    },
    {
      icon: Battery,
      title: ar ? 'إعداد UPS' : 'UPS setup',
      body: ar
        ? 'من إعدادات الجهاز أدخل عنوان NUT واسم الـ UPS لعرض حالة الطاقة والبطارية. وتقدر تعيد تسمية الجهاز من نفس النافذة.'
        : 'From device settings enter the NUT host and UPS name to show power/battery status. You can rename the device from the same dialog.',
    },
    {
      icon: TimerReset,
      title: ar ? 'السجل والتنبيهات' : 'History & alerts',
      body: ar
        ? 'صفحة السجل تعرض رسوم الأداء (يوم/أسبوع/شهر). التنبيهات (CPU/ذاكرة/قرص/توقّف/UPS) تظهر في اللوحة.'
        : 'The History page shows performance charts (day/week/month). Alerts (CPU/memory/disk/down/UPS) appear on the dashboard.',
    },
    {
      icon: KeyRound,
      title: ar ? 'الأمان' : 'Security',
      body: ar
        ? 'الأسرار (JWT/التشفير/توكن الوكيل) فريدة لنشرتك ومحفوظة في .env (غير مرفوعة). إجراءات الحاويات للأدمن فقط.'
        : 'Secrets (JWT/encryption/agent token) are unique to your deployment and live in .env (never pushed). Container actions are admin-only.',
    },
  ]

  return (
    <div className="mx-auto max-w-2xl space-y-4 p-4 sm:p-6">
      <h1 className="text-xl font-bold tracking-tight text-text-primary">
        {t('help')}
      </h1>
      {sections.map((s, i) => (
        <div key={i} className="card p-5">
          <div className="mb-2 flex items-center gap-2.5">
            <span className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-primary">
              <s.icon size={18} />
            </span>
            <span className="font-semibold text-text-primary">{s.title}</span>
          </div>
          <p className="text-sm leading-relaxed text-text-secondary">{s.body}</p>
          {s.code && (
            <button
              onClick={() => copy(s.code!)}
              className="mt-3 block w-full rounded-lg border border-line bg-elevated px-3 py-2 text-start font-mono text-xs text-text-primary"
              dir="ltr"
            >
              {s.code}
            </button>
          )}
        </div>
      ))}
    </div>
  )
}
