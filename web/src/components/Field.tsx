export function Field({
  label,
  value,
  onChange,
  type = 'text',
  placeholder,
  dir,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  type?: string
  placeholder?: string
  dir?: 'ltr' | 'rtl'
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-medium text-text-secondary">
        {label}
      </span>
      <input
        type={type}
        value={value}
        placeholder={placeholder}
        dir={dir}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-xl border border-line bg-bg px-3.5 py-2.5 text-sm text-text-primary outline-none ring-primary/30 transition focus:border-primary focus:ring-2"
      />
    </label>
  )
}

export function PrimaryButton(props: {
  onClick: () => void
  disabled?: boolean
  children: React.ReactNode
}) {
  return (
    <button
      onClick={props.onClick}
      disabled={props.disabled}
      className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-50"
    >
      {props.children}
    </button>
  )
}

export function GhostButton(props: {
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      onClick={props.onClick}
      className="rounded-xl px-4 py-2 text-sm text-text-secondary transition hover:bg-elevated"
    >
      {props.children}
    </button>
  )
}
