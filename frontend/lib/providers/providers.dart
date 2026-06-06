import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../services/backend_service.dart';

/// Overridden in main() with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ============================================================
// Authentication + roles
// ============================================================
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession;
});

/// Resolves (and lazily creates) the current user's role via ensure_profile().
/// First-ever user becomes 'admin', everyone else 'viewer'.
final roleProvider = FutureProvider<String>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return 'viewer';
  try {
    final r = await client.rpc(
      'ensure_profile',
      params: {'p_email': user.email ?? ''},
    );
    return (r as String?) ?? 'viewer';
  } catch (_) {
    return 'viewer';
  }
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(roleProvider).maybeWhen(
        data: (r) => r == 'admin',
        orElse: () => false,
      );
});

/// All user profiles (admin-only; RLS returns just your own row for viewers).
final profilesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('profiles')
      .select('id,email,role,created_at')
      .order('created_at');
  return (rows as List).cast<Map<String, dynamic>>();
});

// ============================================================
// Locale (persisted)
// ============================================================
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._prefs) : super(_initial(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'locale';

  static Locale _initial(SharedPreferences prefs) {
    return Locale(prefs.getString(_key) == 'ar' ? 'ar' : 'en');
  }

  void set(Locale locale) {
    state = locale;
    _prefs.setString(_key, locale.languageCode);
  }

  void toggle() =>
      set(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref.watch(sharedPrefsProvider));
});

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

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(sharedPrefsProvider));
});

// ============================================================
// Live metrics per host (Supabase Realtime Broadcast + fallback polling).
// Multiple agents broadcast to the same channel; we key payloads by host_id.
// ============================================================
class MetricsNotifier extends StateNotifier<Map<String, MetricsPayload>> {
  MetricsNotifier(this._backend, this._supabase) : super({}) {
    _init();
  }

  final BackendService _backend;
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  bool _realtimeConnected = false;

  void _store(MetricsPayload p) {
    state = {...state, p.hostId: p};
  }

  Future<void> _init() async {
    _subscribeBroadcast();
    await refresh();
  }

  void _subscribeBroadcast() {
    _channel = _supabase
        .channel(metricsBroadcastChannel)
        .onBroadcast(
          event: 'metrics',
          callback: (payload) {
            try {
              final data = payload['payload'] as Map<String, dynamic>? ?? payload;
              _store(MetricsPayload.fromJson(Map<String, dynamic>.from(data)));
              _realtimeConnected = true;
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> refresh() async {
    if (!_realtimeConnected || state.isEmpty) {
      await fetchFrom(backendUrl);
    }
  }

  /// Fetch a REST snapshot from a specific agent (realtime fallback / manual).
  Future<void> fetchFrom(String baseUrl) async {
    try {
      _store(await _backend.fetchMetrics(baseUrl: baseUrl));
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final metricsProvider =
    StateNotifierProvider<MetricsNotifier, Map<String, MetricsPayload>>((ref) {
  ref.watch(authStateProvider); // re-subscribe with the signed-in session
  return MetricsNotifier(
    ref.watch(backendServiceProvider),
    ref.watch(supabaseClientProvider),
  );
});

// ============================================================
// Devices (multi-server tabs)
// ============================================================
final devicesProvider = FutureProvider<List<Device>>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client
        .from('devices')
        .select('host_id,host_name,api_url,last_seen')
        .order('host_name');
    return (rows as List)
        .map((r) => Device.fromJson(r as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return <Device>[];
  }
});

final selectedDeviceProvider = StateProvider<String?>((ref) => null);

/// Registered devices merged with any host seen via realtime; falls back to a
/// single default device for a plain single-host setup.
final deviceListProvider = Provider<List<Device>>((ref) {
  final table = ref.watch(devicesProvider).asData?.value ?? const <Device>[];
  final metricsMap = ref.watch(metricsProvider);
  final byId = <String, Device>{};
  for (final d in table) {
    byId[d.hostId] = d;
  }
  metricsMap.forEach((hostId, p) {
    byId.putIfAbsent(
      hostId,
      () => Device(hostId: hostId, hostName: p.hostName, apiUrl: ''),
    );
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

/// The active device (selected tab), resolved against the device list.
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

/// Backend URL for the active device (falls back to the build default).
final selectedApiUrlProvider = Provider<String>((ref) {
  final d = ref.watch(activeDeviceProvider);
  return d.apiUrl.isNotEmpty ? d.apiUrl : backendUrl;
});

// ============================================================
// AI settings (encrypted at rest in Supabase)
// ============================================================
class SettingsNotifier extends StateNotifier<AsyncValue<AIProviderConfig?>> {
  SettingsNotifier(this._supabase) : super(const AsyncValue.loading()) {
    load();
  }

  final SupabaseClient _supabase;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final rows = await _supabase.rpc('get_settings_decrypted');
      if (rows is List && rows.isNotEmpty) {
        state = AsyncValue.data(
          AIProviderConfig.fromJson(rows.first as Map<String, dynamic>),
        );
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(AIProviderConfig config) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.rpc('upsert_settings', params: {
        'p_provider_type': config.providerType,
        'p_base_url': config.baseUrl,
        'p_model_name': config.modelName,
        'p_api_key': config.apiKey,
      });
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
  ref.watch(authStateProvider); // reload settings when the signed-in user changes
  return SettingsNotifier(ref.watch(supabaseClientProvider));
});

// ============================================================
// Historical metrics (time-bucketed via RPC) — range in hours.
// ============================================================
/// Selected history range, in hours: 24 (day) / 168 (week) / 720 (month).
final historyRangeProvider = StateProvider<int>((ref) => 24);

final historyProvider = FutureProvider<List<HistoryPoint>>((ref) async {
  ref.watch(authStateProvider);
  final hours = ref.watch(historyRangeProvider);
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.rpc(
    'get_metrics_history',
    params: {'p_hours': hours, 'p_buckets': 200},
  );
  return (rows as List)
      .map((r) => HistoryPoint.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ============================================================
// Rolling in-memory CPU/RAM history for live charts (last 30 samples)
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

  /// Drop history for containers that no longer exist (prevents unbounded growth).
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
        (ref) {
  return ChartHistoryNotifier();
});
