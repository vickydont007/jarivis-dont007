import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/app_provider.dart';
import '../core/ai_engine.dart';
import '../services/voice_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedAIProvider = 'openrouter';
  String _selectedModel = 'google/gemma-4-26b-a4b-it:free';
  String _apiKey = '';
  bool _useLocalAI = false;

  String _userName = '';
  String _aiName = 'Nexa';
  String _ttsVoiceName = 'Samantha';
  List<Map<String, dynamic>> _availableVoices = [];

  bool _voiceEnabled = true;
  String _selectedLanguage = 'both';
  double _speechRate = 0.5;

  String _weatherApiKey = '';
  String _defaultCity = 'New York';

  String _telegramBotToken = '';
  String _discordBotToken = '';
  String _facebookAccessToken = '';
  String _facebookPageId = '';
  String _instagramAccessToken = '';
  String _instagramPageId = '';
  String _whatsappAccessToken = '';
  String _whatsappPhoneNumberId = '';
  String _whatsappBusinessAccountId = '';

  List<String> _openRouterModels = [];
  bool _isLoadingModels = false;
  String _modelError = '';

  bool _isSaving = false;
  
  String? _userProfilePhoto;
  String? _aiProfilePhoto;
  final ImagePicker _imagePicker = ImagePicker();

  final Map<String, List<String>> _modelsByProvider = {
    'ollama': ['gemma4:e4b', 'hermes3:latest', 'gemma3:4b', 'qwen2.5-coder:7b'],
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
      _userName = prefs.getString('user_name') ?? '';
      _aiName = prefs.getString('ai_name') ?? 'Nexa';
      _ttsVoiceName = prefs.getString('tts_voice_name') ?? 'Samantha';
      _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _selectedLanguage = prefs.getString('voice_language') ?? 'both';
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _weatherApiKey = prefs.getString('weather_api_key') ?? '';
      _defaultCity = prefs.getString('default_city') ?? 'New York';
      _telegramBotToken = prefs.getString('telegram_bot_token') ?? '';
      _discordBotToken = prefs.getString('discord_bot_token') ?? '';
      _facebookAccessToken = prefs.getString('facebook_access_token') ?? '';
      _facebookPageId = prefs.getString('facebook_page_id') ?? '';
      _instagramAccessToken = prefs.getString('instagram_access_token') ?? '';
      _instagramPageId = prefs.getString('instagram_page_id') ?? '';
      _whatsappAccessToken = prefs.getString('whatsapp_access_token') ?? '';
      _whatsappPhoneNumberId = prefs.getString('whatsapp_phone_number_id') ?? '';
      _whatsappBusinessAccountId = prefs.getString('whatsapp_business_account_id') ?? '';
      _userProfilePhoto = prefs.getString('user_profile_photo');
      _aiProfilePhoto = prefs.getString('ai_profile_photo');
    });
    _loadVoices();
    
    // Auto-fetch models based on provider
    if (_selectedAIProvider == 'openrouter') {
      _fetchOpenRouterModels();
    } else if (_selectedAIProvider == 'ollama') {
      _fetchOllamaModels();
    }
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

  Future<void> _fetchOllamaModels() async {
    setState(() {
      _isLoadingModels = true;
      _modelError = '';
    });

    try {
      final dio = Dio();
      final response = await dio.get(
        'http://localhost:11434/api/tags',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      if (response.statusCode == 200 && response.data['models'] != null) {
        final models = List<Map<String, dynamic>>.from(response.data['models']);
        final modelNames = models.map((m) => m['name'] as String).toList();
        modelNames.sort();

        setState(() {
          _modelsByProvider['ollama'] = modelNames;
          _isLoadingModels = false;
          if (modelNames.isNotEmpty && !modelNames.contains(_selectedModel)) {
            _selectedModel = modelNames.first;
          }
        });
      } else {
        setState(() {
          _modelError = 'Ollama not responding. Is it running?';
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      setState(() {
        _modelError = 'Cannot connect to Ollama at localhost:11434';
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _loadVoices() async {
    try {
      final voices = VoiceService.allVoices;
      if (mounted) {
        setState(() => _availableVoices = voices);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableVoices = [
            {'name': 'Samantha', 'locale': 'en-US'},
            {'name': 'Karen', 'locale': 'en-AU'},
            {'name': 'Alex', 'locale': 'en-US'},
          ];
        });
      }
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            _buildSection('AI Configuration', Icons.psychology, [
              _buildProviderDropdown(),
              const SizedBox(height: 16),
              if (_selectedAIProvider == 'openrouter') _buildModelLoader(),
              _buildModelDropdown(),
              const SizedBox(height: 16),
              _buildApiKeyField(),
              const SizedBox(height: 16),
              _buildLocalAIToggle(),
            ]),
            const SizedBox(height: 20),
            _buildSection('Personal Info', Icons.person, [
              _buildProfilePhotoSection(),
              const SizedBox(height: 16),
              _buildUserNameField(),
              const SizedBox(height: 16),
              _buildAINameField(),
            ]),
            const SizedBox(height: 20),
            _buildSection('Voice Settings', Icons.mic, [
              _buildVoiceToggle(),
              const SizedBox(height: 16),
              _buildTTSVoiceDropdown(),
              const SizedBox(height: 16),
              _buildLanguageDropdown(),
              const SizedBox(height: 16),
              _buildSpeechRateSlider(),
            ]),
            const SizedBox(height: 20),
            _buildSection('Weather Settings', Icons.cloud, [
              _buildWeatherApiKeyField(),
              const SizedBox(height: 16),
              _buildDefaultCityField(),
            ]),
            const SizedBox(height: 20),
            _buildSection('Social Media', Icons.share, [
              _buildTelegramTokenField(),
              const SizedBox(height: 16),
              _buildDiscordTokenField(),
              const SizedBox(height: 16),
              _buildFacebookFields(),
              const SizedBox(height: 16),
              _buildInstagramFields(),
              const SizedBox(height: 16),
              _buildWhatsAppFields(),
            ]),
            const SizedBox(height: 20),
            _buildSection('Advanced Features', Icons.auto_awesome, [
              _buildFeatureInfo('Screen Context', 'Capture and analyze screen content'),
              const SizedBox(height: 12),
              _buildFeatureInfo('Cross-App Bridge', 'Interact with other applications'),
              const SizedBox(height: 12),
              _buildFeatureInfo('Predictive Automation', 'Learn and automate workflows'),
              const SizedBox(height: 12),
              _buildFeatureInfo('Screen Recording', 'Record screen activity'),
              const SizedBox(height: 12),
              _buildFeatureInfo('Meeting Assistant', 'Take notes and manage meetings'),
              const SizedBox(height: 12),
              _buildFeatureInfo('Notification Intelligence', 'Smart notification management'),
              const SizedBox(height: 12),
              _buildFeatureInfo('File Converter', 'Convert files between formats'),
            ]),
            const SizedBox(height: 28),
            _buildSaveButton(),
            const SizedBox(height: 12),
            _buildResetButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.settings, color: Color(0xFF00BCD4), size: 28),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Configure your Nextron assistant',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00BCD4), size: 20),
              const SizedBox(width: 10),
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
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFeatureInfo(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderDropdown() {
    return _buildDropdown(
      'AI Provider',
      _selectedAIProvider,
      ['openrouter', 'ollama', 'openai', 'anthropic', 'gemini'],
      (value) {
        setState(() {
          _selectedAIProvider = value!;
          if (value == 'openrouter') {
            _useLocalAI = false;
            if (_apiKey == 'local') _apiKey = '';
            _fetchOpenRouterModels();
          } else if (value == 'ollama') {
            _useLocalAI = true;
            _apiKey = 'local';
            _fetchOllamaModels();
          } else {
            _useLocalAI = false;
            if (_apiKey == 'local') _apiKey = '';
            _selectedModel = _currentModels.isNotEmpty ? _currentModels.first : '';
          }
        });
      },
    );
  }

  Widget _buildModelLoader() {
    if (!_isLoadingModels) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BCD4)),
          ),
          const SizedBox(width: 10),
          Text(
            _selectedAIProvider == 'ollama'
                ? 'Fetching models from Ollama...'
                : 'Fetching models from OpenRouter...',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildModelDropdown() {
    return _buildDropdown(
      'Model (${_currentModels.length} available)',
      _selectedModel,
      _currentModels,
      (value) => setState(() => _selectedModel = value!),
    );
  }

  Widget _buildApiKeyField() {
    final isLocal = _selectedAIProvider == 'ollama' || _useLocalAI;
    return _buildTextField(
      isLocal ? 'API Key (not needed for Ollama)' : 'API Key',
      isLocal ? '' : _apiKey,
      isLocal ? null : (value) => setState(() => _apiKey = value),
      isPassword: false,
      hint: isLocal ? 'Ollama runs locally - no key needed' : 'sk-or-v1-...',
    );
  }

  Widget _buildLocalAIToggle() {
    return _buildSwitch(
      'Use Local AI (Ollama)',
      _useLocalAI,
      (value) {
        setState(() {
          _useLocalAI = value;
          if (value) {
            // Force Ollama provider when toggling on
            _selectedAIProvider = 'ollama';
            _apiKey = 'local';
            // Set default Ollama model
            if (!_modelsByProvider['ollama']!.contains(_selectedModel)) {
              _selectedModel = 'gemma4:e4b';
            }
          }
        });
      },
    );
  }

  Widget _buildProfilePhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Photos',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // User profile photo
            Column(
              children: [
                GestureDetector(
                  onTap: () => _pickProfilePhoto(isUser: true),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.blue.withValues(alpha: 0.3),
                        backgroundImage: _userProfilePhoto != null ? FileImage(File(_userProfilePhoto!)) : null,
                        child: _userProfilePhoto == null
                            ? const Icon(Icons.person, color: Colors.white, size: 32)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('Your Photo', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
            const SizedBox(width: 32),
            // AI girlfriend profile photo
            Column(
              children: [
                GestureDetector(
                  onTap: () => _pickProfilePhoto(isUser: false),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.pink.withValues(alpha: 0.3),
                        backgroundImage: _aiProfilePhoto != null ? FileImage(File(_aiProfilePhoto!)) : null,
                        child: _aiProfilePhoto == null
                            ? const Text('💕', style: TextStyle(fontSize: 32))
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.pink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('AI Photo', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickProfilePhoto({required bool isUser}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        // Copy to app directory
        final appDir = await getApplicationDocumentsDirectory();
        final photosDir = Directory(p.join(appDir.path, 'profile_photos'));
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }
        
        final fileName = isUser ? 'user_profile.jpg' : 'ai_profile.jpg';
        final savedFile = await File(pickedFile.path).copy(p.join(photosDir.path, fileName));
        
        setState(() {
          if (isUser) {
            _userProfilePhoto = savedFile.path;
          } else {
            _aiProfilePhoto = savedFile.path;
          }
        });

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (isUser) {
          await prefs.setString('user_profile_photo', savedFile.path);
        } else {
          await prefs.setString('ai_profile_photo', savedFile.path);
        }
      }
    } catch (e) {
      debugPrint('Profile photo picker error: $e');
    }
  }

  Widget _buildUserNameField() {
    return _buildTextField(
      'Your Name',
      _userName,
      (value) => setState(() => _userName = value),
      hint: 'Enter your name for personalized greetings',
    );
  }

  Widget _buildAINameField() {
    return _buildTextField(
      'AI Name (What she calls herself)',
      _aiName,
      (value) => setState(() => _aiName = value),
      hint: 'Default: Nexa',
    );
  }

  Widget _buildTTSVoiceDropdown() {
    final voiceNames = _availableVoices.map((v) => v['name'] as String).toList();
    if (!voiceNames.contains(_ttsVoiceName) && voiceNames.isNotEmpty) {
      _ttsVoiceName = voiceNames.first;
    }
    return _buildDropdown(
      'TTS Voice (Female)',
      _ttsVoiceName,
      voiceNames.isNotEmpty ? voiceNames : ['Samantha', 'Karen', 'Victoria'],
      (value) => setState(() => _ttsVoiceName = value!),
    );
  }

  Widget _buildVoiceToggle() {
    return _buildSwitch(
      'Enable Voice',
      _voiceEnabled,
      (value) => setState(() => _voiceEnabled = value),
    );
  }

  Widget _buildLanguageDropdown() {
    return _buildDropdown(
      'Language',
      _selectedLanguage,
      ['english', 'hindi', 'both'],
      (value) => setState(() => _selectedLanguage = value!),
    );
  }

  Widget _buildSpeechRateSlider() {
    return _buildSlider(
      'Speech Rate',
      _speechRate,
      (value) => setState(() => _speechRate = value),
    );
  }

  Widget _buildWeatherApiKeyField() {
    return _buildTextField(
      'OpenWeatherMap API Key',
      _weatherApiKey,
      (value) => setState(() => _weatherApiKey = value),
      isPassword: true,
    );
  }

  Widget _buildDefaultCityField() {
    return _buildTextField(
      'Default City',
      _defaultCity,
      (value) => setState(() => _defaultCity = value),
    );
  }

  Widget _buildTelegramTokenField() {
    return _buildTextField(
      'Telegram Bot Token',
      _telegramBotToken,
      (value) => setState(() => _telegramBotToken = value),
      isPassword: true,
    );
  }

  Widget _buildDiscordTokenField() {
    return _buildTextField(
      'Discord Bot Token',
      _discordBotToken,
      (value) => setState(() => _discordBotToken = value),
      isPassword: true,
    );
  }

  Widget _buildFacebookFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 20),
            const SizedBox(width: 8),
            Text('Facebook', style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        _buildTextField(
          'Page Access Token',
          _facebookAccessToken,
          (value) => setState(() => _facebookAccessToken = value),
          isPassword: true,
          hint: 'EAAxxx...',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          'Page ID',
          _facebookPageId,
          (value) => setState(() => _facebookPageId = value),
          hint: '123456789',
        ),
      ],
    );
  }

  Widget _buildInstagramFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.camera_alt, color: Color(0xFFE4405F), size: 20),
            const SizedBox(width: 8),
            Text('Instagram', style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        _buildTextField(
          'Access Token',
          _instagramAccessToken,
          (value) => setState(() => _instagramAccessToken = value),
          isPassword: true,
        ),
        const SizedBox(height: 8),
        _buildTextField(
          'Page ID',
          _instagramPageId,
          (value) => setState(() => _instagramPageId = value),
        ),
      ],
    );
  }

  Widget _buildWhatsAppFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
            const SizedBox(width: 8),
            Text('WhatsApp Business', style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        _buildTextField(
          'Access Token',
          _whatsappAccessToken,
          (value) => setState(() => _whatsappAccessToken = value),
          isPassword: true,
        ),
        const SizedBox(height: 8),
        _buildTextField(
          'Phone Number ID',
          _whatsappPhoneNumberId,
          (value) => setState(() => _whatsappPhoneNumberId = value),
          hint: '1234567890',
        ),
        const SizedBox(height: 8),
        _buildTextField(
          'Business Account ID',
          _whatsappBusinessAccountId,
          (value) => setState(() => _whatsappBusinessAccountId = value),
          hint: '123456789',
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String)? onChanged, {
    bool isPassword = false,
    String? hint,
  }) {
    final controller = TextEditingController(text: value);
    return TextField(
      controller: controller,
      obscureText: isPassword,
      enabled: onChanged != null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00BCD4)),
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
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00BCD4)),
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

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF00BCD4),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[400])),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(color: Color(0xFF00BCD4)),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00BCD4),
          inactiveColor: const Color(0xFF30363D),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BCD4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: const Color(0xFF00BCD4).withValues(alpha: 0.3),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Save Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _resetSettings,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF30363D)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Reset to Defaults',
          style: TextStyle(color: Colors.grey[500], fontSize: 16),
        ),
      ),
    );
  }

  void _saveSettings() async {
    setState(() => _isSaving = true);

    try {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('ai_provider', _selectedAIProvider);
    await prefs.setString('ai_model', _selectedModel);
    await prefs.setString('ai_api_key', _apiKey);
    await prefs.setBool('use_local_ai', _useLocalAI);
    await prefs.setString('user_name', _userName);
    await prefs.setString('ai_name', _aiName);
    await prefs.setString('tts_voice_name', _ttsVoiceName);
    String voiceLocale = 'en-US';
    if (_availableVoices.isNotEmpty) {
      final match = _availableVoices.where((v) => v['name'] == _ttsVoiceName);
      if (match.isNotEmpty) {
        voiceLocale = match.first['locale'] ?? 'en-US';
      }
    }
    await prefs.setString('tts_voice_locale', voiceLocale);
    await prefs.setBool('voice_enabled', _voiceEnabled);
    await prefs.setString('voice_language', _selectedLanguage);
    await prefs.setDouble('speech_rate', _speechRate);
    await prefs.setString('weather_api_key', _weatherApiKey);
    await prefs.setString('default_city', _defaultCity);
    await prefs.setString('telegram_bot_token', _telegramBotToken);
    await prefs.setString('discord_bot_token', _discordBotToken);
    await prefs.setString('facebook_access_token', _facebookAccessToken);
    await prefs.setString('facebook_page_id', _facebookPageId);
    await prefs.setString('instagram_access_token', _instagramAccessToken);
    await prefs.setString('instagram_page_id', _instagramPageId);
    await prefs.setString('whatsapp_access_token', _whatsappAccessToken);
    await prefs.setString('whatsapp_phone_number_id', _whatsappPhoneNumberId);
    await prefs.setString('whatsapp_business_account_id', _whatsappBusinessAccountId);

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
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter an API key'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await ref.read(appStateProvider.notifier).initializeAI(
      provider: provider,
      apiKey: apiKey,
      modelName: _selectedModel,
    );

    // Setup social media platforms
    final socialManager = ref.read(appStateProvider).socialManager;
    if (socialManager != null) {
      if (_facebookAccessToken.isNotEmpty && _facebookPageId.isNotEmpty) {
        socialManager.setupFacebook(accessToken: _facebookAccessToken, pageId: _facebookPageId);
      }
      if (_instagramAccessToken.isNotEmpty && _instagramPageId.isNotEmpty) {
        socialManager.setupInstagram(accessToken: _instagramAccessToken, pageId: _instagramPageId);
      }
      if (_whatsappAccessToken.isNotEmpty && _whatsappPhoneNumberId.isNotEmpty && _whatsappBusinessAccountId.isNotEmpty) {
        socialManager.setupWhatsApp(accessToken: _whatsappAccessToken, phoneNumberId: _whatsappPhoneNumberId, businessAccountId: _whatsappBusinessAccountId);
      }
    }

    setState(() => _isSaving = false);

    final appState = ref.read(appStateProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.isConnected
                ? 'Settings saved! Connected to ${_selectedAIProvider.toUpperCase()}!'
                : 'Settings saved. Failed to connect. Using offline mode.',
          ),
          backgroundColor: appState.isConnected ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
        ),
      );
    }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      prefs.remove('facebook_access_token'),
      prefs.remove('facebook_page_id'),
      prefs.remove('instagram_access_token'),
      prefs.remove('instagram_page_id'),
      prefs.remove('whatsapp_access_token'),
      prefs.remove('whatsapp_phone_number_id'),
      prefs.remove('whatsapp_business_account_id'),
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
      _facebookAccessToken = '';
      _facebookPageId = '';
      _instagramAccessToken = '';
      _instagramPageId = '';
      _whatsappAccessToken = '';
      _whatsappPhoneNumberId = '';
      _whatsappBusinessAccountId = '';
    });

    _fetchOpenRouterModels();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings reset to defaults'),
          backgroundColor: Color(0xFFFF9800),
        ),
      );
    }
  }
}
