import 'dart:io';
import 'package:path/path.dart' as p;
import '../core/logger.dart';
import '../core/constants.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final JarvisLogger _log = JarvisLogger();

  Future<FileResult> read(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return FileResult.error('File not found: $path');
      }
      final content = await file.readAsString();
      return FileResult.ok(content);
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<FileResult> write(String path, String content) async {
    try {
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsString(content);
      _log.info('File written: $path (${content.length} chars)');
      return FileResult.ok('Written ${content.length} chars');
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<FileResult> append(String path, String content) async {
    try {
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsString(content, mode: FileMode.append);
      return FileResult.ok('Appended ${content.length} chars');
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<FileResult> delete(String path) async {
    try {
      final entity = await FileSystemEntity.type(path);
      if (entity == FileSystemEntityType.notFound) {
        return FileResult.error('Not found: $path');
      }
      if (entity == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }
      _log.info('Deleted: $path');
      return FileResult.ok('Deleted: $path');
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<FileResult> list(String path, {bool recursive = false}) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return FileResult.error('Directory not found: $path');
      }
      final entities = recursive
          ? dir.listSync(recursive: true, followLinks: false)
          : dir.listSync(followLinks: false);
      final items = entities.map((e) {
        final isDir = e is Directory;
        return '${isDir ? '[DIR]' : '[FILE]'} ${p.relative(e.path, from: path)}';
      }).toList();
      return FileResult.ok(items.join('\n'));
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<FileResult> copy(String source, String destination) async {
    try {
      await File(source).copy(destination);
      _log.info('Copied: $source → $destination');
      return FileResult.ok('Copied to $destination');
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<FileResult> move(String source, String destination) async {
    try {
      await File(source).rename(destination);
      _log.info('Moved: $source → $destination');
      return FileResult.ok('Moved to $destination');
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<FileResult> search(String query, {String? rootPath}) async {
    try {
      final root = rootPath ?? (Platform.isWindows ? 'C:\\' : '/');
      final findCmd = Platform.isWindows
          ? 'Get-ChildItem -Path "$root" -Recurse -Filter "*$query*" -ErrorAction SilentlyContinue | Select-Object FullName'
          : 'find "$root" -iname "*$query*" -type f 2>/dev/null | head -50';
      
      final result = await _runFindCommand(findCmd);
      return FileResult.ok(result);
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }

  Future<String> _runFindCommand(String cmd) async {
    final shell = Platform.isWindows ? 'powershell.exe' : '/bin/bash';
    final args = Platform.isWindows
        ? ['-NoProfile', '-Command', cmd]
        : ['-c', cmd];
    final process = await Process.start(shell, args);
    final stdout = await process.stdout.transform(SystemEncoding().decoder).join();
    await process.exitCode;
    return stdout;
  }

  Future<FileResult> organizeDownloads({int olderThanDays = 30}) async {
    try {
      final downloadsPath = Platform.isWindows
          ? '${Platform.environment['USERPROFILE']}\\Downloads'
          : '${Platform.environment['HOME']}/Downloads';
      final dir = Directory(downloadsPath);
      if (!await dir.exists()) {
        return FileResult.error('Downloads folder not found');
      }

      final extFolders = <String, String>{
        'jpg,jpeg,png,gif,bmp,svg,webp': 'Images',
        'pdf': 'PDFs',
        'doc,docx,xls,xlsx,ppt,pptx': 'Documents',
        'zip,rar,7z,tar,gz': 'Archives',
        'mp3,wav,flac,aac,ogg': 'Audio',
        'mp4,mkv,avi,mov,wmv': 'Video',
        'exe,msi': 'Installers',
        'dmg,pkg': 'Installers',
        'apk': 'APKs',
        'deb,rpm': 'Packages',
        'dart,py,js,ts,html,css,json,xml': 'Code',
      };

      int moved = 0;
      final now = DateTime.now();

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;

        // Age check
        final stat = await entity.stat();
        if (now.difference(stat.modified).inDays < olderThanDays) continue;

        final ext = p.extension(entity.path).toLowerCase().replaceAll('.', '');
        String? targetFolder;

        for (final entry in extFolders.entries) {
          if (entry.key.split(',').contains(ext)) {
            targetFolder = entry.value;
            break;
          }
        }

        if (targetFolder == null) {
          targetFolder = ext.isEmpty ? 'NoExt' : ext.toUpperCase();
        }

        final targetDir = Directory(p.join(dir.path, targetFolder));
        if (!await targetDir.exists()) {
          await targetDir.create();
        }

        await entity.rename(p.join(targetDir.path, entity.name));
        moved++;
      }

      _log.info('Organized $moved files in Downloads');
      return FileResult.ok('Organized $moved files');
    } catch (e) {
      return FileResult.error(e.toString());
    }
  }
}

class FileResult {
  final bool success;
  final String message;
  final String? error;

  FileResult._({required this.success, required this.message, this.error});

  factory FileResult.ok(String msg) => FileResult._(success: true, message: msg);
  factory FileResult.error(String err) => FileResult._(success: false, message: err, error: err);
}
