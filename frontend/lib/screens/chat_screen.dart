import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String hostId;
  final String apiUrl;

  const ChatScreen({super.key, required this.hostId, this.apiUrl = ''});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _chats = [];
  String? _currentId;
  List<Map<String, String>> _messages = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChats());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    final client = ref.read(supabaseClientProvider);
    try {
      final rows = await client
          .from('ai_chats')
          .select('id,title,messages,updated_at')
          .eq('host_id', widget.hostId)
          .order('updated_at', ascending: false);
      if (mounted) {
        setState(() => _chats = (rows as List).cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  void _openChat(Map<String, dynamic> chat) {
    final raw = (chat['messages'] as List?) ?? [];
    setState(() {
      _currentId = chat['id'] as String?;
      _messages = raw
          .map((m) => {
                'role': (m['role'] ?? '').toString(),
                'content': (m['content'] ?? '').toString(),
              })
          .toList();
      _error = null;
    });
  }

  void _newChat() {
    setState(() {
      _currentId = null;
      _messages = [];
      _error = null;
    });
  }

  Future<void> _deleteChat(String id) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('ai_chats').delete().eq('id', id);
      if (id == _currentId) _newChat();
      await _loadChats();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final client = ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final firstUser = _messages.firstWhere(
      (m) => m['role'] == 'user',
      orElse: () => {'content': 'Chat'},
    )['content']!;
    final title = firstUser.length > 40 ? firstUser.substring(0, 40) : firstUser;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      if (_currentId == null) {
        final row = await client.from('ai_chats').insert({
          'user_id': uid,
          'host_id': widget.hostId,
          'title': title,
          'messages': _messages,
          'updated_at': now,
        }).select('id').single();
        _currentId = row['id'] as String?;
      } else {
        await client.from('ai_chats').update({
          'title': title,
          'messages': _messages,
          'updated_at': now,
        }).eq('id', _currentId!);
      }
      await _loadChats();
    } catch (_) {}
  }

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;

    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null || settings.modelName.isEmpty) {
      setState(() => _error = context.tr('askConfigureFirst'));
      return;
    }

    final history = List<Map<String, String>>.from(_messages);
    setState(() {
      _messages = [
        ..._messages,
        {'role': 'user', 'content': q},
      ];
      _controller.clear();
      _loading = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final res = await ref.read(backendServiceProvider).ask(
            question: q,
            aiConfig: settings,
            history: history,
            baseUrl: widget.apiUrl,
            lang: ref.read(localeProvider).languageCode,
          );
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          {'role': 'assistant', 'content': res.answer},
        ];
        _loading = false;
      });
      _scrollToBottom();
      await _persist();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.tr('chatTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: context.tr('conversations'),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: context.tr('newChat'),
            onPressed: _newChat,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.tr('newChat')),
                onTap: () {
                  Navigator.pop(context);
                  _newChat();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: _chats.isEmpty
                    ? Center(
                        child: Text(context.tr('noChats'),
                            style: TextStyle(color: colors.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, i) {
                          final c = _chats[i];
                          return ListTile(
                            dense: true,
                            selected: c['id'] == _currentId,
                            title: Text(
                              (c['title'] ?? 'Chat').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: colors.textSecondary),
                              onPressed: () => _deleteChat(c['id'] as String),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _openChat(c);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      context.tr('askEmpty'),
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _messages.length) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text(context.tr('askThinking'),
                                style: TextStyle(color: colors.textSecondary)),
                          ]),
                        );
                      }
                      return _bubble(colors, _messages[i]);
                    },
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!,
                  style: TextStyle(color: colors.danger, fontSize: 12)),
            ),
          _inputBar(colors),
        ],
      ),
    );
  }

  Widget _bubble(RasedColors colors, Map<String, String> m) {
    final isUser = m['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 640),
        decoration: BoxDecoration(
          color: isUser ? colors.primary.withValues(alpha: 0.15) : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: isUser
            ? Text(m['content'] ?? '',
                style: TextStyle(color: colors.textPrimary))
            : MarkdownBody(
                data: m['content'] ?? '',
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: colors.textPrimary, height: 1.5),
                  code: TextStyle(
                    backgroundColor: colors.surfaceElevated,
                    color: colors.accent,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _inputBar(RasedColors colors) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(hintText: context.tr('chatHint')),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _loading ? null : _send,
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(backgroundColor: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
