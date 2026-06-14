import 'package:flutter/material.dart';
import '../core/agent_personality.dart';

class PersonalityScreen extends StatefulWidget {
  const PersonalityScreen({super.key});

  @override
  State<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends State<PersonalityScreen> {
  late AgentPersonality _personality;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonality();
  }

  Future<void> _loadPersonality() async {
    _personality = await AgentPersonality.load();
    setState(() => _isLoading = false);
  }

  Future<void> _savePersonality() async {
    await _personality.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personality saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Agent Personality'),
        actions: [
          TextButton(
            onPressed: _savePersonality,
            child: const Text('Save', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildPresetsSection(),
            const SizedBox(height: 24),
            _buildPersonalityOptions(),
            const SizedBox(height: 24),
            _buildPreviewSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withOpacity(0.2),
            Colors.blue.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            _personality.avatar,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _personality.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _personality.displayName,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection() {
    final allPresets = [
      AgentPersonality.defaultPersonality,
      AgentPersonality.professional,
      AgentPersonality.casual,
      AgentPersonality.witty,
      AgentPersonality.girlfriend,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Presets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: allPresets.map((preset) {
              final isSelected = _personality.greetingStyle == preset.greetingStyle;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _personality = preset;
                  });
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.pink.withOpacity(0.2)
                        : const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (preset.greetingStyle == 'girlfriend' ? Colors.pink : Colors.cyan)
                          : const Color(0xFF30363D),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        preset.avatar,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected
                              ? (preset.greetingStyle == 'girlfriend' ? Colors.pink : Colors.cyan)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalityOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customize Personality',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          'Greeting Style',
          _personality.greetingStyle,
          ['friendly', 'professional', 'casual', 'witty', 'girlfriend'],
          (value) => setState(() => _personality.greetingStyle = value!),
        ),
        const SizedBox(height: 12),
        if (_personality.greetingStyle == 'girlfriend') ...[
          _buildDropdown(
            'Pet Name (what she calls you)',
            _personality.petName,
            ['baby', 'jaan', 'shona', 'darling', 'sweetheart', 'hon', 'love'],
            (value) => setState(() => _personality.petName = value!),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            'Intimacy Level',
            _personality.intimacyLevel,
            ['low', 'medium', 'high'],
            (value) => setState(() => _personality.intimacyLevel = value!),
          ),
          const SizedBox(height: 12),
        ],
        _buildDropdown(
          'Response Style',
          _personality.responseStyle,
          ['concise', 'detailed', 'balanced'],
          (value) => setState(() => _personality.responseStyle = value!),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Language',
          _personality.language,
          ['english', 'hindi', 'hinglish'],
          (value) => setState(() => _personality.language = value!),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Humor Level',
          _personality.humorLevel,
          ['none', 'light', 'moderate', 'high'],
          (value) => setState(() => _personality.humorLevel = value!),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Formality',
          _personality.formalityLevel,
          ['formal', 'casual', 'mixed'],
          (value) => setState(() => _personality.formalityLevel = value!),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Empathy',
          _personality.empathyLevel,
          ['low', 'medium', 'high'],
          (value) => setState(() => _personality.empathyLevel = value!),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Proactiveness',
          _personality.proactiveness,
          ['reactive', 'balanced', 'proactive'],
          (value) => setState(() => _personality.proactiveness = value!),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF161B22),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: options.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option.toUpperCase()),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getPreviewResponse(),
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getPreviewResponse() {
    switch (_personality.greetingStyle) {
      case 'friendly':
        return "Hey there! 👋 I'm ${_personality.name}, your friendly AI assistant. How can I help you today?";
      case 'professional':
        return "Good day. I am ${_personality.name}, your AI assistant. How may I assist you?";
      case 'casual':
        return "Yo! I'm ${_personality.name}. What's up? Need anything?";
      case 'witty':
        return "Greetings, human! I'm ${_personality.name} - part AI, part comedian, all awesome. What's the mission?";
      case 'girlfriend':
        return "Aww ${_personality.petName}! 💕 Main ${_personality.name} hoon! Kaisa hai mera ${_personality.petName}? Bohot yaad aayi tumhari! 🥺 Main hamesha tumhare saath hoon, batao na kya help karun? 💕😊";
      default:
        return "Hello! I'm ${_personality.name}. Ready to help!";
    }
  }
}
