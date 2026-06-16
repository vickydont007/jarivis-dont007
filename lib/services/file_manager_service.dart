import 'dart:io';
import 'package:path/path.dart' as p;
import 'file_service.dart';
import 'file_permission_manager.dart';

class FileManagerService {
  final FileService _fileService = FileService();
  final FilePermissionManager _permissions = FilePermissionManager();

  FileService get fileService => _fileService;
  FilePermissionManager get permissions => _permissions;

  Future<List<FileInfo>> listDirectory(String path) async {
    final resolved = _permissions.resolvePath(path);
    final check = _permissions.checkPermission(resolved, PermissionAction.read);
    if (!check.allowed) throw Exception(check.reason);
    return _fileService.listFiles(resolved);
  }

  Future<String> readFile(String path) async {
    final resolved = _permissions.resolvePath(path);
    final check = _permissions.checkPermission(resolved, PermissionAction.read);
    if (!check.allowed) throw Exception(check.reason);

    final file = File(resolved);
    if (!await file.exists()) throw Exception('File not found: $resolved');
    return await file.readAsString();
  }

  Future<void> writeFile(String path, String content) async {
    final resolved = _permissions.resolvePath(path);
    final check = _permissions.checkPermission(resolved, PermissionAction.write);
    if (!check.allowed) throw Exception(check.reason);

    final file = File(resolved);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(content);
  }

  Future<void> appendFile(String path, String content) async {
    final resolved = _permissions.resolvePath(path);
    final check = _permissions.checkPermission(resolved, PermissionAction.write);
    if (!check.allowed) throw Exception(check.reason);

    final file = File(resolved);
    if (!await file.exists()) {
      await writeFile(resolved, content);
      return;
    }
    await file.writeAsString(content, mode: FileMode.append);
  }

  Future<void> createFolder(String path) async {
    final resolved = _permissions.resolvePath(path);
    final check =
        _permissions.checkPermission(resolved, PermissionAction.create);
    if (!check.allowed) throw Exception(check.reason);
    await _fileService.createDirectory(resolved);
  }

  Future<bool> deleteFile(String path, {bool recursive = false}) async {
    final resolved = _permissions.resolvePath(path);
    final check =
        _permissions.checkPermission(resolved, PermissionAction.delete);
    if (!check.allowed) throw Exception(check.reason);
    return _fileService.delete(resolved, recursive: recursive);
  }

  Future<bool> renameFile(String oldPath, String newName) async {
    final resolved = _permissions.resolvePath(oldPath);
    final check =
        _permissions.checkPermission(resolved, PermissionAction.move);
    if (!check.allowed) throw Exception(check.reason);

    final parent = p.dirname(resolved);
    final newPath = p.join(parent, newName);
    final destCheck =
        _permissions.checkPermission(newPath, PermissionAction.create);
    if (!destCheck.allowed) throw Exception(destCheck.reason);

    try {
      await File(resolved).rename(newPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> moveFile(String source, String destination) async {
    final resolvedSrc = _permissions.resolvePath(source);
    final resolvedDst = _permissions.resolvePath(destination);
    final srcCheck =
        _permissions.checkPermission(resolvedSrc, PermissionAction.move);
    if (!srcCheck.allowed) throw Exception(srcCheck.reason);
    final dstCheck =
        _permissions.checkPermission(resolvedDst, PermissionAction.create);
    if (!dstCheck.allowed) throw Exception(dstCheck.reason);

    return _fileService.moveFile(resolvedSrc, resolvedDst);
  }

  Future<bool> copyFile(String source, String destination) async {
    final resolvedSrc = _permissions.resolvePath(source);
    final resolvedDst = _permissions.resolvePath(destination);
    final srcCheck =
        _permissions.checkPermission(resolvedSrc, PermissionAction.read);
    if (!srcCheck.allowed) throw Exception(srcCheck.reason);
    final dstCheck =
        _permissions.checkPermission(resolvedDst, PermissionAction.write);
    if (!dstCheck.allowed) throw Exception(dstCheck.reason);

    return _fileService.copyFile(resolvedSrc, resolvedDst);
  }

  Future<List<FileInfo>> searchFiles(
    String path,
    String query, {
    bool recursive = false,
    String? extension,
  }) async {
    final resolved = _permissions.resolvePath(path);
    final check = _permissions.checkPermission(resolved, PermissionAction.read);
    if (!check.allowed) throw Exception(check.reason);

    if (recursive) {
      return _searchRecursive(resolved, query, extension);
    }

    var files = await _fileService.searchFiles(resolved, query);
    if (extension != null) {
      files = files
          .where((f) =>
              p.extension(f.name).toLowerCase() == extension.toLowerCase())
          .toList();
    }
    return files;
  }

  Future<List<FileInfo>> _searchRecursive(
    String path,
    String query,
    String? extension,
  ) async {
    final results = <FileInfo>[];
    final dir = Directory(path);
    if (!await dir.exists()) return results;

    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is Directory) {
          final subResults = await _searchRecursive(entity.path, query, extension);
          results.addAll(subResults);
        } else if (entity is File) {
          final name = p.basename(entity.path);
          if (name.toLowerCase().contains(query.toLowerCase())) {
            if (extension == null ||
                p.extension(name).toLowerCase() == extension.toLowerCase()) {
              final stat = await entity.stat();
              results.add(FileInfo(
                name: name,
                path: entity.path,
                isDirectory: false,
                size: stat.size,
                modifiedAt: stat.modified,
              ));
            }
          }
        }
      }
    } catch (_) {}
    return results;
  }

