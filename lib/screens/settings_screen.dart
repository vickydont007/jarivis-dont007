import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../providers/app_provider.dart';
import '../core/ai_engine.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // AI Settings
  String _selectedAIProvider = 'openrouter';
  String _selectedModel = 'google/gemma-4-26b-a4b-it:free';
  String _apiKey = '';
  bool _useLocalAI = false;

  // Voice Settings
  bool _voiceEnabled = true;
  String _selectedLanguage = 'both';
  double _speechRate = 0.5;

  // Weather Settings
  String _weatherApiKey = '';
  String _defaultCity = 'New York';

  // Social Media Settings
  String _telegramBotToken = '';
  String _discordBotToken = '';

  // Dynamic models from OpenRouter
  List<String> _openRouterModels = [];
  bool _isLoadingModels = false;
  String _modelError = '';

  // Static models for other providers
  final Map<String, List<String>> _modelsByProvider = {
    'ollama': ['llama3.2', 'llama3.1', 'mistral', 'codellama', 'phi3', 'gemma'],
    'openai': ['gpt-4', 'gpt-4-turbo', 'gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo'],
    'anthropic': ['claude-3-opus', 'claude-3-sonnet', 'claude-3-haiku', 'claude-3.5-sonnet'],
    'gemini': ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchOpenRouterModels();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAIProvider = prefs.getString('ai_provider') ?? 'openrouter';
      _selectedModel = prefs.getString('ai_model') ?? 'google/gemma-4-26b-a4b-it:free';
      _apiKey = prefs.getString('ai_api_key') ?? '';
      _useLocalAI = prefs.getBool('use_local_ai') ?? false;
      _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _selectedLanguage = prefs.getString('voice_language') ?? 'both';
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _weatherApiKey = prefs.getString('weather_api_key') ?? '';
      _defaultCity = prefs.getString('default_city') ?? 'New York';
      _telegramBotToken = prefs.getString('telegram_bot_token') ?? '';
      _discordBotToken = prefs.getString('discord_bot_token') ?? '';
    });
  }

  Future<void> _fetchOpenRouterModels() async {
    setState(() {
      _isLoadingModels = true;
      _modelError = '';
    });

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://openrouter.ai/api/v1/models',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final models = List<Map<String, dynamic>>.from(response.data['data']);
        final freeModels = models.where((m) {
          final id = m['id'] as String? ?? '';
          if (id.endsWith(':free')) return true;
          final pricing = m['pricing'] as Map<String, dynamic>?;
          if (pricing != null) {
            final prompt = pricing['prompt'] as String? ?? '0';
            final completion = pricing['completion'] as String? ?? '0';
            final request = pricing['request'] as String? ?? '0';
            if (double.tryParse(prompt) == 0 &&
                double.tryParse(completion) == 0 &&
                double.tryParse(request) == 0) {
              return true;
            }
          }
          return false;
        }).map((m) => m['id'] as String).toList();

        freeModels.sort();

        setState(() {
          _openRouterModels = freeModels;
          _isLoadingModels = false;
          if (freeModels.isNotEmpty && !freeModels.contains(_selectedModel)) {
            _selectedModel = freeModels.first;
          }
        });
      } else {
        setState(() {
          _modelError = 'Failed to fetch models';
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      setState(() {
        _modelError = 'Network error';
        _isLoadingModels = false;
      });
    }
  }

  List<String> get _currentModels {
    if (_selectedAIProvider == 'openrouter') {
      if (_openRouterModels.isNotEmpty) return _openRouterModels;
      if (_modelError.isNotEmpty) return [];
      return ['Loading...'];
    }
    return _modelsByProvider[_selectedAIProvider] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure your Jarvis assistant',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),

            // AI Settings
            _buildSectionHeader('AI Configuration', Icons.psychology),
            _buildCard([
              _buildDropdown(
                'AI Provider',
                _selectedAIProvider,
                ['openrouter', 'ollama', 'openai', 'anthropic', 'gemini'],
                (value) {
                  setState(() {
                    _selectedAIProvider = value!;
                    if (value == 'openrouter') {
                      _fetchOpenRouterModels();
                    } else {
                      _selectedModel = _currentModels.isNotEmpty ? _currentModels.first : '';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedAIProvider == 'openrouter' && _isLoadingModels)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyan,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Fetching models from OpenRouter...',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              if (_modelError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Could not fetch models. Save an API key first.',
                        style: TextStyle(color: Colors.orange[300], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              _buildDropdown(
                'Model (${_currentModels.length} available)',
                _selectedModel,
                _currentModels,
                (value) {
                  setState(() {
                    _selectedModel = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'OpenRouter API Key',
                _apiKey,
                (value) {
                  setState(() {
                    _apiKey = value;
                  });
                },
                isPassword: true,
                hint: 'sk-or-v1-...',
              ),
              const SizedBox(height: 16),
              _buildSwitch(
                'Use Local AI (Ollama)',
                _useLocalAI,
                (value) {
                  setState(() {
                    _useLocalAI = value;
                  });
                },
              ),
            ]),
            const SizedBox(height: 16),

            // Voice Settings
            _buildSectionHeader('Voice Settings', Icons.mic),
            _buildCard([
              _buildSwitch(
                'Enable Voice',
                _voiceEnabled,
                (value) {
                  setState(() {
                    _voiceEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                'Language',
                _selectedLanguage,
                ['english', 'hindi', 'both'],
                (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildSlider(
                'Speech Rate',
                _speechRate,
                (value) {
                  setState(() {
                    _speechRate = value;
                  });
                },
              ),
            ]),
            const SizedBox(height: 16),

            // Weather Settings
            _buildSectionHeader('Weather Settings', Icons.cloud),
            _buildCard([
              _buildTextField(
                'OpenWeatherMap API Key',
                _weatherApiKey,
                (value) {
                  setState(() {
                    _weatherApiKey = value;
                  });
                },
                isPassword: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Default City',
                _defaultCity,
                (value) {
                  setState(() {
                    _defaultCity = value;
                  });
                },
              ),
            ]),
            const SizedBox(height: 16),

            // Social Media Settings
            _buildSectionHeader('Social Media', Icons.share),
            _buildCard([
              _buildTextField(
                'Telegram Bot Token',
                _telegramBotToken,
                (value) {
                  setState(() {
                    _telegramBotToken = value;
                  });
                },
                isPassword: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Discord Bot Token',
                _discordBotToken,
                (value) {
                  setState(() {
                    _discordBotToken = value;
                  });
                },
                isPassword: true,
              ),
            ]),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reset Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetSettings,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Reset to Defaults',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyan, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String) onChanged, {
    bool isPassword = false,
    String? hint,
  }) {
    return TextField(
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item.toUpperCase()),
        );
      }).toList(),
      onChanged: items.isNotEmpty ? onChanged : null,
    );
  }

  Widget _buildSwitch(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.cyan,
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[400])),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(color: Colors.cyan),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.cyan,
          inactiveColor: const Color(0xFF30363D),
        ),
      ],
    );
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('ai_provider', _selectedAIProvider);
    await prefs.setString('ai_model', _selectedModel);
    await prefs.setString('ai_api_key', _apiKey);
    await prefs.setBool('use_local_ai', _useLocalAI);
    await prefs.setBool('voice_enabled', _voiceEnabled);
    await prefs.setString('voice_language', _selectedLanguage);
    await prefs.setDouble('speech_rate', _speechRate);
    await prefs.setString('weather_api_key', _weatherApiKey);
    await prefs.setString('default_city', _defaultCity);
    await prefs.setString('telegram_bot_token', _telegramBotToken);
    await prefs.setString('discord_bot_token', _discordBotToken);

    AIProvider provider;
    switch (_selectedAIProvider) {
      case 'openrouter':
        provider = AIProvider.openrouter;
        break;
      case 'ollama':
        provider = AIProvider.ollama;
        break;
      case 'openai':
        provider = AIProvider.openai;
        break;
      case 'anthropic':
        provider = AIProvider.anthropic;
        break;
      case 'gemini':
        provider = AIProvider.gemini;
        break;
      default:
        provider = AIProvider.openrouter;
    }

    final apiKey = _useLocalAI ? 'local' : _apiKey;

    if (apiKey.isEmpty && !_useLocalAI) {
      Future.delayed(Duration.zero, () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter an API key'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return;
    }

    await ref.read(appStateProvider.notifier).initializeAI(
      provider: provider,
      apiKey: apiKey,
      modelName: _selectedModel,
    );

    final appState = ref.read(appStateProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.isConnected
                ? 'Settings saved! Connected to ${_selectedAIProvider.toUpperCase()}!'
                : 'Settings saved. Failed to connect. Using offline mode.',
          ),
          backgroundColor: appState.isConnected ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('ai_provider'),
      prefs.remove('ai_model'),
      prefs.remove('ai_api_key'),
      prefs.remove('use_local_ai'),
      prefs.remove('voice_enabled'),
      prefs.remove('voice_language'),
      prefs.remove('speech_rate'),
      prefs.remove('weather_api_key'),
      prefs.remove('default_city'),
      prefs.remove('telegram_bot_token'),
      prefs.remove('discord_bot_token'),
    ]);

    setState(() {
      _selectedAIProvider = 'openrouter';
      _selectedModel = 'google/gemma-4-26b-a4b-it:free';
      _apiKey = '';
      _useLocalAI = false;
      _voiceEnabled = true;
      _selectedLanguage = 'both';
      _speechRate = 0.5;
      _weatherApiKey = '';
      _defaultCity = 'New York';
      _telegramBotToken = '';
      _discordBotToken = '';
    });

    _fetchOpenRouterModels();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings reset to defaults'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
