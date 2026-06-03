import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

const _providerDefaults = {
  'ollama': 'http://localhost:11434/v1',
  'lm_studio': 'http://localhost:1234/v1',
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
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  String _providerType = 'ollama';
  bool _saving = false;

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

  void _loadFromConfig(AIProviderConfig? config) {
    if (config == null) return;
    _providerType = config.providerType;
    _baseUrlController.text = config.baseUrl;
    _modelController.text = config.modelName;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    settingsAsync.whenData((config) {
      if (_modelController.text.isEmpty && config != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadFromConfig(config);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('AI Provider Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Configure your AI provider. Supports any OpenAI-compatible API (Ollama, LM Studio, cloud).',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: _providerType,
                      decoration: const InputDecoration(labelText: 'Provider Type'),
                      items: const [
                        DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
                        DropdownMenuItem(value: 'lm_studio', child: Text('LM Studio')),
                        DropdownMenuItem(value: 'cloud', child: Text('Cloud API')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom')),
                      ],
                      onChanged: _onProviderChanged,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model Name',
                        hintText: 'llama3.2, gpt-4o, etc.',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: _providerType == 'ollama' || _providerType == 'lm_studio'
                            ? 'Optional for local providers'
                            : 'Required for cloud providers',
                      ),
                      validator: (v) {
                        if (_providerType == 'cloud' &&
                            (v == null || v.isEmpty)) {
                          return 'API key required for cloud providers';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'API keys are encrypted at rest in Supabase.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
