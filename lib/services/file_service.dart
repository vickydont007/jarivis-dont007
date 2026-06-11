import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedAt;

  FileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'is_directory': isDirectory,
      'size': size,
      'modified_at': modifiedAt.toIso8601String(),
    };
  }
}

class FileService {
  // Get app documents directory
  Future<String> getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Get downloads directory
  Future<String> getDownloadsDirectory() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, 'Downloads');
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return p.join(userProfile, 'Downloads');
    }
    return await getAppDirectory();
  }

  // List files in directory
  Future<List<FileInfo>> listFiles(String path) async {
    final directory = Directory(path);
    final List<FileInfo> files = [];

    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        final stat = await entity.stat();
        files.add(FileInfo(
          name: p.basename(entity.path),
          path: entity.path,
          isDirectory: entity is Directory,
          size: stat.size,
          modifiedAt: stat.modified,
        ));
      }
    }

    // Sort: directories first, then by name
    files.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return files;
  }

  // Read file content
  Future<String> readFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsString();
    }
    throw Exception('File not found: $path');
  }

  // Write file content
  Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  // Create directory
  Future<void> createDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  // Delete file or directory
  Future<bool> delete(String path, {bool recursive = false}) async {
    final entity = FileSystemEntity.typeSync(path);

    try {
      switch (entity) {
        case FileSystemEntityType.directory:
          await Directory(path).delete(recursive: recursive);
          break;
        case FileSystemEntityType.file:
          await File(path).delete();
          break;
        default:
          return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Copy file
  Future<bool> copyFile(String source, String destination) async {
    try {
      await File(source).copy(destination);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Move file
  Future<bool> moveFile(String source, String destination) async {
    try {
      await File(source).rename(destination);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Search files
  Future<List<FileInfo>> searchFiles(String path, String query) async {
    final files = await listFiles(path);
    final results = <FileInfo>[];

    for (final file in files) {
      if (file.name.toLowerCase().contains(query.toLowerCase())) {
        results.add(file);
      }
    }

    return results;
  }

  // Organize downloads folder
  Future<Map<String, int>> organizeDownloads() async {
    final downloadsDir = await getDownloadsDirectory();
    final files = await listFiles(downloadsDir);
    final organized = <String, int>{
      'documents': 0,
      'images': 0,
      'videos': 0,
      'music': 0,
      'archives': 0,
      'other': 0,
    };

    for (final file in files) {
      if (file.isDirectory) continue;

      final ext = p.extension(file.name).toLowerCase();
      final category = _getCategory(ext);

      // Create category directory if not exists
      final categoryDir = p.join(downloadsDir, category);
      await createDirectory(categoryDir);

      // Move file to category directory
      final newPath = p.join(categoryDir, file.name);
      if (file.path != newPath) {
        await moveFile(file.path, newPath);
        organized[category] = (organized[category] ?? 0) + 1;
      }
    }

    return organized;
  }

  String _getCategory(String extension) {
    const documentExtensions = ['.pdf', '.doc', '.docx', '.txt', '.rtf', '.odt', '.xls', '.xlsx', '.ppt', '.pptx'];
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'];
    const videoExtensions = ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv'];
    const musicExtensions = ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a'];
    const archiveExtensions = ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2'];

    if (documentExtensions.contains(extension)) return 'documents';
    if (imageExtensions.contains(extension)) return 'images';
    if (videoExtensions.contains(extension)) return 'videos';
    if (musicExtensions.contains(extension)) return 'music';
    if (archiveExtensions.contains(extension)) return 'archives';
    return 'other';
  }

  // Get file size in human readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
