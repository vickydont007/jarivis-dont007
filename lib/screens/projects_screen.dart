import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/core.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/common/status_chip.dart';
import '../widgets/common/error_state.dart';
import '../widgets/common/empty_state.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final List<_ProjectItem> _projects = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('user_projects');
      if (data != null) {
        final list = jsonDecode(data) as List;
        _projects.clear();
        for (final item in list) {
          _projects.add(_ProjectItem(
            name: item['name'],
            path: item['path'] ?? '',
            addedAt: DateTime.parse(item['addedAt']),
            lastActivity: item['lastActivity'] != null
                ? DateTime.parse(item['lastActivity'])
                : null,
            status: item['status'] ?? 'active',
          ));
        }
      }
    } catch (e) {
      _error = 'Failed to load projects: $e';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _projects.map((p) => {
      'name': p.name,
      'path': p.path,
      'addedAt': p.addedAt.toIso8601String(),
      'lastActivity': p.lastActivity?.toIso8601String(),
      'status': p.status,
    }).toList();
    await prefs.setString('user_projects', jsonEncode(data));
  }

  Future<void> _addProject() async {
    final nameController = TextEditingController();
    final pathController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Add Project', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Project name',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                hintText: 'Path (optional)',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      setState(() {
        _projects.insert(0, _ProjectItem(
          name: nameController.text.trim(),
          path: pathController.text.trim(),
          addedAt: DateTime.now(),
          lastActivity: DateTime.now(),
          status: 'active',
        ));
      });
      await _saveProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl, AppSpacing.xxl, AppSpacing.xxxl, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📁 Projects',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Track your work and repositories',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassButton(
                    onPressed: _addProject,
                    label: 'Add Project',
                    icon: Icons.add,
                    isCompact: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            Expanded(
              child: _isLoading
                  ? const LoadingState(message: 'Loading projects...')
                  : _error != null
                      ? ErrorState(
                          message: _error!,
                          onRetry: _loadProjects,
                          retryLabel: 'Retry',
                        )
                      : _projects.isEmpty
                          ? EmptyState(
                              icon: Icons.folder_outlined,
                              title: 'No projects tracked yet',
                              subtitle: 'Add projects to track their progress',
                              actionLabel: 'Add First Project',
                              onAction: _addProject,
                            )
                          : _buildProjectList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accentGhost,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: const Center(
                          child: Text('📂', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            if (project.path.isNotEmpty)
                              Text(
                                project.path,
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: project.status,
                        status: project.status == 'active'
                            ? ChipStatus.active
                            : ChipStatus.idle,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Added ${_formatDate(project.addedAt)}',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textTertiary),
                        onPressed: () {
                          setState(() => _projects.removeAt(index));
                          _saveProjects();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ProjectItem {
  final String name;
  final String path;
  final DateTime addedAt;
  final DateTime? lastActivity;
  final String status;

  _ProjectItem({
    required this.name,
    this.path = '',
    required this.addedAt,
    this.lastActivity,
    this.status = 'active',
  });
}
