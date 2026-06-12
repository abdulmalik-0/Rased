import { useEffect, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { X } from 'lucide-react'

export function Dialog({
  open,
  onClose,
  title,
  icon,
  children,
  maxWidth = 'max-w-lg',
}: {
  open: boolean
  onClose: () => void
  title: string
  icon?: ReactNode
  children: ReactNode
  maxWidth?: string
}) {
  useEffect(() => {
    if (!open) return
    const h = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [open, onClose])

  if (!open) return null
  return createPortal(
    <div className="fixed inset-0 z-50 grid place-items-center p-4">
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />
      <div
        className={`card animate-fade-in relative z-10 flex max-h-[86vh] w-full flex-col ${maxWidth}`}
      >
        <div className="flex items-center gap-2.5 border-b border-line/60 px-5 py-3.5">
          {icon}
          <h3 className="flex-1 truncate font-semibold text-text-primary">{title}</h3>
          <button onClick={onClose} className="btn-ghost -me-2">
            <X size={18} />
          </button>
        </div>
        <div className="overflow-y-auto p-5">{children}</div>
      </div>
    </div>,
    document.body,
  )
}
