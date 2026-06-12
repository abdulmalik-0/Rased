import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import type { Lang } from './types'

const en: Record<string, string> = {
  appTitle: 'Rased',
  agentOnline: 'Online',
  agentOffline: 'Offline',
  // auth
  signIn: 'Sign in',
  register: 'Create account',
  email: 'Email',
  password: 'Password',
  haveNoAccount: "Don't have an account? Create one",
  haveAccount: 'Already have an account? Sign in',
  authFailed: 'Authentication failed',
  pendingApproval: 'Account created — awaiting admin approval.',
  // common
  copy: 'Copy',
  copied: 'Copied',
  copyFailed: 'Copy failed — select and copy manually',
  copyName: 'Copy name',
  copyAll: 'Copy all',
  cancel: 'Cancel',
  confirm: 'Confirm',
  save: 'Save',
  remove: 'Remove',
  refresh: 'Refresh',
  retry: 'Retry',
  close: 'Close',
  error: 'Error',
  cannotOpen: 'Could not open',
  // topbar
  settings: 'Settings',
  users: 'Users',
  history: 'History',
  askAi: 'Ask AI',
  help: 'Help',
  theme: 'Theme',
  language: 'Language',
  signOut: 'Sign out',
  addDevice: 'Add device',
  deviceSettings: 'Device settings',
  deployTitle: 'Deploy a container (AI)',
  dashboard: 'Dashboard',
  device: 'Device',
  soon: 'Soon',
  comingSoon: 'Coming soon',
  comingSoonBody: 'This screen is being rebuilt in the new design.',
  overview: 'Overview',
  // host
  hostTitle: 'Host',
  load: 'Load',
  hostCpu: 'CPU',
  hostMemory: 'Memory',
  disk: 'Disk',
  cores: 'cores',
  temperatures: 'Temperatures',
  waitingMetrics: 'Waiting for metrics…',
  noContainers: 'No containers',
  hostUnavailable: 'Host metrics unavailable',
  // ups
  upsTitle: 'UPS',
  upsOnline: 'On utility power (OL)',
  upsBattery: 'On battery',
  upsDisconnected: 'No UPS',
  battery: 'Battery',
  // container
  cpu: 'CPU',
  ram: 'RAM',
  restarts: 'Restarts',
  liveUsage: 'Live usage',
  analyzeLogs: 'Analyze Logs',
  viewLogs: 'View logs',
  actions: 'Actions',
  restart: 'Restart',
  stop: 'Stop',
  start: 'Start',
  editLink: 'Edit link',
  alerts: 'Active alerts',
}

const ar: Record<string, string> = {
  appTitle: 'راصد',
  agentOnline: 'متصل',
  agentOffline: 'غير متصل',
  signIn: 'تسجيل الدخول',
  register: 'إنشاء حساب',
  email: 'البريد',
  password: 'كلمة المرور',
  haveNoAccount: 'ليس لديك حساب؟ أنشئ واحداً',
  haveAccount: 'لديك حساب؟ سجّل الدخول',
  authFailed: 'فشل تسجيل الدخول',
  pendingApproval: 'تم إنشاء الحساب — بانتظار موافقة الأدمن.',
  copy: 'نسخ',
  copied: 'نُسخ',
  copyFailed: 'تعذّر النسخ — حدّد وانسخ يدوياً',
  copyName: 'نسخ الاسم',
  copyAll: 'نسخ الكل',
  cancel: 'إلغاء',
  confirm: 'تأكيد',
  save: 'حفظ',
  remove: 'إزالة',
  refresh: 'تحديث',
  retry: 'إعادة',
  close: 'إغلاق',
  error: 'خطأ',
  cannotOpen: 'تعذّر الفتح',
  settings: 'الإعدادات',
  users: 'المستخدمون',
  history: 'السجل',
  askAi: 'اسأل الذكاء',
  help: 'المساعدة',
  theme: 'المظهر',
  language: 'اللغة',
  signOut: 'خروج',
  addDevice: 'إضافة جهاز',
  deviceSettings: 'إعدادات الجهاز',
  deployTitle: 'تثبيت حاوية (بالذكاء)',
  dashboard: 'اللوحة',
  device: 'الجهاز',
  soon: 'قريباً',
  comingSoon: 'قريباً',
  comingSoonBody: 'هذه الشاشة يُعاد بناؤها في التصميم الجديد.',
  overview: 'نظرة عامة',
  hostTitle: 'الخادم المضيف',
  load: 'الحِمل',
  hostCpu: 'المعالج',
  hostMemory: 'الذاكرة',
  disk: 'القرص',
  cores: 'نواة',
  temperatures: 'درجات الحرارة',
  waitingMetrics: 'بانتظار القياسات…',
  noContainers: 'لا توجد حاويات',
  hostUnavailable: 'قياسات الخادم غير متاحة',
  upsTitle: 'حالة الـ UPS',
  upsOnline: 'متصل بالكهرباء (OL)',
  upsBattery: 'يعمل على البطارية',
  upsDisconnected: 'لا يوجد UPS',
  battery: 'البطارية',
  cpu: 'المعالج',
  ram: 'الذاكرة',
  restarts: 'إعادات',
  liveUsage: 'الاستخدام الحيّ',
  analyzeLogs: 'تحليل السجلات',
  viewLogs: 'عرض السجلات',
  actions: 'إجراءات',
  restart: 'إعادة تشغيل',
  stop: 'إيقاف',
  start: 'تشغيل',
  editLink: 'تعديل الرابط',
  alerts: 'تنبيهات نشطة',
}

const dicts: Record<Lang, Record<string, string>> = { en, ar }

interface I18nCtx {
  lang: Lang
  dir: 'ltr' | 'rtl'
  t: (key: string) => string
  setLang: (l: Lang) => void
  toggle: () => void
}
const Ctx = createContext<I18nCtx | null>(null)

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(
    () => (localStorage.getItem('lang') as Lang) || 'ar',
  )
  const dir = lang === 'ar' ? 'rtl' : 'ltr'

  useEffect(() => {
    document.documentElement.lang = lang
    document.documentElement.dir = dir
    localStorage.setItem('lang', lang)
  }, [lang, dir])

  const t = (key: string) => dicts[lang][key] ?? dicts.en[key] ?? key

  return (
    <Ctx.Provider
      value={{
        lang,
        dir,
        t,
        setLang: setLangState,
        toggle: () => setLangState((l) => (l === 'ar' ? 'en' : 'ar')),
      }}
    >
      {children}
    </Ctx.Provider>
  )
}

export function useI18n() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useI18n outside provider')
  return c
}
