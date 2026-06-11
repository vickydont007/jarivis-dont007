import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
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
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'API Key',
                _apiKey,
                (value) {
                  setState(() {
                    _apiKey = value;
                  });
                },
                isPassword: true,
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
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
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
  }) {
    return TextField(
      obscureText: isPassword,
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
      value: value,
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
      onChanged: onChanged,
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
        Text(
          label,
          style: TextStyle(color: Colors.grey[400]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.cyan,
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
            Text(
              label,
              style: TextStyle(color: Colors.grey[400]),
            ),
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
    // Connect to AI engine
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Initialize AI engine
    await ref.read(appStateProvider.notifier).initializeAI(
      provider: provider,
      apiKey: apiKey,
    );

    final appState = ref.read(appStateProvider);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.isConnected
                ? 'Connected to ${_selectedAIProvider.toUpperCase()}!'
                : 'Failed to connect. Using offline mode.',
          ),
          backgroundColor: appState.isConnected ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _resetSettings() {
    setState(() {
      _selectedAIProvider = 'openrouter';
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings reset to defaults'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
