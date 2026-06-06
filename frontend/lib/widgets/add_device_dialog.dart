import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// One-command "add a Linux machine" dialog. Builds a single curl bootstrap that
/// downloads Rased from GitHub and starts the agent. Secrets are masked on
/// screen; Copy copies the real command.
class AddDeviceDialog extends ConsumerStatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  ConsumerState<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends ConsumerState<AddDeviceDialog> {
  static const _repoKey = 'agent_repo_url';
  static const _defaultRepo = 'https://github.com/abdulmalik-0/Rased.git';

  final _hostId = TextEditingController(text: 'lxc-2');
  final _name = TextEditingController(text: 'LXC 2');
  late final TextEditingController _repoUrl;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(sharedPrefsProvider).getString(_repoKey);
    _repoUrl = TextEditingController(text: saved ?? _defaultRepo);
  }

  @override
  void dispose() {
    _hostId.dispose();
    _name.dispose();
    _repoUrl.dispose();
    super.dispose();
  }

  String _mask(String s) =>
      s.length <= 6 ? '••••••' : '${s.substring(0, 4)}${'•' * 16}';

  /// https://github.com/U/R(.git) -> raw bootstrap script URL.
  String _rawBootstrap(String repo) {
    var r = repo.trim();
    if (r.endsWith('.git')) r = r.substring(0, r.length - 4);
    if (r.endsWith('/')) r = r.substring(0, r.length - 1);
    r = r.replaceFirst('github.com', 'raw.githubusercontent.com');
    return '$r/main/scripts/bootstrap-agent.sh';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final setup = ref.watch(agentSetupProvider);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.add_to_queue, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('addDeviceTitle'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('addDeviceIntro'),
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: setup.when(
                  loading: () => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator())),
                  error: (e, _) => Text('${context.tr('error')}: $e',
                      style: TextStyle(color: colors.danger)),
                  data: (s) => _content(colors, s),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(RasedColors colors, Map<String, dynamic> s) {
    final central = s['central_ingest_url']?.toString() ?? '';
    final token = s['agent_token']?.toString() ?? '';
    final jwt = s['jwt_secret']?.toString() ?? '';

    final id = _hostId.text.trim().isEmpty ? 'lxc-2' : _hostId.text.trim();
    final name = _name.text.trim().isEmpty ? 'LXC' : _name.text.trim();
    final repo = _repoUrl.text.trim().isEmpty ? _defaultRepo : _repoUrl.text.trim();
    final raw = _rawBootstrap(repo);

    String cmd(String t, String j) => 'curl -fsSL $raw | bash -s -- '
        '--central $central --token $t --jwt $j --id $id --name "$name"';
    final realCmd = cmd(token, jwt);
    final shownCmd =
        _reveal ? realCmd : cmd(_mask(token), _mask(jwt));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _field(colors, _hostId, context.tr('agentHostId'))),
            const SizedBox(width: 10),
            Expanded(child: _field(colors, _name, context.tr('displayName'))),
          ]),
          const SizedBox(height: 10),
          _field(colors, _repoUrl, context.tr('agentRepoUrl'),
              hint: _defaultRepo, onChanged: (v) {
            ref.read(sharedPrefsProvider).setString(_repoKey, v);
          }),
          const SizedBox(height: 16),
          Row(children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: colors.primary,
              child: const Icon(Icons.terminal, size: 13, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.tr('addDeviceRun'),
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 6),
          _CmdBlock(
            colors: colors,
            shown: shownCmd,
            copyText: realCmd,
            revealed: _reveal,
            onToggle: () => setState(() => _reveal = !_reveal),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.lightbulb_outline, size: 16, color: colors.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(context.tr('addDeviceTip'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _field(RasedColors colors, TextEditingController c, String label,
      {String? hint, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      onChanged: (v) {
        if (onChanged != null) onChanged(v);
        setState(() {});
      },
      style: TextStyle(color: colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Monospace command box. [shown] is displayed (may be masked); [copyText] is
/// what actually gets copied. The eye toggles secret visibility.
class _CmdBlock extends StatelessWidget {
  final RasedColors colors;
  final String shown;
  final String copyText;
  final bool revealed;
  final VoidCallback onToggle;

  const _CmdBlock({
    required this.colors,
    required this.shown,
    required this.copyText,
    required this.revealed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SelectableText(
              shown,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: colors.textPrimary,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(revealed ? Icons.visibility_off : Icons.visibility,
                    size: 16),
                label: Text(revealed
                    ? context.tr('hideSecrets')
                    : context.tr('revealSecrets')),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: copyText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('copied'))),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(context.tr('copy')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
