// Wire types — snake_case to match the FastAPI JSON exactly (no mapping layer).

export interface ContainerMetrics {
  id: string
  name: string
  status: string
  image: string
  cpu_percent: number
  memory_usage_mb: number
  memory_limit_mb: number
  memory_percent: number
  restart_count: number
  ports: string[]
}

export interface DiskUsage {
  mount: string
  used_gb: number
  total_gb: number
  percent: number
}

export interface Temp {
  label: string
  current: number
  high: number | null
}

export interface HostStats {
  available: boolean
  cpu_percent: number
  cpu_cores: number
  memory_used_mb: number
  memory_total_mb: number
  memory_percent: number
  disks: DiskUsage[]
  temperatures: Temp[]
  load_avg_1m: number | null
  uptime_seconds: number | null
  error: string | null
}

export interface UpsStatus {
  connected: boolean
  on_battery: boolean
  battery_charge_percent: number | null
  status: string
  error: string | null
}

export interface UptimeResult {
  name: string
  url: string
  up: boolean
  status_code: number | null
  latency_ms: number | null
  cert_expiry_days: number | null
  error: string | null
}

export interface Alert {
  level: string
  kind: string
  target: string
  message: string
  value: number | null
  timestamp: string
}

export interface MetricsPayload {
  timestamp: string
  host_id: string
  host_name: string
  containers: ContainerMetrics[]
  ups: UpsStatus
  host: HostStats
  uptime: UptimeResult[]
  alerts: Alert[]
}

export interface Device {
  host_id: string
  host_name: string
  display_name: string
  api_url: string
  nut_host: string
  nut_ups_name: string
  last_seen?: string
}

export function deviceName(d: Device): string {
  return d.display_name?.trim() ? d.display_name : d.host_name
}

export interface AIProviderConfig {
  provider_type: string
  base_url: string
  model_name: string
  api_key: string
}

export interface HistoryPoint {
  ts: string
  host_cpu: number | null
  host_memory: number | null
  host_disk: number | null
}

export interface DeployPlan {
  image: string
  name: string
  ports: { host: number; container: number }[]
  volumes: { host: string; container: string }[]
  env: Record<string, string>
  restart: string
  notes: string
}

export interface DeployResult {
  id: string
  name: string
  status: string
  ports: { host: number; container: number }[]
}

export interface AuthSession {
  token: string
  email: string
  role: string
}

export const isAdmin = (s: AuthSession | null) => s?.role === 'admin'

export type Lang = 'en' | 'ar'
export type Theme = 'dark' | 'light'
