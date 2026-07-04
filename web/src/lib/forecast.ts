// Simple least-squares projection of a percentage series to 100%.
// Used to answer "when does the disk/memory fill up?" from /history samples.

export interface Forecast {
  status: 'stable' | 'filling' | 'insufficient'
  etaMs?: number // time from the last sample until it hits 100%
  samples: number
  current?: number
}

export interface Point {
  t: number // epoch ms
  y: number // percent 0..100
}

export function projectToFull(points: Point[]): Forecast {
  const pts = points.filter((p) => Number.isFinite(p.t) && Number.isFinite(p.y))
  if (pts.length < 5) return { status: 'insufficient', samples: pts.length }

  // Regress y over time. Work in hours to keep the slope numerically sane.
  const t0 = pts[0].t
  const xs = pts.map((p) => (p.t - t0) / 3_600_000) // hours since start
  const ys = pts.map((p) => p.y)
  const n = pts.length
  const sx = xs.reduce((a, b) => a + b, 0)
  const sy = ys.reduce((a, b) => a + b, 0)
  const sxx = xs.reduce((a, b) => a + b * b, 0)
  const sxy = xs.reduce((a, x, i) => a + x * ys[i], 0)
  const denom = n * sxx - sx * sx
  const current = ys[n - 1]

  if (denom === 0) return { status: 'insufficient', samples: n, current }
  const slope = (n * sxy - sx * sy) / denom // percent per hour

  // Flat or trending down → nothing to warn about.
  if (slope <= 0.01 || current >= 100) return { status: 'stable', samples: n, current }

  const hoursToFull = (100 - current) / slope
  return { status: 'filling', etaMs: hoursToFull * 3_600_000, samples: n, current }
}
