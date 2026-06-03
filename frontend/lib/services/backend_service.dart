import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';

class BackendService {
  final http.Client _client;

  BackendService({http.Client? client}) : _client = client ?? http.Client();

  Future<MetricsPayload> fetchMetrics() async {
    final response = await _client.get(Uri.parse('$backendUrl/metrics'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch metrics: ${response.statusCode}');
    }
    return MetricsPayload.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AnalyzeResult> analyzeLogs({
    required String containerId,
    required AIProviderConfig aiConfig,
  }) async {
    final response = await _client.post(
      Uri.parse('$backendUrl/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'container_id': containerId,
        'ai_config': aiConfig.toJson(),
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : response.body;
      throw Exception(detail ?? 'Analysis failed');
    }

    return AnalyzeResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$backendUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
