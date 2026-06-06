/// Rased API (FastAPI) — host port 8002 (override via --dart-define=BACKEND_URL=...)
/// This is the CENTRAL node (auth + data + realtime WebSocket).
const String backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:8002',
);

/// WebSocket URL for live metrics (derived from backendUrl).
String wsMetricsUrl(String token) {
  final base = backendUrl.replaceFirst(RegExp(r'^http'), 'ws');
  return '$base/ws/metrics?token=$token';
}
