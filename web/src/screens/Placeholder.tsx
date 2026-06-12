import { Hammer } from 'lucide-react'
import { useI18n } from '../lib/i18n'

export default function Placeholder({ titleKey }: { titleKey: string }) {
  const { t } = useI18n()
  return (
    <div className="grid h-full place-items-center p-6">
      <div className="card max-w-md p-10 text-center">
        <div className="mx-auto mb-4 grid h-14 w-14 place-items-center rounded-2xl bg-primary/10">
          <Hammer className="text-primary" size={26} />
        </div>
        <h2 className="text-lg font-semibold text-text-primary">{t(titleKey)}</h2>
        <p className="mt-1.5 text-sm text-text-secondary">{t('comingSoonBody')}</p>
      </div>
    </div>
  )
}
