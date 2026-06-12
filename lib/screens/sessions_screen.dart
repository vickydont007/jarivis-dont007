import 'package:flutter/material.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final List<Map<String, dynamic>> _sessions = [
    {
      'id': '1',
      'title': 'Morning Briefing',
      'type': 'daily',
      'duration': '15 min',
      'status': 'completed',
      'tasks': ['Weather update', 'Calendar check', 'Email summary'],
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': '2',
      'title': 'Code Review',
      'type': 'on-demand',
      'duration': '45 min',
      'status': 'completed',
      'tasks': ['Review PR #123', 'Suggest improvements', 'Run tests'],
      'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
    },
    {
      'id': '3',
      'title': 'Research Session',
      'type': 'on-demand',
      'duration': '30 min',
      'status': 'in-progress',
      'tasks': ['Search articles', 'Summarize findings', 'Create report'],
      'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
    },
    {
      'id': '4',
      'title': 'Meeting Prep',
      'type': 'scheduled',
      'duration': '20 min',
      'status': 'scheduled',
      'tasks': ['Review agenda', 'Prepare notes', 'Set reminders'],
      'timestamp': DateTime.now().add(const Duration(hours: 1)),
    },
  ];

  String _selectedFilter = 'all';

  List<Map<String, dynamic>> get _filteredSessions {
    if (_selectedFilter == 'all') return _sessions;
    return _sessions.where((s) => s['status'] == _selectedFilter).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in-progress':
        return Colors.blue;
      case 'scheduled':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'daily':
        return Icons.today;
      case 'scheduled':
        return Icons.schedule;
      case 'on-demand':
        return Icons.touch_app;
      default:
        return Icons.list;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Sessions',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _createNewSession();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('all', 'All'),
                _buildFilterChip('completed', 'Completed'),
                _buildFilterChip('in-progress', 'In Progress'),
                _buildFilterChip('scheduled', 'Scheduled'),
              ],
            ),
          ),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', _sessions.length.toString()),
                _buildStat('Completed', _sessions.where((s) => s['status'] == 'completed').length.toString()),
                _buildStat('In Progress', _sessions.where((s) => s['status'] == 'in-progress').length.toString()),
                _buildStat('Scheduled', _sessions.where((s) => s['status'] == 'scheduled').length.toString()),
              ],
            ),
          ),

          // Sessions List
          Expanded(
            child: _filteredSessions.isEmpty
                ? const Center(
                    child: Text(
                      'No sessions found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSessions.length,
                    itemBuilder: (context, index) {
                      final session = _filteredSessions[index];
                      return _buildSessionCard(session);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedFilter = filter),
        selectedColor: const Color(0xFF58A6FF).withValues(alpha: 0.3),
        checkmarkColor: const Color(0xFF58A6FF),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF58A6FF) : Colors.grey,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF58A6FF) : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(session['status']).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeIcon(session['type']),
                    color: _getStatusColor(session['status']),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${session['type']} • ${session['duration']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(session['status']).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    session['status'].toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(session['status']),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tasks
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (session['tasks'] as List<String>).map((task) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _showSessionDetails(session);
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _resumeSession(session);
                  },
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Resume'),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    _handleMenuAction(value, session);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _createNewSession() {
    final titleController = TextEditingController();
    String selectedType = 'on-demand';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Create Session', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Session title...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                 value: selectedType,
                dropdownColor: const Color(0xFF161B22),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Type',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                items: ['on-demand', 'daily', 'scheduled']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    _sessions.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'title': titleController.text,
                      'type': selectedType,
                      'duration': '0 min',
                      'status': 'scheduled',
                      'tasks': ['New task'],
                      'timestamp': DateTime.now(),
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session created!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.cyan)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(session['title'], style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${session['type']}', style: TextStyle(color: Colors.grey[400])),
            Text('Duration: ${session['duration']}', style: TextStyle(color: Colors.grey[400])),
            Text('Status: ${session['status']}', style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 16),
            const Text('Tasks:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ...session['tasks'].map((t) => Text('• $t', style: TextStyle(color: Colors.grey[400]))),
          ],
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

  void _resumeSession(Map<String, dynamic> session) {
    setState(() {
      session['status'] = 'in-progress';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resumed: ${session['title']}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleMenuAction(String action, Map<String, dynamic> session) {
    switch (action) {
      case 'edit':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit coming soon!'), backgroundColor: Colors.orange),
        );
        break;
      case 'duplicate':
        setState(() {
          final duplicate = Map<String, dynamic>.from(session);
          duplicate['id'] = DateTime.now().millisecondsSinceEpoch.toString();
          duplicate['title'] = '${session['title']} (Copy)';
          _sessions.insert(0, duplicate);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session duplicated!'), backgroundColor: Colors.green),
        );
        break;
      case 'delete':
        setState(() {
          _sessions.removeWhere((s) => s['id'] == session['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted!'), backgroundColor: Colors.red),
        );
        break;
    }
  }
}
