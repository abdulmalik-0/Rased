import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Overridden in main() with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final apiProvider = Provider<ApiService>((ref) {
  return ApiService(token: () => ref.read(authProvider)?.token);
});

// ============================================================
// Auth
// ============================================================
class AuthController extends StateNotifier<AuthSession?> {
  AuthController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  final ApiService _api = ApiService();
  static const _key = 'auth_token';

  static AuthSession? _load(SharedPreferences prefs) {
    final t = prefs.getString(_key);
    if (t == null || t.isEmpty) return null;
    final claims = decodeJwt(t);
    final exp = claims['exp'];
    if (exp is int && exp * 1000 < DateTime.now().millisecondsSinceEpoch) {
      return null;
    }
    return AuthSession(
      token: t,
      email: claims['email']?.toString() ?? '',
      role: claims['role']?.toString() ?? 'viewer',
    );
  }

  Future<void> login(String email, String password) async {
    final s = await _api.login(email, password);
    await _prefs.setString(_key, s.token);
    state = s;
  }

  /// Returns true if the account is created but pending admin approval.
  Future<bool> register(String email, String password) async {
    final r = await _api.register(email, password);
    if (r.pending || r.session == null) return true;
    await _prefs.setString(_key, r.session!.token);
    state = r.session;
    return false;
  }

  void logout() {
    _prefs.remove(_key);
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthSession?>((ref) {
  return AuthController(ref.watch(sharedPrefsProvider));
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authProvider)?.isAdmin ?? false;
});

// ============================================================
// Locale (persisted)
// ============================================================
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._prefs) : super(_initial(_prefs));
  final SharedPreferences _prefs;
  static const _key = 'locale';

  static Locale _initial(SharedPreferences prefs) =>
      Locale(prefs.getString(_key) == 'ar' ? 'ar' : 'en');

  void set(Locale locale) {
    state = locale;
    _prefs.setString(_key, locale.languageCode);
  }

  void toggle() =>
      set(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
    (ref) => LocaleNotifier(ref.watch(sharedPrefsProvider)));

// ============================================================
// Theme mode (persisted)
// ============================================================
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_initial(_prefs));
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  static ThemeMode _initial(SharedPreferences prefs) {
    switch (prefs.getString(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  void set(ThemeMode mode) {
    state = mode;
    _prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
    (ref) => ThemeModeNotifier(ref.watch(sharedPrefsProvider)));

// ============================================================
// Live metrics per host (WebSocket + REST fallback)
// ============================================================
class MetricsNotifier extends StateNotifier<Map<String, MetricsPayload>> {
  MetricsNotifier(this._api, this._token) : super({}) {
    _init();
  }

  final ApiService _api;
  final String? _token;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnect;
  bool _disposed = false;

  Future<void> _init() async {
    await refresh();
    _connect();
  }

  void _connect() {
    if (_disposed || _token == null || _token.isEmpty) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsMetricsUrl(_token)));
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final p = MetricsPayload.fromJson(
                jsonDecode(data as String) as Map<String, dynamic>);
            state = {...state, p.hostId: p};
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), () {
      refresh();
      _connect();
    });
  }

  Future<void> refresh() async {
    try {
      for (final p in await _api.getMetricsAll()) {
        state = {...state, p.hostId: p};
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _channel?.sink.close();
    _reconnect?.cancel();
    super.dispose();
  }
}

final metricsProvider =
    StateNotifierProvider<MetricsNotifier, Map<String, MetricsPayload>>((ref) {
  final session = ref.watch(authProvider);
  return MetricsNotifier(ref.watch(apiProvider), session?.token);
});

// ============================================================
// Devices (multi-server tabs)
// ============================================================
final devicesProvider = FutureProvider<List<Device>>((ref) async {
  ref.watch(authProvider);
  return ref.watch(apiProvider).getDevices();
});

final selectedDeviceProvider = StateProvider<String?>((ref) => null);

final deviceListProvider = Provider<List<Device>>((ref) {
  final table = ref.watch(devicesProvider).asData?.value ?? const <Device>[];
  final metricsMap = ref.watch(metricsProvider);
  final byId = <String, Device>{};
  for (final d in table) {
    byId[d.hostId] = d;
  }
  metricsMap.forEach((hostId, p) {
    byId.putIfAbsent(
        hostId, () => Device(hostId: hostId, hostName: p.hostName, apiUrl: ''));
  });
  if (byId.isEmpty) {
    byId['default'] =
        const Device(hostId: 'default', hostName: 'My Server', apiUrl: '');
  }
  final list = byId.values.toList()
    ..sort((a, b) =>
        a.hostName.toLowerCase().compareTo(b.hostName.toLowerCase()));
  return list;
});

final activeDeviceProvider = Provider<Device>((ref) {
  final devices = ref.watch(deviceListProvider);
  final sel = ref.watch(selectedDeviceProvider);
  for (final d in devices) {
    if (d.hostId == sel) return d;
  }
  return devices.isNotEmpty
      ? devices.first
      : const Device(hostId: 'default', hostName: 'My Server', apiUrl: '');
});

final selectedApiUrlProvider = Provider<String>((ref) {
  final d = ref.watch(activeDeviceProvider);
  return d.apiUrl.isNotEmpty ? d.apiUrl : backendUrl;
});

/// Ready-to-run agent linking info (admin only) — fetched on demand.
final agentSetupProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider);
  return ref.watch(apiProvider).getAgentSetup();
});

