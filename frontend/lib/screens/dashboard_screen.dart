import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/analyze_logs_dialog.dart';
import '../widgets/container_card.dart';
import '../widgets/ups_status_widget.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  MetricsPayload? _lastMetrics;

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(metricsProvider);
    final chartHistory = ref.watch(chartHistoryProvider);
    final backendHealthy = ref.watch(backendHealthProvider);

    if (metrics != null && metrics != _lastMetrics) {
      _lastMetrics = metrics;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in metrics.containers) {
          if (c.isRunning) {
            ref.read(chartHistoryProvider.notifier).addSample(
                  c.id,
                  c.cpuPercent,
                  c.memoryPercent,
                );
          }
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.dns, color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Rased Dashboard'),
            const SizedBox(width: 12),
            backendHealthy.when(
              data: (ok) => _statusBadge(
                ok ? 'Agent Online' : 'Agent Offline',
                ok ? AppTheme.accent : AppTheme.danger,
              ),
              loading: () => _statusBadge('Checking…', AppTheme.textSecondary),
              error: (_, __) => _statusBadge('Agent Offline', AppTheme.danger),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh metrics',
            onPressed: () => ref.read(metricsProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'AI Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: metrics == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for metrics…',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
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
                        sliver: SliverToBoxAdapter(
                          child: UpsStatusWidget(ups: metrics.ups),
                        ),
                      ),
                      if (metrics.containers.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No Docker containers found',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: crossAxisCount == 1 ? 1.4 : 0.85,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final container = metrics.containers[index];
                                return ContainerCard(
                                  container: container,
                                  cpuHistory:
                                      chartHistory['${container.id}_cpu'] ?? [],
                                  memoryHistory:
                                      chartHistory['${container.id}_mem'] ?? [],
                                  onAnalyze: () => showDialog(
                                    context: context,
                                    builder: (_) => AnalyzeLogsDialog(
                                      container: container,
                                    ),
                                  ),
                                );
                              },
                              childCount: metrics.containers.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
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
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
