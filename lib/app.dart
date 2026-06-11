import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/hermes_service.dart';
import 'core/logger.dart';
import 'screens/home_screen.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});

  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final JarvisLogger _logger = JarvisLogger();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSystemTray());
    windowManager.addListener(this);
    _initWindow();
  }

  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);
  }

  Future<void> _initSystemTray() async {
    try {
      await _systemTray.initSystemTray(
        toolTip: 'Jarvis Desktop Agent',
        iconPath: 'assets/icons/app_icon.png',
      );
      
      await _systemTray.setContextMenu(
        SystemTrayContextMenu(
          items: [
            MenuItemLabel(label: 'Show', onPressed: (_) => _showWindow()),
            MenuItemLabel(label: 'Hide', onPressed: (_) => _hideWindow()),
            const MenuSeparator(),
            MenuItemLabel(label: 'Status: Running', enabled: false),
            const MenuSeparator(),
            MenuItemLabel(label: 'Quit', onPressed: (_) => _quit()),
          ],
        ),
      );

      _systemTray.onSystemTrayClicked = (_) => _showWindow();
      
      _logger.info('System tray initialized');
    } catch (e) {
      _logger.warning('System tray init failed (non-fatal)', exception: e);
    }
  }

  void _showWindow() {
    windowManager.show();
    windowManager.focus();
  }

  void _hideWindow() {
    windowManager.hide();
  }

  Future<void> _quit() async {
    final hermes = context.read<HermesService>();
    hermes.disconnect();
    await windowManager.close();
  }

  @override
  void onWindowClose() async {
    // Minimize to tray instead of closing
    await windowManager.hide();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
