import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Guided "add a Linux machine" dialog. Editable fields, two ways to get the
/// code onto the new machine (Git clone or scp), and masked secrets (Copy
/// still copies the real values).
class AddDeviceDialog extends ConsumerStatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  ConsumerState<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends ConsumerState<AddDeviceDialog> {
  static const _repoKey = 'agent_repo_url';

  final _hostId = TextEditingController(text: 'lxc-2');
  final _name = TextEditingController(text: 'LXC 2');
  final _sshUser = TextEditingController(text: 'root');
  final _machineIp = TextEditingController();
  late final TextEditingController _repoUrl;
  bool _useGit = true;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(sharedPrefsProvider).getString(_repoKey);
    _repoUrl = TextEditingController(
        text: saved ?? 'https://github.com/abdulmalik-0/Rased.git');
  }

  @override
  void dispose() {
    _hostId.dispose();
    _name.dispose();
    _sshUser.dispose();
    _machineIp.dispose();
    _repoUrl.dispose();
    super.dispose();
  }

  String _mask(String s) =>
      s.length <= 6 ? '••••••' : '${s.substring(0, 4)}${'•' * 16}';

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
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
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
                '${context.tr('addDeviceIntro')}  ${context.tr('agentLinuxNote')}',
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
    final user = _sshUser.text.trim().isEmpty ? 'root' : _sshUser.text.trim();
    final ip = _machineIp.text.trim().isEmpty
        ? 'NEW_MACHINE_IP'
        : _machineIp.text.trim();
    final repo = _repoUrl.text.trim().isEmpty
        ? 'https://github.com/abdulmalik-0/Rased.git'
        : _repoUrl.text.trim();

    final getCmd = _useGit
        ? 'git clone --depth 1 $repo ~/rased'
        : 'scp -r ~/rased $user@$ip:~/';
    final step1Label =
        _useGit ? context.tr('addDeviceStep1Git') : context.tr('addDeviceStep1');

    final realCmd = 'cd ~/rased && bash scripts/install-agent.sh '
        '--central $central --token $token --jwt $jwt --id $id --name "$name"';
    final shownCmd = 'cd ~/rased && bash scripts/install-agent.sh '
        '--central $central --token ${_reveal ? token : _mask(token)} '
        '--jwt ${_reveal ? jwt : _mask(jwt)} --id $id --name "$name"';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity
          Row(children: [
            Expanded(child: _field(colors, _hostId, context.tr('agentHostId'))),
            const SizedBox(width: 10),
            Expanded(child: _field(colors, _name, context.tr('displayName'))),
          ]),
          const SizedBox(height: 12),

          // How to get the code onto the new machine
          Wrap(spacing: 8, children: [
            ChoiceChip(
              avatar: const Icon(Icons.cloud_download_outlined, size: 16),
              label: Text(context.tr('methodGit')),
              selected: _useGit,
              onSelected: (_) => setState(() => _useGit = true),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.drive_file_move_outlined, size: 16),
              label: Text(context.tr('methodScp')),
              selected: !_useGit,
              onSelected: (_) => setState(() => _useGit = false),
            ),
          ]),
          const SizedBox(height: 10),

          if (_useGit) ...[
            _field(colors, _repoUrl, context.tr('agentRepoUrl'),
                hint: 'https://github.com/abdulmalik-0/Rased.git', onChanged: (v) {
              ref.read(sharedPrefsProvider).setString(_repoKey, v);
            }),
            const SizedBox(height: 6),
            Text(context.tr('agentGitNote'),
                style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ] else
            Row(children: [
              Expanded(
                  child: _field(colors, _sshUser, context.tr('agentSshUser'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _field(colors, _machineIp, context.tr('agentNewIp'),
                      hint: '192.168.100.x')),
            ]),
          const SizedBox(height: 16),

          _stepLabel(colors, '1', step1Label),
          const SizedBox(height: 6),
          _CmdBlock(colors: colors, shown: getCmd, copyText: getCmd),
          const SizedBox(height: 16),

          _stepLabel(colors, '2', context.tr('addDeviceStep2')),
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

  Widget _stepLabel(RasedColors colors, String n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: colors.primary,
          child: Text(n,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text,
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

/// Monospace command box. [shown] is displayed (may be masked); [copyText] is
/// what actually gets copied. An optional eye toggles secret visibility.
class _CmdBlock extends StatelessWidget {
  final RasedColors colors;
  final String shown;
  final String copyText;
  final bool? revealed;
  final VoidCallback? onToggle;

  const _CmdBlock({
    required this.colors,
    required this.shown,
    required this.copyText,
    this.revealed,
    this.onToggle,
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
              if (onToggle != null)
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                      (revealed ?? false)
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16),
                  label: Text((revealed ?? false)
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
