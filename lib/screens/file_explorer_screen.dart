import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/file_manager_service.dart';
import '../services/file_service.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/glass/glass_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  final FileManagerService _service = FileManagerService();
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _currentPath = '';
  List<FileInfo> _files = [];
  FileInfo? _selectedFile;
  Map<String, dynamic>? _selectedFileInfo;
  bool _isLoading = false;
  String? _error;
  bool _showPreview = false;
  bool _searchMode = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  Future<void> _initPath() async {
    final home = Platform.environment['HOME'] ?? '';
    _currentPath = '$home/Desktop';
    _pathController.text = _currentPath;
    await _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedFile = null;
      _selectedFileInfo = null;
      _showPreview = false;
    });

    try {
      final files = await _service.listDirectory(path);
      setState(() {
        _files = files;
        _currentPath = path;
        _pathController.text = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateTo(String path) async {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      await _loadDirectory(path);
    } else if (entity == FileSystemEntityType.file) {
      await _selectFile(FileInfo(
        name: p.basename(path),
        path: path,
        isDirectory: false,
        size: 0,
        modifiedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _goUp() async {
    final parent = p.dirname(_currentPath);
    if (parent != _currentPath) {
      await _loadDirectory(parent);
    }
  }

  Future<void> _selectFile(FileInfo file) async {
    setState(() {
      _selectedFile = file;
      _showPreview = true;
    });

    try {
      final info = await _service.getFileInfo(file.path);
      setState(() => _selectedFileInfo = info);
    } catch (e) {
      setState(() => _selectedFileInfo = {'error': e.toString()});
    }
  }

  Future<void> _searchFiles() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchMode = true;
      _searchQuery = query;
      _error = null;
    });

    try {
      final files = await _service.searchFiles(_currentPath, query);
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _exitSearch() {
    setState(() => _searchMode = false);
    _loadDirectory(_currentPath);
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Create Folder'),
        content: GlassTextField(
          controller: nameController,
          hintText: 'Folder name',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _service.createFolder(p.join(_currentPath, result));
        await _loadDirectory(_currentPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteFile(FileInfo file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Delete'),
        content: Text('Delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteFile(file.path);
        setState(() {
          _selectedFile = null;
          _showPreview = false;
        });
        await _loadDirectory(_currentPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  String _formatSize(int bytes) => _service.formatSize(bytes);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left: File list
          Expanded(
            flex: 3,
            child: _buildFileListPanel(),
          ),
          // Right: Preview panel
          if (_showPreview && _selectedFile != null)
            SizedBox(
              width: 340,
              child: _buildPreviewPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildFileListPanel() {
    return Column(
      children: [
        // Toolbar
        _buildToolbar(),
        // Breadcrumb
        _buildBreadcrumb(),
        // File list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _files.isEmpty
                      ? _buildEmpty()
                      : _buildFileList(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: _searchMode ? _exitSearch : _goUp,
            tooltip: _searchMode ? 'Exit search' : 'Go up',
          ),
          const SizedBox(width: AppSpacing.sm),
          // Path field
          Expanded(
            child: GlassTextField(
              controller: _pathController,
              hintText: 'Path...',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Go button
          GlassButton(
            onPressed: () => _loadDirectory(_pathController.text),
            label: 'Go',
            icon: Icons.arrow_forward,
            isCompact: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Search
          SizedBox(
            width: 200,
            child: GlassTextField(
              controller: _searchController,
              hintText: 'Search files...',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GlassButton(
            onPressed: _searchFiles,
            label: 'Search',
            icon: Icons.search,
            isCompact: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          // New folder
          GlassButton(
            onPressed: _createFolder,
            label: 'New Folder',
            icon: Icons.create_new_folder,
            isCompact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final parts = _currentPath.split(Platform.pathSeparator);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textTertiary),
              ),
            GestureDetector(
              onTap: () {
                final path = parts.sublist(0, i + 1).join(Platform.pathSeparator);
                _loadDirectory(path);
              },
              child: Text(
                parts[i],
                style: TextStyle(
                  color: i == parts.length - 1
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isSelected = _selectedFile?.path == file.path;
        return _buildFileTile(file, isSelected);
      },
    );
  }

  Widget _buildFileTile(FileInfo file, bool isSelected) {
    final icon = file.isDirectory ? Icons.folder : _getFileIcon(file.name);
    final color = file.isDirectory ? AppColors.accent : AppColors.textSecondary;

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      margin: const EdgeInsets.only(bottom: 2),
      onTap: () {
        if (file.isDirectory) {
          _loadDirectory(file.path);
        } else {
          _selectFile(file);
        }
      },
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!file.isDirectory)
                  Text(
                    _formatSize(file.size),
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (!file.isDirectory)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: AppColors.textTertiary),
              onPressed: () => _deleteFile(file),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final file = _selectedFile!;
    final info = _selectedFileInfo;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        border: Border(
          left: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.glassBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _showPreview = false;
                    _selectedFile = null;
                  }),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: info == null
                ? const Center(child: CircularProgressIndicator())
                : _buildPreviewContent(info),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(Map<String, dynamic> info) {
    if (info.containsKey('error')) {
      return Center(
        child: Text(
          info['error'],
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Type', info['type']?.toString() ?? ''),
          _buildInfoRow('Size', _formatSize(info['size'] ?? 0)),
          _buildInfoRow('Modified', info['modified']?.toString() ?? ''),
          if (info['extension'] != null)
            _buildInfoRow('Extension', info['extension']),
          if (info['line_count'] != null)
            _buildInfoRow('Lines', info['line_count'].toString()),
          if (info['item_count'] != null) ...[
            _buildInfoRow('Items', info['item_count'].toString()),
            _buildInfoRow('Folders', info['folder_count'].toString()),
            _buildInfoRow('Files', info['file_count'].toString()),
          ],
          if (info['preview'] != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Preview',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Text(
                info['preview'],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          GlassButton(
            onPressed: () => _loadDirectory(_currentPath),
            label: 'Retry',
            icon: Icons.refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            _searchMode ? 'No results for "$_searchQuery"' : 'Empty folder',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.md':
        return Icons.description;
      case '.txt':
        return Icons.article;
      case '.json':
        return Icons.code;
      case '.csv':
        return Icons.table_chart;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return Icons.image;
      case '.mp4':
      case '.mov':
        return Icons.video_file;
      case '.mp3':
      case '.wav':
        return Icons.audio_file;
      case '.zip':
      case '.rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
