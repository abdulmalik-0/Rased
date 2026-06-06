import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

const _providerDefaults = {
  'ollama': 'http://localhost:11434/v1',
  'lm_studio': 'http://localhost:1234/v1',
  'anthropic': 'https://api.anthropic.com',
  'cloud': '',
  'custom': '',
};

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  String _providerType = 'ollama';
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _modelController = TextEditingController();
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _loadFromConfig(AIProviderConfig config) {
    setState(() {
      _providerType = config.providerType;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.modelName;
      _loaded = true;
    });
  }

  void _onProviderChanged(String? value) {
    if (value == null) return;
    setState(() {
      _providerType = value;
      final defaultUrl = _providerDefaults[value] ?? '';
      if (defaultUrl.isNotEmpty) {
        _baseUrlController.text = defaultUrl;
      } else if (value == 'cloud' || value == 'custom') {
        _baseUrlController.clear();
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(settingsProvider.notifier).save(
            AIProviderConfig(
              providerType: _providerType,
              baseUrl: _baseUrlController.text.trim(),
              modelName: _modelController.text.trim(),
              apiKey: _apiKeyController.text,
            ),
          );
      _apiKeyController.clear();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('settingsSaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('${context.tr('settingsSaveFailed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Load saved config into the form once.
    ref.listen(settingsProvider, (prev, next) {
      next.whenData((config) {
        if (config != null && !_loaded) _loadFromConfig(config);
      });
    });
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settingsTitle'))),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _appearanceSection(colors),
                  const SizedBox(height: 32),
                  _aiSection(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(RasedColors colors, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget _appearanceSection(RasedColors colors) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(colors, context.tr('appearance')),
        Text(context.tr('language'),
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'en', label: Text(context.tr('languageEnglish'))),
            ButtonSegment(
                value: 'ar', label: Text(context.tr('languageArabic'))),
          ],
          selected: {locale.languageCode},
          onSelectionChanged: (s) =>
              ref.read(localeProvider.notifier).set(Locale(s.first)),
        ),
        const SizedBox(height: 16),
        Text(context.tr('theme'),
            style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
                value: ThemeMode.dark, label: Text(context.tr('themeDark'))),
            ButtonSegment(
                value: ThemeMode.light, label: Text(context.tr('themeLight'))),
            ButtonSegment(
                value: ThemeMode.system, label: Text(context.tr('themeSystem'))),
          ],
          selected: {themeMode},
          onSelectionChanged: (s) =>
              ref.read(themeModeProvider.notifier).set(s.first),
        ),
      ],
    );
  }

  Widget _aiSection(RasedColors colors) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(colors, context.tr('aiProviderSettings')),
          Text(
            context.tr('configureProvider'),
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _providerType,
            decoration:
                InputDecoration(labelText: context.tr('providerType')),
            items: [
              DropdownMenuItem(
                  value: 'ollama', child: Text(context.tr('providerOllama'))),
              DropdownMenuItem(
                  value: 'lm_studio',
                  child: Text(context.tr('providerLmStudio'))),
              DropdownMenuItem(
                  value: 'anthropic',
                  child: Text(context.tr('providerAnthropic'))),
              DropdownMenuItem(
                  value: 'cloud', child: Text(context.tr('providerCloud'))),
              DropdownMenuItem(
                  value: 'custom', child: Text(context.tr('providerCustom'))),
            ],
            onChanged: _onProviderChanged,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _baseUrlController,
            decoration: InputDecoration(
              labelText: context.tr('baseUrl'),
              hintText: 'https://api.openai.com/v1',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? context.tr('required') : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: context.tr('modelName'),
              hintText: 'llama3.2, gpt-4o, etc.',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? context.tr('required') : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr('apiKey'),
              hintText: _providerType == 'ollama' || _providerType == 'lm_studio'
                  ? context.tr('apiKeyOptional')
                  : context.tr('apiKeyRequired'),
            ),
            validator: (v) {
              if ((_providerType == 'cloud' || _providerType == 'anthropic') &&
                  (v == null || v.isEmpty)) {
                return context.tr('apiKeyRequiredError');
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('apiKeyEncrypted'),
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('saveSettings')),
          ),
        ],
      ),
    );
  }
}
