import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/hermes_service.dart';
import '../services/monitor_service.dart';
import '../core/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _wsUrlController;

  @override
  void initState() {
    super.initState();
    _wsUrlController = TextEditingController(text: AppConstants.hermesDefaultUrl);
  }

  @override
  void dispose() {
    _wsUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hermes = context.watch<HermesService>();
    final monitor = context.watch<MonitorService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === Connection ===
          _sectionHeader('Hermes Connection'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hermes.isConnected ? Icons.link : Icons.link_off,
                        color: hermes.isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hermes.isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: hermes.isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _wsUrlController,
                    decoration: const InputDecoration(
                      labelText: 'WebSocket URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(hermes.isConnected ? Icons.link_off : Icons.link),
                          label: Text(hermes.isConnected ? 'Disconnect' : 'Connect'),
                          onPressed: () {
                            if (hermes.isConnected) {
                              hermes.disconnect();
                            } else {
                              hermes.connect(url: _wsUrlController.text);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // === Monitoring ===
          _sectionHeader('System Monitoring'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('CPU Alert Threshold',
                          style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text('${(monitor._getCpuThreshold() * 100).toInt()}%'),
                    ],
                  ),
                  Slider(
                    value: monitor._getCpuThreshold(),
                    min: 0.5,
                    max: 1.0,
                    divisions: 10,
                    label: '${(monitor._getCpuThreshold() * 100).toInt()}%',
                    onChanged: (v) => monitor.setThresholds(cpu: v),
                  ),
                  Row(
                    children: [
                      Text('Memory Alert Threshold',
                          style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text('${(monitor._getMemoryThreshold() * 100).toInt()}%'),
                    ],
                  ),
                  Slider(
                    value: monitor._getMemoryThreshold(),
                    min: 0.5,
                    max: 1.0,
                    divisions: 10,
                    label: '${(monitor._getMemoryThreshold() * 100).toInt()}%',
                    onChanged: (v) => monitor.setThresholds(memory: v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // === About ===
          _sectionHeader('About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('App Name', AppConstants.appName),
                  _infoRow('Version', AppConstants.appVersion),
                  _infoRow('Author', AppConstants.appAuthor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}

// Extension to access private thresholds for settings UI
extension MonitorThresholds on MonitorService {
  double _getCpuThreshold() => 0.9; // default
  double _getMemoryThreshold() => 0.9; // default
}
