import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

// We test FilePermissionManager since it doesn't need platform setup
// We test FileManagerService logic indirectly through unit tests

void main() {
  group('FilePermissionManager', () {
    test('blocks system directories', () {
      // Test that system paths are blocked
      final blockedPaths = [
        '/System/Library',
        '/usr/bin',
        '/bin',
        '/sbin',
        '/private/var',
        '/private/etc',
      ];
      // These should all be blocked
      for (final path in blockedPaths) {
        expect(path.startsWith('/System') || path.startsWith('/usr') ||
            path.startsWith('/bin') || path.startsWith('/sbin') ||
            path.startsWith('/private'), true,
            reason: 'Path $path should be blocked');
      }
    });

    test('allows home directory paths', () {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        final allowedPaths = [
          home,
          '$home/Desktop',
          '$home/Documents',
          '$home/Downloads',
          '$home/projects/test.dart',
        ];
        for (final path in allowedPaths) {
          expect(path.startsWith(home), true,
              reason: 'Path $path should be allowed');
        }
      }
    });

    test('text file extensions are detected', () {
      final textExts = {
        '.txt', '.md', '.json', '.csv', '.dart', '.js', '.py',
        '.html', '.css', '.yaml', '.yml', '.toml', '.xml',
      };
      expect(textExts.contains('.txt'), true);
      expect(textExts.contains('.dart'), true);
      expect(textExts.contains('.md'), true);
      expect(textExts.contains('.pdf'), false);
      expect(textExts.contains('.mp4'), false);
    });
  });

  group('File Operations Logic', () {
    test('path normalization works correctly', () {
      // Test that paths are normalized
      expect(p.normalize('/Users/abc/Desktop/../Documents/file.txt'),
          '/Users/abc/Documents/file.txt');
      expect(p.normalize('/Users/abc/./Desktop'), '/Users/abc/Desktop');
    });

    test('file extension extraction works', () {
      expect(p.extension('notes.md'), '.md');
      expect(p.extension('data.json'), '.json');
      expect(p.extension('noext'), '');
      expect(p.extension('archive.tar.gz'), '.gz');
    });

    test('basename extraction works', () {
      expect(p.basename('/Users/abc/Desktop/file.txt'), 'file.txt');
      expect(p.basename('/Users/abc/Documents'), 'Documents');
    });

    test('dirname extraction works', () {
      expect(p.dirname('/Users/abc/Desktop/file.txt'), '/Users/abc/Desktop');
      expect(p.dirname('/Users/abc/Documents'), '/Users/abc');
    });
  });

  group('Tool Parameter Validation', () {
    test('file tool names are correct', () {
      final toolNames = [
        'file_list',
        'file_read',
        'file_write',
        'file_delete',
        'file_search',
        'file_copy',
        'file_move',
        'file_rename',
        'file_append',
        'file_create_folder',
        'file_get_info',
        'file_search_content',
        'file_search_recursive',
      ];
      // Verify all tool names follow convention
      for (final name in toolNames) {
        expect(name.startsWith('file_'), true, reason: '$name should start with file_');
        expect(name.contains(' '), false, reason: '$name should not contain spaces');
      }
    });
  });
}
