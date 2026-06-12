import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/memory_system.dart';
import '../providers/app_provider.dart';

class MemoryViewerScreen extends ConsumerStatefulWidget {
  const MemoryViewerScreen({super.key});

  @override
  ConsumerState<MemoryViewerScreen> createState() => _MemoryViewerScreenState();
}

class _MemoryViewerScreenState extends ConsumerState<MemoryViewerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MemoryEntry> _memories = [];
  List<MemoryEntry> _filteredMemories = [];
  String _selectedCategory = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  void _loadMemories() async {
    setState(() => _isLoading = true);
    final appState = ref.read(appStateProvider);
    if (appState.memory != null) {
      _memories = await appState.memory!.getAllMemories();
      _filteredMemories = List.from(_memories);
    }
    setState(() => _isLoading = false);
  }

  void _searchMemories(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMemories = List.from(_memories);
      } else {
        _filteredMemories = _memories
            .where((m) => m.content.toLowerCase().contains(query.toLowerCase()))
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
            .where((m) => m.category == category)
            .toList();
      }
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'chat':
        return Colors.blue;
      case 'preference':
        return Colors.purple;
      case 'event':
        return Colors.orange;
      case 'context':
        return Colors.green;
      case 'credential':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'chat':
        return Icons.chat;
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
    final categories = ['all', ..._memories.map((m) => m.category).toSet().toList()];

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
            icon: const Icon(Icons.refresh),
            onPressed: _loadMemories,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Column(
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
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          selectedColor: _getCategoryColor(category),
                          backgroundColor: const Color(0xFF21262D),
                          onSelected: (selected) {
                            _filterByCategory(category);
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.memory, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '${_filteredMemories.length} memories',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        'Total: ${_memories.length}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Memories List
                Expanded(
                  child: _filteredMemories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.memory, size: 64, color: Colors.grey[800]),
                              const SizedBox(height: 16),
                              Text(
                                _memories.isEmpty ? 'No memories yet' : 'No matching memories',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _memories.isEmpty
                                    ? 'Start chatting to build memories'
                                    : 'Try a different search term',
                                style: TextStyle(color: Colors.grey[800], fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredMemories.length,
                          itemBuilder: (context, index) {
                            return _buildMemoryCard(_filteredMemories[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMemoryCard(MemoryEntry memory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCategoryColor(memory.category).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(memory.category),
              color: _getCategoryColor(memory.category),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(memory.category).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        memory.category,
                        style: TextStyle(
                          color: _getCategoryColor(memory.category),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(memory.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 18),
            onPressed: () => _deleteMemory(memory),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  void _deleteMemory(MemoryEntry memory) async {
    final appState = ref.read(appStateProvider);
    if (appState.memory != null) {
      await appState.memory!.deleteMemory(memory.id);
      _loadMemories();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
