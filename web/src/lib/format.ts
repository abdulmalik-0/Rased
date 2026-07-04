// Human-readable byte throughput, e.g. 1536 -> "1.5KB/s".
export function humanRate(bytesPerSec: number): string {
  if (!bytesPerSec || bytesPerSec < 1) return '0'
  const units = ['B', 'KB', 'MB', 'GB']
  let v = bytesPerSec
  let i = 0
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024
    i++
  }
  return `${v >= 100 ? v.toFixed(0) : v.toFixed(1)}${units[i]}/s`
}
