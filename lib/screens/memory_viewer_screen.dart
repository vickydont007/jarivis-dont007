import 'package:flutter/material.dart';

class MemoryViewerScreen extends StatefulWidget {
  const MemoryViewerScreen({super.key});

  @override
  State<MemoryViewerScreen> createState() => _MemoryViewerScreenState();
}

class _MemoryViewerScreenState extends State<MemoryViewerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _memories = [];
  List<Map<String, dynamic>> _filteredMemories = [];
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  void _loadMemories() {
    // Mock memories data
    _memories = [
      {
        'id': '1',
        'content': 'User prefers dark mode in applications',
        'category': 'preference',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'importance': 'high',
      },
      {
        'id': '2',
        'content': 'Meeting with team at 3 PM tomorrow',
        'category': 'event',
        'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
        'importance': 'medium',
      },
      {
        'id': '3',
        'content': 'User is learning Flutter development',
        'category': 'context',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        'importance': 'low',
      },
      {
        'id': '4',
        'content': 'Password for WiFi: secure123',
        'category': 'credential',
        'timestamp': DateTime.now().subtract(const Duration(days: 3)),
        'importance': 'critical',
      },
      {
        'id': '5',
        'content': 'Project deadline: Next Friday',
        'category': 'event',
        'timestamp': DateTime.now().subtract(const Duration(hours: 12)),
        'importance': 'high',
      },
    ];
    _filteredMemories = List.from(_memories);
  }

  void _searchMemories(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMemories = List.from(_memories);
      } else {
        _filteredMemories = _memories
            .where((m) => m['content'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'all') {
        _filteredMemories = List.from(_memories);
      } else {
        _filteredMemories = _memories
            .where((m) => m['category'] == category)
            .toList();
      }
    });
  }

  Color _getImportanceColor(String importance) {
    switch (importance) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'preference':
        return Icons.favorite;
      case 'event':
        return Icons.event;
      case 'context':
        return Icons.info;
      case 'credential':
        return Icons.lock;
      default:
        return Icons.memory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Memory Viewer',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddMemoryDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              _clearOldMemories();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF161B22),
            child: TextField(
              controller: _searchController,
              onChanged: _searchMemories,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search memories...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
              ),
            ),
          ),

          // Category Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip('all', 'All'),
                _buildCategoryChip('preference', 'Preferences'),
                _buildCategoryChip('event', 'Events'),
                _buildCategoryChip('context', 'Context'),
                _buildCategoryChip('credential', 'Credentials'),
              ],
            ),
          ),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total', _memories.length.toString()),
                _buildStat('Critical', _memories.where((m) => m['importance'] == 'critical').length.toString()),
                _buildStat('High', _memories.where((m) => m['importance'] == 'high').length.toString()),
                _buildStat('Today', _memories.where((m) => m['timestamp'].isAfter(DateTime.now().subtract(const Duration(days: 1)))).length.toString()),
              ],
            ),
          ),

          // Memory List
          Expanded(
            child: _filteredMemories.isEmpty
                ? const Center(
                    child: Text(
                      'No memories found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMemories.length,
                    itemBuilder: (context, index) {
                      final memory = _filteredMemories[index];
                      return _buildMemoryCard(memory);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => _filterByCategory(category),
        selectedColor: const Color(0xFF58A6FF).withOpacity(0.3),
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

  Widget _buildMemoryCard(Map<String, dynamic> memory) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getImportanceColor(memory['importance']).withOpacity(0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getImportanceColor(memory['importance']).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(memory['category']),
            color: _getImportanceColor(memory['importance']),
          ),
        ),
        title: Text(
          memory['content'],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getImportanceColor(memory['importance']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  memory['importance'].toUpperCase(),
                  style: TextStyle(
                    color: _getImportanceColor(memory['importance']),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(memory['timestamp']),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            // TODO: Handle menu actions
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
            const PopupMenuItem(value: 'export', child: Text('Export')),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }

  void _showAddMemoryDialog() {
    final contentController = TextEditingController();
    String selectedCategory = 'general';
    String selectedImportance = 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Add Memory', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: contentController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter memory content...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF30363D)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  items: ['general', 'preference', 'event', 'context', 'credential']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedImportance,
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Importance',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  items: ['low', 'medium', 'high', 'critical']
                      .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedImportance = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (contentController.text.isNotEmpty) {
                  setState(() {
                    _memories.insert(0, {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'content': contentController.text,
                      'category': selectedCategory,
                      'timestamp': DateTime.now(),
                      'importance': selectedImportance,
                    });
                    _filteredMemories = List.from(_memories);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Memory added!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.cyan)),
            ),
          ],
        ),
      ),
    );
  }

  void _clearOldMemories() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    setState(() {
      _memories.removeWhere((m) => m['timestamp'].isBefore(cutoff));
      _filteredMemories = List.from(_memories);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Old memories cleared!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
