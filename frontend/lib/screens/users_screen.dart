import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    String id,
    String role,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .update({'role': role}).eq('id', id);
      ref.invalidate(profilesProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isAdmin = ref.watch(isAdminProvider);
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('usersTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(profilesProvider),
          ),
        ],
      ),
      body: !isAdmin
          ? Center(
              child: Text(
                context.tr('adminsOnly'),
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          : profiles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${context.tr('usersError')}: $e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (rows) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = rows[i];
                  final id = p['id'] as String;
                  final email = (p['email'] as String?) ?? id;
                  final role = (p['role'] as String?) ?? 'viewer';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            role == 'admin'
                                ? Icons.shield
                                : Icons.visibility,
                            color: role == 'admin'
                                ? colors.primary
                                : colors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(color: colors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownButton<String>(
                            value: role == 'admin' ? 'admin' : 'viewer',
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text(context.tr('roleAdmin')),
                              ),
                              DropdownMenuItem(
                                value: 'viewer',
                                child: Text(context.tr('roleViewer')),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null && v != role) {
                                _setRole(context, ref, id, v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
