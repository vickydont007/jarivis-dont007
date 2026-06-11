import 'package:flutter/material.dart';
import '../core/logger.dart';
import 'dart:async';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final JarvisLogger _logger = JarvisLogger();
  final List<LogEntry> _displayLogs = [];
  StreamSubscription? _subscription;
  LogLevel _filterLevel = LogLevel.debug;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load existing logs
    _displayLogs.addAll(_logger.logs);
    // Listen for new logs
    _subscription = _logger.logStream.listen((entry) {
      if (entry.level.index >= _filterLevel.index) {
        setState(() => _displayLogs.add(entry));
        _autoScroll();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        centerTitle: true,
        actions: [
          // Filter dropdown
          PopupMenuButton<LogLevel>(
            icon: const Icon(Icons.filter_list),
            onSelected: (level) {
              setState(() {
                _filterLevel = level;
                _displayLogs.clear();
                _displayLogs.addAll(_logger.logs
                    .where((l) => l.level.index >= level.index));
              });
            },
            itemBuilder: (context) => LogLevel.values.map((level) {
              return PopupMenuItem(
                value: level,
                child: Row(
                  children: [
                    Icon(
                      _getLevelIcon(level),
                      size: 18,
                      color: _getLevelColor(level),
                    ),
                    const SizedBox(width: 8),
                    Text(level.name.toUpperCase()),
                    if (level == _filterLevel)
                      const Icon(Icons.check, size: 16),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => setState(() => _displayLogs.clear()),
            tooltip: 'Clear display',
          ),
        ],
      ),
      body: _displayLogs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.terminal, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No logs', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Logs will appear as the agent runs',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _displayLogs.length,
              itemBuilder: (context, index) {
                final entry = _displayLogs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      _getLevelIcon(entry.level),
                      size: 18,
                      color: _getLevelColor(entry.level),
                    ),
                    title: Text(
                      entry.message,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: _getLevelColor(entry.level),
                      ),
                    ),
                    subtitle: Text(
                      '${entry.timestamp.toString().split('.').first}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                    trailing: entry.exception != null
                        ? IconButton(
                            icon: const Icon(Icons.error_outline, size: 16),
                            onPressed: () => _showException(context, entry.exception!),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return Icons.bug_report;
      case LogLevel.info: return Icons.info_outline;
      case LogLevel.warning: return Icons.warning_amber;
      case LogLevel.error: return Icons.error_outline;
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return Colors.grey;
      case LogLevel.info: return Colors.blue;
      case LogLevel.warning: return Colors.orange;
      case LogLevel.error: return Colors.red;
    }
  }

  void _showException(BuildContext context, String exception) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exception Details'),
        content: SingleChildScrollView(
          child: SelectableText(exception, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
