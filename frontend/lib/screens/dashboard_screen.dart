import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/add_device_dialog.dart';
import '../widgets/alerts_banner.dart';
import '../widgets/analyze_logs_dialog.dart';
import '../widgets/container_card.dart';
import '../widgets/deploy_suggest_dialog.dart';
import '../widgets/device_config_dialog.dart';
import '../widgets/host_stats_widget.dart';
import '../widgets/link_edit_dialog.dart';
import '../widgets/logs_viewer_dialog.dart';
import '../widgets/ups_status_widget.dart';
import '../widgets/uptime_widget.dart';
import 'chat_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  MetricsPayload? _lastMetrics;

  void _accumulateHistory(
      Map<String, MetricsPayload> metricsMap, String hostId) {
    final selected = metricsMap[hostId];
    if (selected == null || selected == _lastMetrics) return;
    _lastMetrics = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(chartHistoryProvider.notifier);
      for (final c in selected.containers) {
        if (c.isRunning) {
          notifier.addSample('${hostId}_${c.id}', c.cpuPercent, c.memoryPercent);
        }
      }
      final active = <String>{};
      metricsMap.forEach((h, p) {
        for (final c in p.containers) {
          active.add('${h}_${c.id}');
        }
      });
      notifier.retain(active);
    });
  }

  Future<void> _handleAction(ContainerMetrics c, String action) async {
    final apiUrl = ref.read(selectedApiUrlProvider);
    if (action == 'logs') {
      showDialog(
        context: context,
        builder: (_) => LogsViewerDialog(container: c, apiUrl: apiUrl),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('confirmActionTitle')),
        content: Text(
          ctx
              .tr('confirmActionBody')
              .replaceAll('{action}', ctx.tr(action))
              .replaceAll('{name}', c.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).containerAction(
            containerId: c.id,
            action: action,
            baseUrl: apiUrl,
          );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('actionSuccess'))),
        );
      }
      await ref.read(metricsProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('${context.tr('actionFailed')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metricsMap = ref.watch(metricsProvider);
    final chartHistory = ref.watch(chartHistoryProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final devices = ref.watch(deviceListProvider);
    final activeDevice = ref.watch(activeDeviceProvider);
    final apiUrl = ref.watch(selectedApiUrlProvider);
    final hostId = activeDevice.hostId;
    final metrics = metricsMap[hostId];
    final online = metrics != null;

    _accumulateHistory(metricsMap, hostId);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.dns, color: colors.primary, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(context.tr('appTitle'),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 12),
            _statusBadge(
              online ? context.tr('agentOnline') : context.tr('agentOffline'),
              online ? colors.accent : colors.danger,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: context.tr('askAi'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(hostId: hostId, apiUrl: apiUrl),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: context.tr('history'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: context.tr('language'),
            onPressed: () => ref.read(localeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: context.tr('theme'),
            onPressed: () {
              final mode = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).set(
                    mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('refresh'),
            onPressed: () =>
                ref.read(metricsProvider.notifier).refresh(),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: context.tr('deviceSettings'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => DeviceConfigDialog(device: activeDevice),
              ),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_to_queue),
              tooltip: context.tr('addDevice'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AddDeviceDialog(),
              ),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.rocket_launch_outlined),
              tooltip: context.tr('deployTitle'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const DeploySuggestDialog(),
              ),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: context.tr('users'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UsersScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: context.tr('help'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: context.tr('settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: context.tr('signOut'),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (devices.length > 1) _deviceTabs(colors, devices, metricsMap),
          Expanded(child: _deviceBody(colors, metrics, chartHistory, hostId)),
        ],
      ),
    );
  }

  Widget _deviceTabs(
    RasedColors colors,
    List<Device> devices,
    Map<String, MetricsPayload> metricsMap,
  ) {
    final selected = ref.watch(activeDeviceProvider).hostId;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: devices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = devices[i];
          final live = metricsMap.containsKey(d.hostId);
          return ChoiceChip(
            selected: d.hostId == selected,
            avatar: Icon(Icons.circle,
                size: 10, color: live ? colors.accent : colors.textSecondary),
            label: Text(d.name),
            onSelected: (_) =>
                ref.read(selectedDeviceProvider.notifier).state = d.hostId,
          );
        },
      ),
    );
  }

  Widget _deviceBody(
    RasedColors colors,
    MetricsPayload? metrics,
    Map<String, List<double>> chartHistory,
    String hostId,
  ) {
    if (metrics == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: 16),
            Text(context.tr('waitingMetrics'),
                style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }

    final links = ref.watch(linksProvider(hostId)).asData?.value ??
        const <String, Map<String, String>>{};
    final deviceName = ref.watch(activeDeviceProvider).name;

    return RefreshIndicator(
      onRefresh: () => ref.read(metricsProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1200
              ? 3
              : constraints.maxWidth > 800
                  ? 2
                  : 1;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    HostStatsWidget(
                        host: metrics.host, hostName: deviceName),
                    if (metrics.alerts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      AlertsBanner(alerts: metrics.alerts),
                    ],
                    const SizedBox(height: 16),
                    UpsStatusWidget(ups: metrics.ups),
                    if (metrics.uptime.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      UptimeWidget(results: metrics.uptime),
                    ],
                  ]),
                ),
              ),
              if (metrics.containers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(context.tr('noContainers'),
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final container in metrics.containers)
                          SizedBox(
                            width: (constraints.maxWidth -
                                    32 -
                                    16 * (crossAxisCount - 1)) /
                                crossAxisCount,
                            child: ContainerCard(
                              container: container,
                              cpuHistory:
                                  chartHistory['${hostId}_${container.id}_cpu'] ??
                                      const [],
                              memoryHistory:
                                  chartHistory['${hostId}_${container.id}_mem'] ??
                                      const [],
                              onAnalyze: () => showDialog(
                                context: context,
                                builder: (_) => AnalyzeLogsDialog(
                                  container: container,
                                  apiUrl: ref.read(selectedApiUrlProvider),
                                  hostId: hostId,
                                ),
                              ),
                              onAction: (action) =>
                                  _handleAction(container, action),
                              isAdmin: ref.read(isAdminProvider),
                              apiUrl: ref.read(selectedApiUrlProvider),
                              customLink: links[container.name],
                              onEditLink: () => showDialog(
                                context: context,
                                builder: (_) => LinkEditDialog(
                                  hostId: hostId,
                                  containerName: container.name,
                                  url: links[container.name]?['url'] ?? '',
                                  label: links[container.name]?['label'] ?? '',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
