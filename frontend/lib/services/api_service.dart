import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';

/// Decode a JWT payload (no verification — for reading email/role/exp client-side).
Map<String, dynamic> decodeJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (p.length % 4 != 0) {
      p += '=';
    }
    return jsonDecode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

class ApiService {
  final http.Client _client;
  final String? Function()? _token;

  ApiService({http.Client? client, String? Function()? token})
      : _client = client ?? http.Client(),
        _token = token;

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _aiTimeout = Duration(seconds: 130);

  String _base(String? baseUrl) =>
      (baseUrl == null || baseUrl.isEmpty) ? backendUrl : baseUrl;

  Map<String, String> _headers({bool json = false}) {
    final t = _token?.call();
    return {
      if (json) 'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  // ---------- auth ----------
  /// Returns (pending:true) when the account awaits admin approval.
  Future<({bool pending, AuthSession? session})> register(
      String email, String password) async {
    final resp = await _client
        .post(Uri.parse('$backendUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    final b = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = b['token'] as String?;
    if ((b['pending'] as bool? ?? false) || token == null) {
      return (pending: true, session: null);
    }
    return (
      pending: false,
      session: AuthSession(
        token: token,
        email: b['email'] as String? ?? email,
        role: b['role'] as String? ?? 'viewer',
      )
    );
  }

  Future<AuthSession> login(String email, String password) =>
      _auth('/auth/login', email, password);

  Future<AuthSession> _auth(String path, String email, String password) async {
    final resp = await _client
        .post(Uri.parse('$backendUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    final b = jsonDecode(resp.body) as Map<String, dynamic>;
    return AuthSession(
      token: b['token'] as String,
      email: b['email'] as String? ?? email,
      role: b['role'] as String? ?? 'viewer',
    );
  }

  // ---------- settings ----------
  Future<AIProviderConfig?> getSettings() async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/settings'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    if (resp.body.isEmpty || resp.body == 'null') return null;
    return AIProviderConfig.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AIProviderConfig config) async {
    final resp = await _client
        .post(Uri.parse('$backendUrl/settings'),
            headers: _headers(json: true), body: jsonEncode(config.toJson()))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
  }

  // ---------- users (admin) ----------
  Future<List<Map<String, dynamic>>> getUsers() async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/users'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> setUserRole(String uid, String role) async {
    final resp = await _client
        .patch(Uri.parse('$backendUrl/users/$uid'),
            headers: _headers(json: true), body: jsonEncode({'role': role}))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
  }

  Future<void> setUserApproved(String uid, bool approved) async {
    final resp = await _client
        .patch(Uri.parse('$backendUrl/users/$uid'),
            headers: _headers(json: true),
            body: jsonEncode({'approved': approved}))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
  }

  // ---------- devices ----------
  Future<List<Device>> getDevices() async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/devices'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as List)
        .map((r) => Device.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateDevice(
    String hostId, {
    String? displayName,
    String? nutHost,
    String? nutUpsName,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (nutHost != null) body['nut_host'] = nutHost;
    if (nutUpsName != null) body['nut_ups_name'] = nutUpsName;
    final resp = await _client
        .patch(Uri.parse('$backendUrl/devices/$hostId'),
            headers: _headers(json: true), body: jsonEncode(body))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
  }

  // ---------- container links ----------
  Future<List<Map<String, dynamic>>> getLinks(String hostId) async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/links?host_id=$hostId'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> setLink(
      String hostId, String name, String url, String label) async {
    final resp = await _client
        .put(Uri.parse('$backendUrl/links'),
            headers: _headers(json: true),
            body: jsonEncode(
                {'host_id': hostId, 'name': name, 'url': url, 'label': label}))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
  }

  Future<void> deleteLink(String hostId, String name) async {
    final resp = await _client
        .delete(
            Uri.parse(
                '$backendUrl/links?host_id=$hostId&name=${Uri.encodeComponent(name)}'),
            headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
  }

  // ---------- onboarding (admin) ----------
  /// Ready-to-run agent linking info with the real shared secrets prefilled.
  Future<Map<String, dynamic>> getAgentSetup() async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/setup/agent'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ---------- history ----------
  Future<List<HistoryPoint>> getHistory(int hours) async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/history?hours=$hours'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as List)
        .map((r) => HistoryPoint.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ---------- chats ----------
  Future<List<Map<String, dynamic>>> getChats(String hostId) async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/chats?host_id=$hostId'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }

  Future<String> upsertChat({
    String? id,
    required String hostId,
    required String title,
    required List<Map<String, String>> messages,
  }) async {
    final resp = await _client
        .post(Uri.parse('$backendUrl/chats'),
            headers: _headers(json: true),
            body: jsonEncode({
              'id': id,
              'host_id': hostId,
              'title': title,
              'messages': messages,
            }))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<void> deleteChat(String id) async {
    final resp = await _client
        .delete(Uri.parse('$backendUrl/chats/$id'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
  }

  // ---------- metrics (fallback; primary is the WebSocket) ----------
  Future<List<MetricsPayload>> getMetricsAll() async {
    final resp = await _client
        .get(Uri.parse('$backendUrl/metrics/all'), headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as List)
        .map((r) => MetricsPayload.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ---------- per-device AI / actions ----------
  Future<AnalyzeResult> analyzeLogs({
    required String containerId,
    required AIProviderConfig aiConfig,
    int tail = 100,
    String lang = 'en',
    String? baseUrl,
  }) async {
    final resp = await _client
        .post(Uri.parse('${_base(baseUrl)}/analyze'),
            headers: _headers(json: true),
            body: jsonEncode({
              'container_id': containerId,
              'ai_config': aiConfig.toJson(),
              'tail': tail,
              'lang': lang,
            }))
        .timeout(_aiTimeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return AnalyzeResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
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
    final resp = await _client
        .post(Uri.parse('${_base(baseUrl)}/ask'),
            headers: _headers(json: true),
            body: jsonEncode({
              'question': question,
              'ai_config': aiConfig.toJson(),
              'container_id': containerId,
              'include_logs': includeLogs,
              'history': history,
              'lang': lang,
            }))
        .timeout(_aiTimeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return AskResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<String>> fetchLogs({
    required String containerId,
    int tail = 200,
    String? baseUrl,
  }) async {
    final resp = await _client
        .get(Uri.parse('${_base(baseUrl)}/logs/$containerId?tail=$tail'),
            headers: _headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    final b = jsonDecode(resp.body) as Map<String, dynamic>;
    return (b['sanitized_lines'] as List? ?? []).map((e) => e.toString()).toList();
  }

  Future<String> containerAction({
    required String containerId,
    required String action,
    String? baseUrl,
  }) async {
    final resp = await _client
        .post(Uri.parse('${_base(baseUrl)}/actions/$containerId'),
            headers: _headers(json: true), body: jsonEncode({'action': action}))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw Exception(_err(resp));
    return (jsonDecode(resp.body) as Map<String, dynamic>)['status'] as String? ??
        'unknown';
  }

  String _err(http.Response resp) {
    try {
      final b = jsonDecode(resp.body);
      if (b is Map && b['detail'] != null) return b['detail'].toString();
    } catch (_) {}
    return 'Request failed (${resp.statusCode})';
  }
}