/// Admin-defined custom links per container, keyed by container name.
final linksProvider =
    FutureProvider.family<Map<String, Map<String, String>>, String>(
        (ref, hostId) async {
  ref.watch(authProvider);
  final rows = await ref.watch(apiProvider).getLinks(hostId);
  return {
    for (final r in rows)
      (r['name'] as String): {
        'url': r['url']?.toString() ?? '',
        'label': r['label']?.toString() ?? '',
      }
  };
});

// ============================================================
// AI settings (per user)
// ============================================================
class SettingsNotifier extends StateNotifier<AsyncValue<AIProviderConfig?>> {
  SettingsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  final ApiService _api;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _api.getSettings());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(AIProviderConfig config) async {
    state = const AsyncValue.loading();
    try {
      await _api.saveSettings(config);
      state = AsyncValue.data(config.copyWith(apiKey: ''));
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<AIProviderConfig?>>(
        (ref) {
  ref.watch(authProvider);
  return SettingsNotifier(ref.watch(apiProvider));
});

// ============================================================
// History (time-bucketed) + range
// ============================================================
final historyRangeProvider = StateProvider<int>((ref) => 24);

final historyProvider = FutureProvider<List<HistoryPoint>>((ref) async {
  ref.watch(authProvider);
  final hours = ref.watch(historyRangeProvider);
  return ref.watch(apiProvider).getHistory(hours);
});

// ============================================================
// Users (admin)
// ============================================================
final usersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider);
  return ref.watch(apiProvider).getUsers();
});

// ============================================================
// Rolling in-memory CPU/RAM history for live charts
// ============================================================
class ChartHistoryNotifier extends StateNotifier<Map<String, List<double>>> {
  ChartHistoryNotifier() : super({});
  static const maxPoints = 30;

  void addSample(String containerId, double cpu, double memory) {
    final key = '${containerId}_cpu';
    final memKey = '${containerId}_mem';
    final cpuList = <double>[...(state[key] ?? []), cpu];
    final memList = <double>[...(state[memKey] ?? []), memory];
    if (cpuList.length > maxPoints) cpuList.removeAt(0);
    if (memList.length > maxPoints) memList.removeAt(0);
    state = {...state, key: cpuList, memKey: memList};
  }

  void retain(Set<String> activeIds) {
    final next = <String, List<double>>{};
    var changed = false;
    state.forEach((key, value) {
      final id = key.replaceAll(RegExp(r'_(cpu|mem)$'), '');
      if (activeIds.contains(id)) {
        next[key] = value;
      } else {
        changed = true;
      }
    });
    if (changed) state = next;
  }
}

final chartHistoryProvider =
    StateNotifierProvider<ChartHistoryNotifier, Map<String, List<double>>>(
        (ref) => ChartHistoryNotifier());
