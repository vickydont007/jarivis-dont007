import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'widgets/sidebar/floating_sidebar.dart';
import 'widgets/command/command_palette.dart';
import 'screens/assistant_screen.dart';
import 'screens/memory_screen.dart';
import 'screens/agents_screen.dart';
import 'screens/automation_screen.dart';
import 'screens/agent_playground_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/developer_screen.dart';
import 'screens/runtime_validation_screen.dart';

final themeProvider = StateProvider<bool>((ref) => true);

class JarvisApp extends ConsumerWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'JARVIS OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const JarvisShell(),
    );
  }
}

class JarvisShell extends ConsumerStatefulWidget {
  const JarvisShell({super.key});

  @override
  ConsumerState<JarvisShell> createState() => _JarvisShellState();
}

class _JarvisShellState extends ConsumerState<JarvisShell> {
  int _selectedIndex = 0;
  bool _isCommandPaletteOpen = false;
  bool _isSidebarExpanded = false;

  final List<Widget> _screens = [
    const AssistantScreen(),
    const MemoryScreen(),
    const AgentsScreen(),
    const AutomationScreen(),
    const AgentPlaygroundScreen(),
    const SettingsScreen(),
  ];

  final List<Widget> _developerScreens = [
    const DeveloperScreen(),
    const RuntimeValidationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupKeyboardShortcuts();
  }

  void _setupKeyboardShortcuts() {
    HardwareKeyboard.instance.addHandler((event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

      final isCmd = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaRight);

      if (isCmd) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyK:
            setState(() => _isCommandPaletteOpen = !_isCommandPaletteOpen);
            return true;
          case LogicalKeyboardKey.digit1:
            _navigateTo(0);
            return true;
          case LogicalKeyboardKey.digit2:
            _navigateTo(1);
            return true;
          case LogicalKeyboardKey.digit3:
            _navigateTo(2);
            return true;
          case LogicalKeyboardKey.digit4:
            _navigateTo(3);
            return true;
          case LogicalKeyboardKey.digit5:
            _navigateTo(4);
            return true;
          case LogicalKeyboardKey.digit6:
            _navigateTo(5);
            return true;
          case LogicalKeyboardKey.digit7:
            _navigateTo(6);
            return true;
          case LogicalKeyboardKey.digit8:
            _navigateTo(7);
            return true;
        }
      }
      return false;
    });
  }

  void _navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
      _isCommandPaletteOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDevScreen = _selectedIndex >= 6;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content
          Row(
            children: [
              // Floating sidebar
              Padding(
                padding: const EdgeInsets.all(16),
                child: FloatingSidebar(
                  selectedIndex: _selectedIndex,
                  onIndexChanged: _navigateTo,
                  isExpanded: _isSidebarExpanded,
                ),
              ),
              // Screen content
              Expanded(
                child: isDevScreen
                    ? _developerScreens[_selectedIndex - 6]
                    : _screens[_selectedIndex],
              ),
            ],
          ),

          // Command palette overlay
          CommandPalette(
            isOpen: _isCommandPaletteOpen,
            onClose: () => setState(() => _isCommandPaletteOpen = false),
            onCommand: _handleCommand,
          ),
        ],
      ),
    );
  }

  void _handleCommand(String command) {
    switch (command) {
      case 'Assistant':
        _navigateTo(0);
        break;
      case 'Memory':
        _navigateTo(1);
        break;
      case 'Agents':
        _navigateTo(2);
        break;
      case 'Automations':
        _navigateTo(3);
        break;
      case 'Playground':
        _navigateTo(4);
        break;
      case 'Settings':
        _navigateTo(5);
        break;
    }
  }
}

// Keep old name for backward compatibility
typedef NextronApp = JarvisApp;
typedef MainScreen = JarvisShell;
