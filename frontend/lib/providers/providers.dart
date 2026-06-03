import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import 'backend_service.dart';

final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Live metrics from Supabase Realtime Broadcast + fallback polling
class MetricsNotifier extends StateNotifier<MetricsPayload?> {
  MetricsNotifier(this._backend, this._supabase) : super(null) {
    _init();
  }

  final BackendService _backend;
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  bool _realtimeConnected = false;

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
              state = MetricsPayload.fromJson(
                Map<String, dynamic>.from(data),
              );
              _realtimeConnected = true;
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> refresh() async {
    if (!_realtimeConnected || state == null) {
      try {
        state = await _backend.fetchMetrics();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final metricsProvider =
    StateNotifierProvider<MetricsNotifier, MetricsPayload?>((ref) {
  return MetricsNotifier(
    ref.watch(backendServiceProvider),
    ref.watch(supabaseClientProvider),
  );
});

/// AI settings stored in Supabase (encrypted at rest)
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
  return SettingsNotifier(ref.watch(supabaseClientProvider));
});

final backendHealthProvider = FutureProvider<bool>((ref) async {
  return ref.watch(backendServiceProvider).healthCheck();
});

/// Historical CPU/RAM data points for charts (last 30 samples)
class ChartHistoryNotifier extends StateNotifier<Map<String, List<double>>> {
  ChartHistoryNotifier() : super({});

  static const maxPoints = 30;

  void addSample(String containerId, double cpu, double memory) {
    final key = '${containerId}_cpu';
    final memKey = '${containerId}_mem';
    final cpuList = [...(state[key] ?? []), cpu];
    final memList = [...(state[memKey] ?? []), memory];
    if (cpuList.length > maxPoints) cpuList.removeAt(0);
    if (memList.length > maxPoints) memList.removeAt(0);
    state = {...state, key: cpuList, memKey: memList};
  }
}

final chartHistoryProvider =
    StateNotifierProvider<ChartHistoryNotifier, Map<String, List<double>>>(
        (ref) {
  return ChartHistoryNotifier();
});
