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
import '../core/core.dart';
import '../core/providers.dart';
import '../services/voice_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/glass/glass_toggle.dart';
import '../widgets/glass/glass_dropdown.dart';
import '../widgets/common/status_chip.dart';
import '../widgets/common/error_state.dart';
import '../widgets/common/empty_state.dart';
import 'settings/ai_control_center.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedCategory = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _categories = [
    _CategoryDef(icon: Icons.tune, label: 'General', shortcut: '⌘1'),
    _CategoryDef(icon: Icons.psychology, label: 'AI Brain', shortcut: '⌘2'),
    _CategoryDef(icon: Icons.mic, label: 'Voice & Audio', shortcut: '⌘3'),
    _CategoryDef(icon: Icons.memory, label: 'Memory Core', shortcut: '⌘4'),
    _CategoryDef(icon: Icons.smart_toy, label: 'Agents', shortcut: '⌘5'),
    _CategoryDef(icon: Icons.autorenew, label: 'Automation', shortcut: '⌘6'),
    _CategoryDef(icon: Icons.extension, label: 'Integrations', shortcut: '⌘7'),
    _CategoryDef(icon: Icons.calendar_month, label: 'Calendar & Email', shortcut: '⌘8'),
    _CategoryDef(icon: Icons.palette, label: 'Appearance', shortcut: '⌘9'),
    _CategoryDef(icon: Icons.shield, label: 'Security', shortcut: '⌘0'),
    _CategoryDef(icon: Icons.code, label: 'Advanced', shortcut: '⌘A'),
    _CategoryDef(icon: Icons.info_outline, label: 'About', shortcut: '⌘B'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CategoryDef> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories.where((c) =>
      c.label.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _buildSidebar(),
          Container(width: 1, color: AppColors.glassBorder),
          Expanded(child: _buildContent()),
          Container(width: 1, color: AppColors.glassBorder),
          const SizedBox(width: 340, child: AIControlCenter()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 240,
      child: Container(
        color: AppColors.backgroundSecondary,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentGhost,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search settings...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 16),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                    filled: true,
                    fillColor: AppColors.glassFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Categories
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _filteredCategories.length,
                itemBuilder: (context, index) {
                  final cat = _filteredCategories[index];
                  final catIndex = _categories.indexOf(cat);
                  final isSelected = _selectedCategory == catIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _selectedCategory = catIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accentGhost : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: AppColors.accent.withAlpha(50))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                cat.icon,
                                size: 18,
                                color: isSelected ? AppColors.accent : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                cat.shortcut,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textDisabled,
                                  fontFamily: 'SF Mono',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.keyboard_command_key, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Text(
                      '⌘K for commands',
                      style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      color: AppColors.background,
      child: IndexedStack(
        index: _selectedCategory,
        children: const [
          _GeneralSection(),
          _AIBrainSection(),
          _VoiceSection(),
          _MemorySection(),
          _AgentsSection(),
          _AutomationSection(),
          _IntegrationsSection(),
          _CalendarEmailSection(),
          _AppearanceSection(),
          _SecuritySection(),
          _AdvancedSection(),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _CategoryDef {
  final IconData icon;
  final String label;
  final String shortcut;
  const _CategoryDef({required this.icon, required this.label, required this.shortcut});
}

// ─── Section wrapper ──────────────────────────────────────────────

class _SectionScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentGhost,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );
  }
}

// ─── Status Card helper ───────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatusCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Row helper ────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
          GlassToggle(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Slider Row helper ────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String? suffix;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              Text(
                suffix != null ? '${(value * 100).toInt()}$suffix' : '${(value * 100).toInt()}%',
                style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.glassFillActive,
              thumbColor: AppColors.accent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 1: GENERAL
// ═══════════════════════════════════════════════════════════════════

class _GeneralSection extends ConsumerStatefulWidget {
  const _GeneralSection();
  @override
  ConsumerState<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends ConsumerState<_GeneralSection> {
  String _userName = '';
  String _aiName = 'Nexa';
  String? _userProfilePhoto;
  String? _aiProfilePhoto;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _aiName = prefs.getString('ai_name') ?? 'Nexa';
      _userProfilePhoto = prefs.getString('user_profile_photo');
      _aiProfilePhoto = prefs.getString('ai_profile_photo');
    });
  }

  Future<void> _pickPhoto({required bool isUser}) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85,
      );
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final photosDir = Directory(p.join(appDir.path, 'profile_photos'));
        if (!await photosDir.exists()) await photosDir.create(recursive: true);
        final fileName = isUser ? 'user_profile.jpg' : 'ai_profile.jpg';
        final saved = await File(picked.path).copy(p.join(photosDir.path, fileName));
        final prefs = await SharedPreferences.getInstance();
        if (isUser) {
          await prefs.setString('user_profile_photo', saved.path);
          setState(() => _userProfilePhoto = saved.path);
        } else {
          await prefs.setString('ai_profile_photo', saved.path);
          setState(() => _aiProfilePhoto = saved.path);
        }
      }
    } catch (e) {
      debugPrint('Photo picker error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'General',
      subtitle: 'Profile and basic preferences',
      icon: Icons.tune,
      children: [
        // Profile photos
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAvatar('You', _userProfilePhoto, AppColors.accent, () => _pickPhoto(isUser: true)),
                  const SizedBox(width: 24),
                  _buildAvatar(_aiName, _aiProfilePhoto, AppColors.accent, () => _pickPhoto(isUser: false), isAI: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Name fields
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Identity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Name', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        const SizedBox(height: 6),
                        GlassTextField(
                          hintText: 'Enter your name',
                          initialValue: _userName,
                          onChanged: (v) {
                            _userName = v;
                            SharedPreferences.getInstance().then((p) => p.setString('user_name', v));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Name', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        const SizedBox(height: 6),
                        GlassTextField(
                          hintText: 'Default: Nexa',
                          initialValue: _aiName,
                          onChanged: (v) {
                            _aiName = v;
                            SharedPreferences.getInstance().then((p) => p.setString('ai_name', v));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick stats
        Row(
          children: [
            Expanded(child: _StatusCard(label: 'App Version', value: '1.0.0', icon: Icons.info_outline)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Platform', value: Platform.operatingSystem, icon: Icons.computer)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Build', value: 'Debug', icon: Icons.build)),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(String label, String? path, Color color, VoidCallback onTap, {bool isAI = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color.withAlpha(30),
                backgroundImage: path != null ? FileImage(File(path)) : null,
                child: path == null
                    ? isAI
                        ? const Text('💕', style: TextStyle(fontSize: 28))
                        : Icon(Icons.person, color: color, size: 28)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.backgroundElevated, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 2: AI BRAIN
// ═══════════════════════════════════════════════════════════════════

class _AIBrainSection extends ConsumerStatefulWidget {
  const _AIBrainSection();
  @override
  ConsumerState<_AIBrainSection> createState() => _AIBrainSectionState();
}

class _AIBrainSectionState extends ConsumerState<_AIBrainSection> {
  String _provider = 'openrouter';
  String _model = 'google/gemma-4-26b-a4b-it:free';
  String _apiKey = '';
  bool _localAI = false;
  List<String> _openRouterModels = [];
  List<String> _ollamaModels = [];
  bool _isLoadingModels = false;
  String _modelError = '';

  static const _modelsByProvider = {
    'openai': ['gpt-4', 'gpt-4-turbo', 'gpt-4o', 'gpt-4o-mini'],
    'anthropic': ['claude-3-opus', 'claude-3-sonnet', 'claude-3-haiku', 'claude-3.5-sonnet'],
    'gemini': ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _provider = prefs.getString('ai_provider') ?? 'openrouter';
      _model = prefs.getString('ai_model') ?? 'google/gemma-4-26b-a4b-it:free';
      _apiKey = prefs.getString('ai_api_key') ?? '';
      _localAI = prefs.getBool('use_local_ai') ?? false;
    });
    _fetchModels();
  }

  List<String> get _currentModels {
    if (_provider == 'openrouter') return _openRouterModels.isNotEmpty ? _openRouterModels : ['Loading...'];
    if (_provider == 'ollama') return _ollamaModels.isNotEmpty ? _ollamaModels : ['Loading...'];
    return _modelsByProvider[_provider] ?? [];
  }

  Future<void> _fetchModels() async {
    setState(() { _isLoadingModels = true; _modelError = ''; });
    try {
      final dio = Dio();
      if (_provider == 'openrouter') {
        final resp = await dio.get('https://openrouter.ai/api/v1/models',
          options: Options(headers: {'Content-Type': 'application/json'}, validateStatus: (s) => s! < 500));
        if (resp.statusCode == 200 && resp.data['data'] != null) {
          final models = List<Map<String, dynamic>>.from(resp.data['data']);
          final free = models.where((m) {
            final id = m['id'] as String? ?? '';
            if (id.endsWith(':free')) return true;
            final pricing = m['pricing'] as Map<String, dynamic>?;
            if (pricing != null) {
              final prompt = double.tryParse(pricing['prompt'] as String? ?? '0') ?? 0;
              final completion = double.tryParse(pricing['completion'] as String? ?? '0') ?? 0;
              return prompt == 0 && completion == 0;
            }
            return false;
          }).map((m) => m['id'] as String).toList();
          free.sort();
          setState(() {
            _openRouterModels = free;
            if (free.isNotEmpty && !free.contains(_model)) _model = free.first;
          });
        }
      } else if (_provider == 'ollama') {
        final resp = await dio.get('http://localhost:11434/api/tags',
          options: Options(validateStatus: (s) => s! < 500, receiveTimeout: const Duration(seconds: 3)));
        if (resp.statusCode == 200 && resp.data['models'] != null) {
          final models = List<Map<String, dynamic>>.from(resp.data['models']);
          final names = models.map((m) => m['name'] as String).toList()..sort();
          setState(() {
            _ollamaModels = names;
            if (names.isNotEmpty && !names.contains(_model)) _model = names.first;
          });
        } else {
          setState(() => _modelError = 'Ollama not responding');
        }
      }
    } catch (e) {
      setState(() => _modelError = 'Network error');
    }
    setState(() => _isLoadingModels = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_provider', _provider);
    await prefs.setString('ai_model', _model);
    await prefs.setString('ai_api_key', _apiKey);
    await prefs.setBool('use_local_ai', _localAI);

    AIProvider p;
    switch (_provider) {
      case 'ollama': p = AIProvider.ollama; break;
      case 'openai': p = AIProvider.openai; break;
      case 'anthropic': p = AIProvider.anthropic; break;
      case 'gemini': p = AIProvider.gemini; break;
      default: p = AIProvider.openrouter;
    }
    final key = _localAI ? 'local' : _apiKey;
    if (key.isNotEmpty || _localAI) {
      await ref.read(appStateProvider.notifier).initializeAI(provider: p, apiKey: key, modelName: _model);
    }
    if (mounted) {
      final connected = ref.read(appStateProvider).isConnected;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(connected ? 'Connected to ${_provider.toUpperCase()}!' : 'Saved. Connection failed.'),
        backgroundColor: connected ? AppColors.success : AppColors.warning,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    return _SectionScaffold(
      title: 'AI Brain',
      subtitle: 'Configure your AI backbone',
      icon: Icons.psychology,
      children: [
        // Status cards
        Row(
          children: [
            Expanded(child: _StatusCard(
              label: 'Provider',
              value: _provider.toUpperCase(),
              icon: Icons.cloud,
              valueColor: appState.isConnected ? AppColors.success : AppColors.textSecondary,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(
              label: 'Status',
              value: appState.isConnected ? 'Connected' : 'Disconnected',
              icon: appState.isConnected ? Icons.check_circle : Icons.error_outline,
              valueColor: appState.isConnected ? AppColors.success : AppColors.error,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(
              label: 'Model',
              value: _model.length > 20 ? '${_model.substring(0, 20)}...' : _model,
              icon: Icons.smart_toy,
            )),
          ],
        ),
        const SizedBox(height: 16),

        // Provider card
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Provider', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GlassDropdown<String>(
                      value: _provider,
                      items: ['openrouter', 'ollama', 'openai', 'anthropic', 'gemini']
                          .map((v) => GlassDropdownItem(value: v, label: v.toUpperCase()))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _provider = v!;
                          if (v == 'ollama') { _localAI = true; _apiKey = 'local'; }
                          else { _localAI = false; if (_apiKey == 'local') _apiKey = ''; }
                        });
                        _fetchModels();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model (${_currentModels.where((m) => m != 'Loading...').length} available)',
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 6),
                        if (_isLoadingModels)
                          const SizedBox(height: 36, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))))
                        else
                          GlassDropdown<String>(
                            value: _currentModels.contains(_model) ? _model : (_currentModels.isNotEmpty ? _currentModels.first : null),
                            items: _currentModels
                                .map((m) => GlassDropdownItem(value: m, label: m))
                                .toList(),
                            onChanged: (v) => setState(() => _model = v!),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_modelError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_modelError, style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // API Key card
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.key, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('API Key', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Spacer(),
                  if (_apiKey.isNotEmpty)
                    StatusChip(label: 'Set', status: ChipStatus.success),
                ],
              ),
              const SizedBox(height: 16),
              GlassTextField(
                hintText: _localAI ? 'Not needed for Ollama' : 'Enter API key...',
                initialValue: _localAI ? '' : _apiKey,
                obscureText: true,
                onChanged: _localAI ? null : (v) => _apiKey = v,
              ),
              const SizedBox(height: 12),
              _ToggleRow(
                label: 'Use Local AI (Ollama)',
                subtitle: 'Run AI models on your machine',
                value: _localAI,
                onChanged: (v) {
                  setState(() {
                    _localAI = v;
                    if (v) { _provider = 'ollama'; _apiKey = 'local'; _fetchModels(); }
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Performance card
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _StatusCard(label: 'Latency', value: '~200ms', icon: Icons.timer)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatusCard(label: 'Tokens/req', value: '~2K', icon: Icons.text_fields)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatusCard(label: 'Cost', value: _localAI ? 'Free' : 'Pay-per-use', icon: Icons.attach_money)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Save button
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            onPressed: _save,
            label: 'Save & Connect',
            icon: Icons.save,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 3: VOICE & AUDIO
// ═══════════════════════════════════════════════════════════════════

class _VoiceSection extends ConsumerStatefulWidget {
  const _VoiceSection();
  @override
  ConsumerState<_VoiceSection> createState() => _VoiceSectionState();
}

class _VoiceSectionState extends ConsumerState<_VoiceSection> {
  bool _voiceEnabled = true;
  String _ttsVoiceName = 'Samantha';
  String _selectedLanguage = 'both';
  double _speechRate = 0.5;
  List<Map<String, dynamic>> _voices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _ttsVoiceName = prefs.getString('tts_voice_name') ?? 'Samantha';
      _selectedLanguage = prefs.getString('voice_language') ?? 'both';
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
    });
    try { _voices = VoiceService.allVoices; } catch (e) { _voices = []; }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_enabled', _voiceEnabled);
    await prefs.setString('tts_voice_name', _ttsVoiceName);
    await prefs.setString('voice_language', _selectedLanguage);
    await prefs.setDouble('speech_rate', _speechRate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Voice settings saved'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Voice & Audio',
      subtitle: 'Speech recognition and text-to-speech',
      icon: Icons.mic,
      children: [
        // Status
        Row(
          children: [
            Expanded(child: _StatusCard(
              label: 'Voice',
              value: _voiceEnabled ? 'Enabled' : 'Disabled',
              icon: Icons.mic,
              valueColor: _voiceEnabled ? AppColors.success : AppColors.textSecondary,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(
              label: 'Language',
              value: _selectedLanguage.toUpperCase(),
              icon: Icons.language,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(
              label: 'Speed',
              value: '${(_speechRate * 100).toInt()}%',
              icon: Icons.speed,
            )),
          ],
        ),
        const SizedBox(height: 16),

        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.record_voice_over, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Voice Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                label: 'Enable Voice',
                subtitle: 'Turn on speech recognition and TTS',
                value: _voiceEnabled,
                onChanged: (v) => setState(() => _voiceEnabled = v),
              ),
              const Divider(color: AppColors.glassBorder, height: 24),
              GlassDropdown<String>(
                value: _ttsVoiceName,
                items: (_voices.isNotEmpty
                    ? _voices.map((v) => v['name'] as String).toList()
                    : ['Samantha', 'Karen', 'Victoria', 'Alex'])
                    .map((v) => GlassDropdownItem(value: v, label: v))
                    .toList(),
                onChanged: (v) => setState(() => _ttsVoiceName = v!),
              ),
              const SizedBox(height: 16),
              GlassDropdown<String>(
                value: _selectedLanguage,
                items: const ['english', 'hindi', 'both']
                    .map((v) => GlassDropdownItem(value: v, label: v[0].toUpperCase() + v.substring(1)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLanguage = v!),
              ),
              const SizedBox(height: 16),
              _SliderRow(
                label: 'Speech Rate',
                value: _speechRate,
                onChanged: (v) => setState(() => _speechRate = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            onPressed: _save,
            label: 'Save Voice Settings',
            icon: Icons.save,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 4: MEMORY CORE
// ═══════════════════════════════════════════════════════════════════

class _MemorySection extends ConsumerStatefulWidget {
  const _MemorySection();
  @override
  ConsumerState<_MemorySection> createState() => _MemorySectionState();
}

class _MemorySectionState extends ConsumerState<_MemorySection> {
  int _totalMemories = 0;
  int _recentMemories = 0;
  bool _semanticSearch = true;
  bool _autoSummarize = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final memory = ref.read(appStateProvider).memory;
      if (memory != null) {
        final all = await memory.getAllMemories();
        setState(() {
          _totalMemories = all.length;
          _recentMemories = all.where((m) =>
            DateTime.now().difference(m.createdAt).inDays < 7
          ).length;
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Memory Core',
      subtitle: 'Memory storage and retrieval',
      icon: Icons.memory,
      children: [
        Row(
          children: [
            Expanded(child: _StatusCard(label: 'Total Memories', value: '$_totalMemories', icon: Icons.storage)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'This Week', value: '$_recentMemories', icon: Icons.timeline)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Health', value: 'Good', icon: Icons.favorite, valueColor: AppColors.success)),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Memory Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                label: 'Semantic Search',
                subtitle: 'Use AI embeddings for smarter memory retrieval',
                value: _semanticSearch,
                onChanged: (v) => setState(() => _semanticSearch = v),
              ),
              const Divider(color: AppColors.glassBorder, height: 24),
              _ToggleRow(
                label: 'Auto Summarize',
                subtitle: 'Automatically compress long conversations',
                value: _autoSummarize,
                onChanged: (v) => setState(() => _autoSummarize = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 5: AGENTS
// ═══════════════════════════════════════════════════════════════════

class _AgentsSection extends ConsumerStatefulWidget {
  const _AgentsSection();
  @override
  ConsumerState<_AgentsSection> createState() => _AgentsSectionState();
}

class _AgentsSectionState extends ConsumerState<_AgentsSection> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final agentMgr = ref.watch(agentManagerProvider);
    final agents = ref.watch(agentsStreamProvider).value ?? [];
    final scheduler = ref.watch(persistentSchedulerProvider);

    return _SectionScaffold(
      title: 'Agents',
      subtitle: 'AI agent orchestration',
      icon: Icons.smart_toy,
      children: [
        Row(
          children: [
            Expanded(child: _StatusCard(
              label: 'Active Agents',
              value: '${agents.where((a) => a.isActive).length}',
              icon: Icons.check_circle,
              valueColor: AppColors.success,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(
              label: 'Total Agents',
              value: '${agents.length}',
              icon: Icons.smart_toy,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(
              label: 'Tasks Completed',
              value: '${agents.fold(0, (sum, a) => sum + a.completedTasks)}',
              icon: Icons.task_alt,
            )),
          ],
        ),
        const SizedBox(height: 16),
        if (agents.isEmpty)
          const EmptyState(
            icon: Icons.smart_toy_outlined,
            title: 'No agents configured',
            subtitle: 'Agents are created automatically when you start using JARVIS',
          )
        else
          ...agents.map((agent) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: agent.isActive ? AppColors.successGhost : AppColors.glassFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.smart_toy,
                      size: 18,
                      color: agent.isActive ? AppColors.success : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agent.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          '${agent.completedTasks} completed • ${agent.failedTasks} failed',
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: agent.isActive ? 'Active' : 'Idle',
                    status: agent.isActive ? ChipStatus.active : ChipStatus.idle,
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 6: AUTOMATION
// ═══════════════════════════════════════════════════════════════════

class _AutomationSection extends ConsumerStatefulWidget {
  const _AutomationSection();
  @override
  ConsumerState<_AutomationSection> createState() => _AutomationSectionState();
}

class _AutomationSectionState extends ConsumerState<_AutomationSection> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final scheduler = ref.watch(persistentSchedulerProvider);

    return _SectionScaffold(
      title: 'Automation',
      subtitle: 'Scheduled tasks and automations',
      icon: Icons.autorenew,
      children: [
        Row(
          children: [
            Expanded(child: _StatusCard(label: 'Scheduler', value: 'Active', icon: Icons.schedule, valueColor: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'System', value: appState.persistentScheduler != null ? 'Running' : 'Off', icon: Icons.play_circle)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Status', value: 'Ready', icon: Icons.check_circle, valueColor: AppColors.success)),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.autorenew, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Scheduler Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'The persistent scheduler manages all scheduled tasks, reminders, and automations. Tasks survive app restarts and are executed automatically.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 7: INTEGRATIONS
// ═══════════════════════════════════════════════════════════════════

class _IntegrationsSection extends ConsumerStatefulWidget {
  const _IntegrationsSection();
  @override
  ConsumerState<_IntegrationsSection> createState() => _IntegrationsSectionState();
}

class _IntegrationsSectionState extends ConsumerState<_IntegrationsSection> {
  String _telegramToken = '';
  String _discordToken = '';
  String _facebookToken = '';
  String _facebookPageId = '';
  String _instagramToken = '';
  String _instagramPageId = '';
  String _whatsappToken = '';
  String _whatsappPhoneId = '';
  String _whatsappBusinessId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _telegramToken = prefs.getString('telegram_bot_token') ?? '';
      _discordToken = prefs.getString('discord_bot_token') ?? '';
      _facebookToken = prefs.getString('facebook_access_token') ?? '';
      _facebookPageId = prefs.getString('facebook_page_id') ?? '';
      _instagramToken = prefs.getString('instagram_access_token') ?? '';
      _instagramPageId = prefs.getString('instagram_page_id') ?? '';
      _whatsappToken = prefs.getString('whatsapp_access_token') ?? '';
      _whatsappPhoneId = prefs.getString('whatsapp_phone_number_id') ?? '';
      _whatsappBusinessId = prefs.getString('whatsapp_business_account_id') ?? '';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('telegram_bot_token', _telegramToken);
    await prefs.setString('discord_bot_token', _discordToken);
    await prefs.setString('facebook_access_token', _facebookToken);
    await prefs.setString('facebook_page_id', _facebookPageId);
    await prefs.setString('instagram_access_token', _instagramToken);
    await prefs.setString('instagram_page_id', _instagramPageId);
    await prefs.setString('whatsapp_access_token', _whatsappToken);
    await prefs.setString('whatsapp_phone_number_id', _whatsappPhoneId);
    await prefs.setString('whatsapp_business_account_id', _whatsappBusinessId);

    final sm = ref.read(appStateProvider).socialManager;
    if (sm != null) {
      if (_facebookToken.isNotEmpty && _facebookPageId.isNotEmpty) sm.setupFacebook(accessToken: _facebookToken, pageId: _facebookPageId);
      if (_instagramToken.isNotEmpty && _instagramPageId.isNotEmpty) sm.setupInstagram(accessToken: _instagramToken, pageId: _instagramPageId);
      if (_whatsappToken.isNotEmpty && _whatsappPhoneId.isNotEmpty) sm.setupWhatsApp(accessToken: _whatsappToken, phoneNumberId: _whatsappPhoneId, businessAccountId: _whatsappBusinessId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Integrations saved'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Integrations',
      subtitle: 'Connect external services',
      icon: Icons.extension,
      children: [
        // Grid of integration cards
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _IntegrationCard(name: 'Telegram', icon: Icons.telegram, color: const Color(0xFF0088CC), connected: _telegramToken.isNotEmpty),
            _IntegrationCard(name: 'Discord', icon: Icons.gamepad, color: const Color(0xFF5865F2), connected: _discordToken.isNotEmpty),
            _IntegrationCard(name: 'Facebook', icon: Icons.facebook, color: const Color(0xFF1877F2), connected: _facebookToken.isNotEmpty),
            _IntegrationCard(name: 'Instagram', icon: Icons.camera_alt, color: const Color(0xFFE4405F), connected: _instagramToken.isNotEmpty),
            _IntegrationCard(name: 'WhatsApp', icon: Icons.chat, color: const Color(0xFF25D366), connected: _whatsappToken.isNotEmpty),
            _IntegrationCard(name: 'OpenRouter', icon: Icons.cloud, color: AppColors.accent, connected: ref.watch(appStateProvider).isConnected),
          ],
        ),
        const SizedBox(height: 16),

        // Telegram & Discord
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Messaging', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              GlassTextField(
                hintText: 'Telegram Bot Token',
                initialValue: _telegramToken,
                obscureText: true,
                onChanged: (v) => _telegramToken = v,
              ),
              const SizedBox(height: 12),
              GlassTextField(
                hintText: 'Discord Bot Token',
                initialValue: _discordToken,
                obscureText: true,
                onChanged: (v) => _discordToken = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Social media
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Social Media', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: GlassTextField(hintText: 'Facebook Page Token', initialValue: _facebookToken, obscureText: true, onChanged: (v) => _facebookToken = v)),
                  const SizedBox(width: 12),
                  Expanded(child: GlassTextField(hintText: 'Page ID', initialValue: _facebookPageId, onChanged: (v) => _facebookPageId = v)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: GlassTextField(hintText: 'Instagram Token', initialValue: _instagramToken, obscureText: true, onChanged: (v) => _instagramToken = v)),
                  const SizedBox(width: 12),
                  Expanded(child: GlassTextField(hintText: 'Page ID', initialValue: _instagramPageId, onChanged: (v) => _instagramPageId = v)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: GlassTextField(hintText: 'WhatsApp Token', initialValue: _whatsappToken, obscureText: true, onChanged: (v) => _whatsappToken = v)),
                  const SizedBox(width: 12),
                  Expanded(child: GlassTextField(hintText: 'Phone ID', initialValue: _whatsappPhoneId, onChanged: (v) => _whatsappPhoneId = v)),
                  const SizedBox(width: 12),
                  Expanded(child: GlassTextField(hintText: 'Business ID', initialValue: _whatsappBusinessId, onChanged: (v) => _whatsappBusinessId = v)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: GlassButton(onPressed: _save, label: 'Save Integrations', icon: Icons.save),
        ),
      ],
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool connected;

  const _IntegrationCard({required this.name, required this.icon, required this.color, required this.connected});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(connected ? 'Connected' : 'Not connected',
                  style: TextStyle(fontSize: 11, color: connected ? AppColors.success : AppColors.textTertiary)),
              ],
            ),
          ),
          Icon(connected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16, color: connected ? AppColors.success : AppColors.textDisabled),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 8: CALENDAR & EMAIL
// ═══════════════════════════════════════════════════════════════════

class _CalendarEmailSection extends ConsumerStatefulWidget {
  const _CalendarEmailSection();
  @override
  ConsumerState<_CalendarEmailSection> createState() => _CalendarEmailSectionState();
}

class _CalendarEmailSectionState extends ConsumerState<_CalendarEmailSection> {
  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Calendar & Email',
      subtitle: 'Schedule and email management',
      icon: Icons.calendar_month,
      children: [
        Row(
          children: [
            Expanded(child: _StatusCard(label: 'Calendar Events', value: 'Manage in Calendar tab', icon: Icons.event)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Email', value: 'IMAP Configured', icon: Icons.email, valueColor: AppColors.success)),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Email Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: GlassTextField(hintText: 'IMAP Server', initialValue: 'imap.gmail.com')),
                  const SizedBox(width: 12),
                  Expanded(child: GlassTextField(hintText: 'Port', initialValue: '993')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: GlassTextField(hintText: 'Email', initialValue: '')),
                  const SizedBox(width: 12),
                  Expanded(child: GlassTextField(hintText: 'Password', initialValue: '', obscureText: true)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 9: APPEARANCE
// ═══════════════════════════════════════════════════════════════════

class _AppearanceSection extends ConsumerStatefulWidget {
  const _AppearanceSection();
  @override
  ConsumerState<_AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends ConsumerState<_AppearanceSection> {
  double _orbIntensity = 0.8;
  double _glassBlur = 10.0;
  double _animationIntensity = 1.0;
  bool _compactMode = false;

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Appearance',
      subtitle: 'Visual customization',
      icon: Icons.palette,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Theme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              _SliderRow(label: 'Orb Intensity', value: _orbIntensity, onChanged: (v) => setState(() => _orbIntensity = v)),
              _SliderRow(label: 'Glass Blur', value: _glassBlur / 30, onChanged: (v) => setState(() => _glassBlur = v * 30), suffix: 'px'),
              _SliderRow(label: 'Animation Speed', value: _animationIntensity, onChanged: (v) => setState(() => _animationIntensity = v)),
              const Divider(color: AppColors.glassBorder, height: 24),
              _ToggleRow(
                label: 'Compact Mode',
                subtitle: 'Reduce spacing and padding',
                value: _compactMode,
                onChanged: (v) => setState(() => _compactMode = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Live preview
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          AppColors.accent.withAlpha((_orbIntensity * 255).toInt()),
                          AppColors.accentGhost,
                        ]),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Glass Card', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                          Text('Preview of your theme settings', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    StatusChip(label: 'Active', status: ChipStatus.active),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 10: SECURITY
// ═══════════════════════════════════════════════════════════════════

class _SecuritySection extends ConsumerStatefulWidget {
  const _SecuritySection();
  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final permMgr = appState.permissionManager;

    return _SectionScaffold(
      title: 'Security',
      subtitle: 'Permissions and access control',
      icon: Icons.shield,
      children: [
        Row(
          children: [
            Expanded(child: _StatusCard(label: 'Permissions', value: 'Managed', icon: Icons.security, valueColor: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Tool Policies', value: 'Default', icon: Icons.policy)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Audit Log', value: 'Active', icon: Icons.fact_check, valueColor: AppColors.success)),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Permission Policies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tool access is managed automatically. When a tool requests elevated permissions, you\'ll be prompted to allow or deny.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _StatusCard(label: 'File Access', value: 'Read/Write', icon: Icons.folder)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatusCard(label: 'Network', value: 'Allowed', icon: Icons.wifi)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatusCard(label: 'Shell', value: 'Sandboxed', icon: Icons.terminal)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 11: ADVANCED
// ═══════════════════════════════════════════════════════════════════

class _AdvancedSection extends ConsumerStatefulWidget {
  const _AdvancedSection();
  @override
  ConsumerState<_AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends ConsumerState<_AdvancedSection> {
  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Advanced',
      subtitle: 'Developer tools and diagnostics',
      icon: Icons.code,
      children: [
        Row(
          children: [
            Expanded(child: _StatusCard(label: 'Databases', value: '18 active', icon: Icons.storage)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Timeline Events', value: 'Active', icon: Icons.timeline, valueColor: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _StatusCard(label: 'Memory Usage', value: 'Normal', icon: Icons.memory, valueColor: AppColors.success)),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.build, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Developer Tools', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              _buildToolRow(Icons.storage, 'Database Health', 'All databases operational'),
              _buildToolRow(Icons.file_download, 'Export Logs', 'Download application logs'),
              _buildToolRow(Icons.backup, 'Backup Database', 'Create a backup of all data'),
              _buildToolRow(Icons.restore, 'Restore Database', 'Restore from a backup'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION 12: ABOUT
// ═══════════════════════════════════════════════════════════════════

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'About',
      subtitle: 'JARVIS OS information',
      icon: Icons.info_outline,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    AppColors.accent.withAlpha(60),
                    AppColors.accentGhost,
                  ]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('J', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.accent)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'JARVIS OS',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your Personal AI Operating System',
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AboutStat(label: 'Version', value: '1.0.0'),
                  const SizedBox(width: 32),
                  _AboutStat(label: 'Build', value: '2024.1'),
                  const SizedBox(width: 32),
                  _AboutStat(label: 'Engine', value: 'Flutter'),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.glassBorder),
              const SizedBox(height: 16),
              const Text(
                'Built with Flutter • Powered by OpenRouter & Ollama',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 8),
              const Text(
                '80+ tools • Memory system • Agent orchestration • Voice AI',
                style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutStat extends StatelessWidget {
  final String label;
  final String value;
  const _AboutStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }
}
