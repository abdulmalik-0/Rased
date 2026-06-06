class ContainerMetrics {
  final String id;
  final String name;
  final String status;
  final String image;
  final double cpuPercent;
  final double memoryUsageMb;
  final double memoryLimitMb;
  final double memoryPercent;
  final int restartCount;
  final List<String> ports;

  const ContainerMetrics({
    required this.id,
    required this.name,
    required this.status,
    required this.image,
    required this.cpuPercent,
    required this.memoryUsageMb,
    required this.memoryLimitMb,
    required this.memoryPercent,
    this.restartCount = 0,
    this.ports = const [],
  });

  factory ContainerMetrics.fromJson(Map<String, dynamic> json) {
    return ContainerMetrics(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      image: json['image'] as String? ?? '',
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0,
      memoryUsageMb: (json['memory_usage_mb'] as num?)?.toDouble() ?? 0,
      memoryLimitMb: (json['memory_limit_mb'] as num?)?.toDouble() ?? 0,
      memoryPercent: (json['memory_percent'] as num?)?.toDouble() ?? 0,
      restartCount: (json['restart_count'] as num?)?.toInt() ?? 0,
      ports: (json['ports'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  bool get isRunning => status == 'running';
}

class DiskUsage {
  final String mount;
  final double usedGb;
  final double totalGb;
  final double percent;

  const DiskUsage({
    required this.mount,
    required this.usedGb,
    required this.totalGb,
    required this.percent,
  });

  factory DiskUsage.fromJson(Map<String, dynamic> json) {
    return DiskUsage(
      mount: json['mount'] as String? ?? '',
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0,
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Temp {
  final String label;
  final double current;
  final double? high;

  const Temp({required this.label, required this.current, this.high});

  factory Temp.fromJson(Map<String, dynamic> json) {
    return Temp(
      label: json['label'] as String? ?? '',
      current: (json['current'] as num?)?.toDouble() ?? 0,
      high: (json['high'] as num?)?.toDouble(),
    );
  }
}

class HostStats {
  final bool available;
  final double cpuPercent;
  final int cpuCores;
  final double memoryUsedMb;
  final double memoryTotalMb;
  final double memoryPercent;
  final List<DiskUsage> disks;
  final List<Temp> temperatures;
  final double? loadAvg1m;
  final double? uptimeSeconds;
  final String? error;

  const HostStats({
    this.available = false,
    this.cpuPercent = 0,
    this.cpuCores = 0,
    this.memoryUsedMb = 0,
    this.memoryTotalMb = 0,
    this.memoryPercent = 0,
    this.disks = const [],
    this.temperatures = const [],
    this.loadAvg1m,
    this.uptimeSeconds,
    this.error,
  });

  factory HostStats.fromJson(Map<String, dynamic> json) {
    return HostStats(
      available: json['available'] as bool? ?? false,
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0,
      cpuCores: (json['cpu_cores'] as num?)?.toInt() ?? 0,
      memoryUsedMb: (json['memory_used_mb'] as num?)?.toDouble() ?? 0,
      memoryTotalMb: (json['memory_total_mb'] as num?)?.toDouble() ?? 0,
      memoryPercent: (json['memory_percent'] as num?)?.toDouble() ?? 0,
      disks: (json['disks'] as List<dynamic>? ?? [])
          .map((d) => DiskUsage.fromJson(d as Map<String, dynamic>))
          .toList(),
      temperatures: (json['temperatures'] as List<dynamic>? ?? [])
          .map((t) => Temp.fromJson(t as Map<String, dynamic>))
          .toList(),
      loadAvg1m: (json['load_avg_1m'] as num?)?.toDouble(),
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );
  }
}

class UpsStatus {
  final bool connected;
  final bool onBattery;
  final double? batteryChargePercent;
  final String status;
  final String? error;

  const UpsStatus({
    required this.connected,
    required this.onBattery,
    this.batteryChargePercent,
    required this.status,
    this.error,
  });

  factory UpsStatus.fromJson(Map<String, dynamic> json) {
    return UpsStatus(
      connected: json['connected'] as bool? ?? false,
      onBattery: json['on_battery'] as bool? ?? false,
      batteryChargePercent: (json['battery_charge_percent'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'unknown',
      error: json['error'] as String?,
    );
  }
}

class UptimeResult {
  final String name;
  final String url;
  final bool up;
  final int? statusCode;
  final double? latencyMs;
  final int? certExpiryDays;
  final String? error;

  const UptimeResult({
    required this.name,
    required this.url,
    required this.up,
    this.statusCode,
    this.latencyMs,
    this.certExpiryDays,
    this.error,
  });

  factory UptimeResult.fromJson(Map<String, dynamic> json) {
    return UptimeResult(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      up: json['up'] as bool? ?? false,
      statusCode: (json['status_code'] as num?)?.toInt(),
      latencyMs: (json['latency_ms'] as num?)?.toDouble(),
      certExpiryDays: (json['cert_expiry_days'] as num?)?.toInt(),
      error: json['error'] as String?,
    );
  }
}

class Alert {
  final String level;
  final String kind;
  final String target;
  final String message;
  final double? value;
  final String timestamp;

  const Alert({
    required this.level,
    required this.kind,
    required this.target,
    required this.message,
    this.value,
    required this.timestamp,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      level: json['level'] as String? ?? 'warning',
      kind: json['kind'] as String? ?? '',
      target: json['target'] as String? ?? '',
      message: json['message'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble(),
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class MetricsPayload {
  final String timestamp;
  final String hostId;
  final String hostName;
  final List<ContainerMetrics> containers;
  final UpsStatus ups;
  final HostStats host;
  final List<UptimeResult> uptime;
  final List<Alert> alerts;

  const MetricsPayload({
    required this.timestamp,
    required this.hostId,
    required this.hostName,
    required this.containers,
    required this.ups,
    required this.host,
    required this.uptime,
    required this.alerts,
  });

  factory MetricsPayload.fromJson(Map<String, dynamic> json) {
    return MetricsPayload(
      timestamp: json['timestamp'] as String? ?? '',
      hostId: json['host_id'] as String? ?? 'default',
      hostName: json['host_name'] as String? ?? 'My Server',
      containers: (json['containers'] as List<dynamic>? ?? [])
          .map((c) => ContainerMetrics.fromJson(c as Map<String, dynamic>))
          .toList(),
      ups: UpsStatus.fromJson(json['ups'] as Map<String, dynamic>? ?? {}),
      host: HostStats.fromJson(json['host'] as Map<String, dynamic>? ?? {}),
      uptime: (json['uptime'] as List<dynamic>? ?? [])
          .map((u) => UptimeResult.fromJson(u as Map<String, dynamic>))
          .toList(),
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map((a) => Alert.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AIProviderConfig {
  final String providerType;
  final String baseUrl;
  final String modelName;
  final String apiKey;

  const AIProviderConfig({
    required this.providerType,
    required this.baseUrl,
    required this.modelName,
    this.apiKey = '',
  });

  Map<String, dynamic> toJson() => {
        'provider_type': providerType,
        'base_url': baseUrl,
        'model_name': modelName,
        'api_key': apiKey,
      };

  factory AIProviderConfig.fromJson(Map<String, dynamic> json) {
    return AIProviderConfig(
      providerType: json['provider_type'] as String? ?? 'custom',
      baseUrl: json['base_url'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      apiKey: json['api_key'] as String? ?? '',
    );
  }

  AIProviderConfig copyWith({
    String? providerType,
    String? baseUrl,
    String? modelName,
    String? apiKey,
  }) {
    return AIProviderConfig(
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}

class AnalyzeResult {
  final String analysis;
  final String sanitizedLogPreview;
  final String modelUsed;

  const AnalyzeResult({
    required this.analysis,
    required this.sanitizedLogPreview,
    required this.modelUsed,
  });

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) {
    return AnalyzeResult(
      analysis: json['analysis'] as String? ?? '',
      sanitizedLogPreview: json['sanitized_log_preview'] as String? ?? '',
      modelUsed: json['model_used'] as String? ?? '',
    );
  }
}

class AskResult {
  final String answer;
  final String modelUsed;

  const AskResult({required this.answer, required this.modelUsed});

  factory AskResult.fromJson(Map<String, dynamic> json) {
    return AskResult(
      answer: json['answer'] as String? ?? '',
      modelUsed: json['model_used'] as String? ?? '',
    );
  }
}

/// Authenticated session (JWT issued by the backend).
class AuthSession {
  final String token;
  final String email;
  final String role;

  const AuthSession({
    required this.token,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
}

/// A monitored machine/agent (from the backend `devices` table).
class Device {
  final String hostId;
  final String hostName;
  final String displayName;
  final String apiUrl;
  final String nutHost;
  final String nutUpsName;
  final DateTime? lastSeen;

  const Device({
    required this.hostId,
    required this.hostName,
    this.displayName = '',
    required this.apiUrl,
    this.nutHost = '',
    this.nutUpsName = '',
    this.lastSeen,
  });

  /// Admin display override falls back to the agent-reported name.
  String get name => displayName.isNotEmpty ? displayName : hostName;

  factory Device.fromJson(Map<String, dynamic> json) {
    final id = json['host_id'] as String? ?? '';
    final hn = json['host_name'] as String? ?? '';
    return Device(
      hostId: id,
      hostName: hn.isNotEmpty ? hn : id,
      displayName: json['display_name'] as String? ?? '',
      apiUrl: json['api_url'] as String? ?? '',
      nutHost: json['nut_host'] as String? ?? '',
      nutUpsName: json['nut_ups_name'] as String? ?? '',
      lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? '')?.toLocal(),
    );
  }
}

/// A single point of historical metrics (from the backend `metrics_history` table).
class HistoryPoint {
  final DateTime ts;
  final double? hostCpu;
  final double? hostMem;
  final double? hostDiskMax;
  final int containersRunning;

  const HistoryPoint({
    required this.ts,
    this.hostCpu,
    this.hostMem,
    this.hostDiskMax,
    this.containersRunning = 0,
  });

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      ts: DateTime.tryParse(json['ts'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      hostCpu: (json['host_cpu'] as num?)?.toDouble(),
      hostMem: (json['host_mem'] as num?)?.toDouble(),
      hostDiskMax: (json['host_disk_max'] as num?)?.toDouble(),
      containersRunning: (json['containers_running'] as num?)?.toInt() ?? 0,
    );
  }
}
