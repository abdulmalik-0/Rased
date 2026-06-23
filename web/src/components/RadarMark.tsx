/**
 * RadarMark — the Rased (راصد = "the watcher") brand glyph.
 * A small radar/observatory scope: range rings, crosshair, a live blip,
 * and a sweep arm that rotates continuously — the product, in one mark.
 */
export function RadarMark({
  size = 38,
  className = '',
  sweep = true,
}: {
  size?: number
  className?: string
  sweep?: boolean
}) {
  const uid = `rm${size}`
  return (
    <span
      className={`relative inline-grid shrink-0 place-items-center ${className}`}
      style={{ width: size, height: size }}
      aria-hidden
    >
      <svg
        viewBox="0 0 48 48"
        width={size}
        height={size}
        className="text-primary"
        fill="none"
      >
        <defs>
          <radialGradient id={`${uid}-dome`} cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="rgb(var(--primary))" stopOpacity="0.16" />
            <stop offset="70%" stopColor="rgb(var(--surface))" stopOpacity="0.04" />
            <stop offset="100%" stopColor="rgb(var(--surface))" stopOpacity="0" />
          </radialGradient>
          <linearGradient
            id={`${uid}-sweep`}
            x1="50%"
            y1="50%"
            x2="100%"
            y2="0%"
          >
            <stop offset="0%" stopColor="rgb(var(--primary))" stopOpacity="0.55" />
            <stop offset="100%" stopColor="rgb(var(--primary))" stopOpacity="0" />
          </linearGradient>
        </defs>

        {/* dome glow + outer ring */}
        <circle cx="24" cy="24" r="22" fill={`url(#${uid}-dome)`} />
        <circle
          cx="24"
          cy="24"
          r="21.5"
          stroke="currentColor"
          strokeOpacity="0.35"
          strokeWidth="1.5"
        />
        {/* range rings */}
        <circle cx="24" cy="24" r="14.5" stroke="currentColor" strokeOpacity="0.22" strokeWidth="1" />
        <circle cx="24" cy="24" r="7.5" stroke="currentColor" strokeOpacity="0.22" strokeWidth="1" />
        {/* crosshair */}
        <line x1="24" y1="2.5" x2="24" y2="45.5" stroke="currentColor" strokeOpacity="0.16" strokeWidth="1" />
        <line x1="2.5" y1="24" x2="45.5" y2="24" stroke="currentColor" strokeOpacity="0.16" strokeWidth="1" />

        {/* rotating sweep arm */}
        <g
          className={sweep ? 'animate-sweep' : ''}
          style={{ transformBox: 'view-box', transformOrigin: '24px 24px' }}
        >
          <path d="M24 24 L24 2.5 A21.5 21.5 0 0 1 45.5 24 Z" fill={`url(#${uid}-sweep)`} />
          <line x1="24" y1="24" x2="24" y2="2.5" stroke="currentColor" strokeOpacity="0.7" strokeWidth="1.25" />
        </g>

        {/* detected blip */}
        <circle cx="33.5" cy="16" r="1.9" fill="rgb(var(--accent))" />
        {/* center */}
        <circle cx="24" cy="24" r="2" fill="currentColor" />
      </svg>
    </span>
  )
}
