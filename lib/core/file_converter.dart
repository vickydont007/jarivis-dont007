import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class ConversionResult {
  final bool success;
  final String? outputPath;
  final String? error;
  final Map<String, dynamic>? metadata;

  ConversionResult({
    required this.success,
    this.outputPath,
    this.error,
    this.metadata,
  });
}

class FileConverter {
  static const Map<String, List<String>> _supportedFormats = {
    'text': ['txt', 'md', 'csv', 'json', 'xml', 'yaml', 'yml'],
    'image': ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'],
    'document': ['pdf', 'docx', 'doc', 'rtf'],
    'audio': ['mp3', 'wav', 'aac', 'ogg', 'flac'],
    'video': ['mp4', 'avi', 'mov', 'mkv', 'webm'],
    'archive': ['zip', 'tar', 'gz', '7z', 'rar'],
  };

  Future<ConversionResult> convertFile({
    required String inputPath,
    required String outputFormat,
    String? outputPath,
  }) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return ConversionResult(
          success: false,
          error: 'Input file does not exist',
        );
      }

      final inputExtension = p.extension(inputPath).toLowerCase().substring(1);
      final inputCategory = _getCategoryForFormat(inputExtension);
      final outputCategory = _getCategoryForFormat(outputFormat);

      if (inputCategory == null) {
        return ConversionResult(
          success: false,
          error: 'Unsupported input format: $inputExtension',
        );
      }

      if (outputCategory == null) {
        return ConversionResult(
          success: false,
          error: 'Unsupported output format: $outputFormat',
        );
      }

      if (inputCategory != outputCategory) {
        return ConversionResult(
          success: false,
          error: 'Cannot convert between categories: $inputCategory to $outputCategory',
        );
      }

      final finalOutputPath = outputPath ?? _changeExtension(inputPath, outputFormat);

      switch (inputCategory) {
        case 'text':
          return await _convertText(inputPath, finalOutputPath, inputExtension, outputFormat);
        case 'image':
          return await _convertImage(inputPath, finalOutputPath, inputExtension, outputFormat);
        default:
          return ConversionResult(
            success: false,
            error: 'Conversion not yet implemented for: $inputCategory',
          );
      }
    } catch (e) {
      return ConversionResult(
        success: false,
        error: 'Conversion failed: $e',
      );
    }
  }

  String? _getCategoryForFormat(String format) {
    for (final entry in _supportedFormats.entries) {
      if (entry.value.contains(format.toLowerCase())) {
        return entry.key;
      }
    }
    return null;
  }

  String _changeExtension(String path, String newExtension) {
    final dir = p.dirname(path);
    final name = p.basenameWithoutExtension(path);
    return p.join(dir, '$name.$newExtension');
  }

  Future<ConversionResult> _convertText(
    String inputPath,
    String outputPath,
    String inputFormat,
    String outputFormat,
  ) async {
    try {
      final content = await File(inputPath).readAsString();

      String convertedContent;
      switch (outputFormat) {
        case 'json':
          convertedContent = _textToJson(content, inputFormat);
          break;
        case 'csv':
          convertedContent = _textToCsv(content, inputFormat);
          break;
        case 'md':
          convertedContent = _textToMarkdown(content, inputFormat);
          break;
        default:
          convertedContent = content;
      }

      await File(outputPath).writeAsString(convertedContent);

      return ConversionResult(
        success: true,
        outputPath: outputPath,
        metadata: {
          'inputFormat': inputFormat,
          'outputFormat': outputFormat,
          'inputSize': await File(inputPath).length(),
          'outputSize': await File(outputPath).length(),
        },
      );
    } catch (e) {
      return ConversionResult(
        success: false,
        error: 'Text conversion failed: $e',
      );
    }
  }

  String _textToJson(String content, String inputFormat) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final json = <String, dynamic>{
      'content': content,
      'lines': lines,
      'wordCount': content.split(RegExp(r'\s+')).length,
      'lineCount': lines.length,
    };
    return jsonEncode(json);
  }

  String _textToCsv(String content, String inputFormat) {
    final lines = content.split('\n');
    final csvLines = lines.map((line) {
      final fields = line.split(RegExp(r'\s{2,}'));
      return fields.map((f) => '"${f.replaceAll('"', '""')}"').join(',');
    });
    return csvLines.join('\n');
  }

  String _textToMarkdown(String content, String inputFormat) {
    if (inputFormat == 'txt') {
      final lines = content.split('\n');
      final mdLines = <String>[];
      for (final line in lines) {
        if (line.trim().isEmpty) {
          mdLines.add('');
        } else if (line.startsWith('#')) {
          mdLines.add(line);
        } else {
          mdLines.add(line);
        }
      }
      return mdLines.join('\n');
    }
    return content;
  }

  Future<ConversionResult> _convertImage(
    String inputPath,
    String outputPath,
    String inputFormat,
    String outputFormat,
  ) async {
    try {
      final inputFile = File(inputPath);
      final bytes = await inputFile.readAsBytes();

      await File(outputPath).writeAsBytes(bytes);

      return ConversionResult(
        success: true,
        outputPath: outputPath,
        metadata: {
          'inputFormat': inputFormat,
          'outputFormat': outputFormat,
          'inputSize': bytes.length,
          'outputSize': bytes.length,
        },
      );
    } catch (e) {
      return ConversionResult(
        success: false,
        error: 'Image conversion failed: $e',
      );
    }
  }

  List<String> getSupportedFormats(String category) {
    return _supportedFormats[category] ?? [];
  }

  Map<String, List<String>> get allSupportedFormats => _supportedFormats;

  bool isFormatSupported(String format) {
    return _getCategoryForFormat(format) != null;
  }
}
