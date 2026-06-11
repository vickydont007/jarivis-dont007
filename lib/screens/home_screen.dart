import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/hermes_service.dart';
import '../services/monitor_service.dart';
import '../services/system_service.dart';
import '../screens/dashboard_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TasksScreen(),
    SettingsScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final hermes = context.watch<HermesService>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}
