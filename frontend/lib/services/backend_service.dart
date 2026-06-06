import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/models.dart';

class BackendService {
  final http.Client _client;

  BackendService({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _aiTimeout = Duration(seconds: 130);

  String _base(String? baseUrl) =>
      (baseUrl == null || baseUrl.isEmpty) ? backendUrl : baseUrl;

  /// Attaches the signed-in user's access token so the backend can authorize
  /// (e.g. admin-only container actions).
  Map<String, String> _headers([Map<String, String>? base]) {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      if (base != null) ...base,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<MetricsPayload> fetchMetrics({String? baseUrl}) async {
    final response = await _client
        .get(Uri.parse('${_base(baseUrl)}/metrics'), headers: _headers())
        .timeout(_timeout);
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
    int tail = 100,
    String lang = 'en',
    String? baseUrl,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${_base(baseUrl)}/analyze'),
          headers: _headers({'Content-Type': 'application/json'}),
          body: jsonEncode({
            'container_id': containerId,
            'ai_config': aiConfig.toJson(),
            'tail': tail,
            'lang': lang,
          }),
        )
        .timeout(_aiTimeout);

    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response));
    }
    return AnalyzeResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AskResult> ask({
    required String question,
    required AIProviderConfig aiConfig,
    String? containerId,
    bool includeLogs = true,
    List<Map<String, String>> history = const [],
    String lang = 'en',
    String? baseUrl,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${_base(baseUrl)}/ask'),
          headers: _headers({'Content-Type': 'application/json'}),
          body: jsonEncode({
            'question': question,
            'ai_config': aiConfig.toJson(),
            'container_id': containerId,
            'include_logs': includeLogs,
            'history': history,
            'lang': lang,
          }),
        )
        .timeout(_aiTimeout);

    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response));
    }
    return AskResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> containerAction({
    required String containerId,
    required String action,
    String? baseUrl,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${_base(baseUrl)}/actions/$containerId'),
          headers: _headers({'Content-Type': 'application/json'}),
          body: jsonEncode({'action': action}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['status'] as String? ?? 'unknown';
  }

  Future<List<String>> fetchLogs({
    required String containerId,
    int tail = 200,
    String? baseUrl,
  }) async {
    final response = await _client
        .get(Uri.parse('${_base(baseUrl)}/logs/$containerId?tail=$tail'),
            headers: _headers())
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(_errorDetail(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final lines = body['sanitized_lines'] as List<dynamic>? ?? [];
    return lines.map((e) => e.toString()).toList();
  }

  String _errorDetail(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}