  Future<List<FileInfo>> searchByContent(
    String path,
    String query, {
    int maxResults = 20,
  }) async {
    final resolved = _permissions.resolvePath(path);
    final check = _permissions.checkPermission(resolved, PermissionAction.read);
    if (!check.allowed) throw Exception(check.reason);

    final results = <FileInfo>[];
    final dir = Directory(resolved);
    if (!await dir.exists()) return results;

    final textExtensions = {
      '.txt', '.md', '.json', '.csv', '.dart', '.js', '.py',
      '.html', '.css', '.yaml', '.yml', '.toml', '.xml',
      '.sh', '.bash', '.zsh', '.log', '.cfg', '.ini',
    };

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && results.length < maxResults) {
          final ext = p.extension(entity.path).toLowerCase();
          if (textExtensions.contains(ext)) {
            try {
              final content = await entity.readAsString();
              if (content.toLowerCase().contains(query.toLowerCase())) {
                final stat = await entity.stat();
                results.add(FileInfo(
                  name: p.basename(entity.path),
                  path: entity.path,
                  isDirectory: false,
                  size: stat.size,
                  modifiedAt: stat.modified,
                ));
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return results;
  }

  Future<Map<String, dynamic>> getFileInfo(String path) async {
    final resolved = _permissions.resolvePath(path);
    final check = _permissions.checkPermission(resolved, PermissionAction.read);
    if (!check.allowed) throw Exception(check.reason);

    final entity = FileSystemEntity.typeSync(resolved);
    if (entity == FileSystemEntityType.notFound) {
      throw Exception('Path not found: $resolved');
    }

    final stat = await FileStat.stat(resolved);
    final file = File(resolved);

    final info = <String, dynamic>{
      'name': p.basename(resolved),
      'path': resolved,
      'type': entity == FileSystemEntityType.directory ? 'directory' : 'file',
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
      'accessed': stat.accessed.toIso8601String(),
      'mode': stat.mode,
    };

    if (entity == FileSystemEntityType.file) {
      info['extension'] = p.extension(resolved);
      info['is_text'] = _isTextFile(resolved);

      if (await file.exists() && stat.size < 1024 * 100) {
        try {
          final content = await file.readAsString();
          info['line_count'] = content.split('\n').length;
          info['preview'] = content.length > 500
              ? content.substring(0, 500) + '...'
              : content;
        } catch (_) {}
      }
    }

    if (entity == FileSystemEntityType.directory) {
      try {
        final contents = await _fileService.listFiles(resolved);
        info['item_count'] = contents.length;
        info['folder_count'] = contents.where((f) => f.isDirectory).length;
        info['file_count'] = contents.where((f) => !f.isDirectory).length;
      } catch (_) {}
    }

    return info;
  }

  bool _isTextFile(String path) {
    final textExts = {
      '.txt', '.md', '.json', '.csv', '.dart', '.js', '.py',
      '.html', '.css', '.yaml', '.yml', '.toml', '.xml',
      '.sh', '.log', '.cfg', '.ini', '.java', '.kt', '.swift',
      '.c', '.cpp', '.h', '.rs', '.go', '.rb', '.php',
    };
    return textExts.contains(p.extension(path).toLowerCase());
  }

  String formatSize(int bytes) => _fileService.formatFileSize(bytes);
}
