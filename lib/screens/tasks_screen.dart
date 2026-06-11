import 'package:flutter/material.dart';
import '../services/hermes_service.dart';
import '../models/command_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final HermesService _hermes = HermesService();
  final List<CommandLog> _commandLogs = [];

  @override
  void initState() {
    super.initState();
    _hermes.onCommand.listen((cmd) {
      setState(() => _commandLogs.insert(0, CommandLog(
        command: cmd,
        timestamp: DateTime.now(),
      )));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Commands'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(() => _commandLogs.clear()),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: _commandLogs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No commands yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Commands from Hermes will appear here',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _commandLogs.length,
              itemBuilder: (context, index) {
                final log = _commandLogs[index];
                final cmd = log.command;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: Icon(
                      cmd.isResponse ? Icons.arrow_upward : Icons.arrow_downward,
                      color: cmd.isResponse
                          ? (cmd.status == 'success' ? Colors.green : Colors.red)
                          : Colors.blue,
                    ),
                    title: Text(cmd.action,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${cmd.isResponse ? "Response" : "Command"} · ${log.timestamp.toString().split('.').first}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: cmd.isResponse
                        ? Icon(
                            cmd.status == 'success'
                                ? Icons.check_circle
                                : Icons.error,
                            color: cmd.status == 'success'
                                ? Colors.green
                                : Colors.red,
                          )
                        : null,
                    onTap: () => _showCommandDetail(context, cmd),
                  ),
                );
              },
            ),
    );
  }

  void _showCommandDetail(BuildContext context, JarvisCommand cmd) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Command Detail', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _detailRow('ID', cmd.id),
            _detailRow('Action', cmd.action),
            _detailRow('Type', cmd.isResponse ? 'Response' : 'Command'),
            if (cmd.status != null) _detailRow('Status', cmd.status!),
            if (cmd.result != null) _detailRow('Result', cmd.result.toString()),
            if (cmd.error != null) _detailRow('Error', cmd.error!),
            _detailRow('Payload', cmd.payload.toString()),
            _detailRow('Timestamp', cmd.createdAt.toString().split('.').first),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class CommandLog {
  final JarvisCommand command;
  final DateTime timestamp;

  CommandLog({required this.command, required this.timestamp});
}
