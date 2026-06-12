import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/agent_orchestrator.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String _selectedFilter = 'all';
  List<AgentTask> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() => _isLoading = true);
    // Get tasks from agent network's orchestrator
    _sessions = []; // Tasks will be populated as agents execute
    setState(() => _isLoading = false);
  }

  List<AgentTask> get _filteredSessions {
    if (_selectedFilter == 'all') return _sessions;
    return _sessions.where((s) => s.status.name == _selectedFilter).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'running':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'running':
        return Icons.play_circle;
      case 'failed':
        return Icons.error;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Sessions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_sessions.length} sessions',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Chips
            Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('completed', 'Completed'),
                const SizedBox(width: 8),
                _buildFilterChip('running', 'Running'),
                const SizedBox(width: 8),
                _buildFilterChip('failed', 'Failed'),
              ],
            ),
            const SizedBox(height: 24),

            // Sessions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
                  : _filteredSessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.list_alt, size: 64, color: Colors.grey[800]),
                              const SizedBox(height: 16),
                              Text(
                                'No sessions yet',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sessions will appear here when agents execute tasks',
                                style: TextStyle(color: Colors.grey[800], fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredSessions.length,
                          itemBuilder: (context, index) {
                            return _buildSessionCard(_filteredSessions[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontSize: 12,
        ),
      ),
      selectedColor: Colors.cyan,
      backgroundColor: const Color(0xFF21262D),
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildSessionCard(AgentTask session) {
    final statusColor = _getStatusColor(session.status.name);
    final typeIcon = _getTypeIcon(session.status.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: statusColor),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      session.status.name.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(session.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                if (session.result != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    session.result!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
}
