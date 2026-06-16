import { useEffect, useState } from 'react'
import { AreaChart } from '@tremor/react'
import { LineChart, Loader2 } from 'lucide-react'
import { Dialog } from '../Dialog'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'

const round = (v: unknown) => {
  const n = typeof v === 'number' ? v : Number(v)
  return Number.isFinite(n) ? Math.round(n) : 0
}

export function ContainerHistoryDialog({
  open,
  onClose,
  name,
  hostId,
}: {
  open: boolean
  onClose: () => void
  name: string
  hostId: string
}) {
  const { t } = useI18n()
  const [data, setData] = useState<Record<string, string | number>[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!open) return
    setLoading(true)
    api
      .getContainerHistory(name, 24, hostId)
      .then((rows) =>
        setData(
          rows.map((r) => ({
            time: String(r.ts ?? '').slice(11, 16),
            [t('cpu')]: round(r.cpu),
            [t('ram')]: round(r.mem),
          })),
        ),
      )
      .catch(() => setData([]))
      .finally(() => setLoading(false))
  }, [open, name, hostId, t])

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="max-w-2xl"
      icon={<LineChart className="text-primary" size={18} />}
      title={`${t('usageHistory')} — ${name}`}
    >
      {loading ? (
        <div className="grid place-items-center py-16">
          <Loader2 className="animate-spin text-primary" size={26} />
        </div>
      ) : data.length === 0 ? (
        <div className="py-16 text-center text-text-secondary">{t('noHistory')}</div>
      ) : (
        <AreaChart
          className="h-72"
          data={data}
          index="time"
          categories={[t('cpu'), t('ram')]}
          colors={['blue', 'emerald']}
          valueFormatter={(v) => `${v}%`}
          maxValue={100}
          showAnimation
        />
      )}
    </Dialog>
  )
}
