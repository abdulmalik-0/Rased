class ContainerMetrics {
  final String id;
  final String name;
  final String status;
  final String image;
  final double cpuPercent;
  final double memoryUsageMb;
  final double memoryLimitMb;
  final double memoryPercent;

  const ContainerMetrics({
    required this.id,
    required this.name,
    required this.status,
    required this.image,
    required this.cpuPercent,
    required this.memoryUsageMb,
    required this.memoryLimitMb,
    required this.memoryPercent,
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
    );
  }

  bool get isRunning => status == 'running';
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

class MetricsPayload {
  final String timestamp;
  final List<ContainerMetrics> containers;
  final UpsStatus ups;

  const MetricsPayload({
    required this.timestamp,
    required this.containers,
    required this.ups,
  });

  factory MetricsPayload.fromJson(Map<String, dynamic> json) {
    return MetricsPayload(
      timestamp: json['timestamp'] as String? ?? '',
      containers: (json['containers'] as List<dynamic>? ?? [])
          .map((c) => ContainerMetrics.fromJson(c as Map<String, dynamic>))
          .toList(),
      ups: UpsStatus.fromJson(json['ups'] as Map<String, dynamic>? ?? {}),
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
