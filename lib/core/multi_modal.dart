import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ImageAnalysis {
  final String description;
  final List<String> objects;
  final List<String> text;
  final String mood;
  final Map<String, dynamic> metadata;

  ImageAnalysis({
    required this.description,
    this.objects = const [],
    this.text = const [],
    this.mood = '',
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'objects': objects,
    'text': text,
    'mood': mood,
    'metadata': metadata,
  };

  factory ImageAnalysis.fromJson(Map<String, dynamic> json) {
    return ImageAnalysis(
      description: json['description'] ?? '',
      objects: List<String>.from(json['objects'] ?? []),
      text: List<String>.from(json['text'] ?? []),
      mood: json['mood'] ?? '',
      metadata: json['metadata'] ?? {},
    );
  }
}

class MultiModalSupport {
  final Dio _dio = Dio();
  String _apiKey = '';

  MultiModalSupport({String? apiKey}) : _apiKey = apiKey ?? '';

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  Future<ImageAnalysis> analyzeImage(String imagePath, {String? prompt}) async {
    if (_apiKey.isEmpty) {
      throw Exception('API key not set for multi-modal');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file not found: $imagePath');
    }

    final bytes = await file.readAsBytes();
    final base64Image = _encodeImage(bytes);
    final mimeType = _getMimeType(imagePath);

    return _analyzeImageWithAPI(
      base64Image: base64Image,
      mimeType: mimeType,
      prompt: prompt ?? 'Describe this image in detail. List any objects, text, or notable features.',
    );
  }

  Future<ImageAnalysis> analyzeImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
    String? prompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('API key not set for multi-modal');
    }

    final base64Image = _encodeImage(bytes);

    return _analyzeImageWithAPI(
      base64Image: base64Image,
      mimeType: mimeType,
      prompt: prompt ?? 'Describe this image in detail. List any objects, text, or notable features.',
    );
  }

  Future<ImageAnalysis> analyzeImageUrl(
    String imageUrl, {
    String? prompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('API key not set for multi-modal');
    }

    try {
      final response = await _dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://nextron-ai.app',
            'X-Title': 'Nextron AI',
          },
          validateStatus: (status) => status! < 500,
        ),
        data: {
          'model': 'google/gemini-pro-vision',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt ?? 'Describe this image in detail. List any objects, text, or notable features.',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': imageUrl,
                  },
                },
              ],
            },
          ],
          'max_tokens': 1000,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices']?[0]?['message']?['content'] ?? '';
        return _parseAnalysis(content);
      }
      throw Exception('API error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  Future<ImageAnalysis> _analyzeImageWithAPI({
    required String base64Image,
    required String mimeType,
    required String prompt,
  }) async {
    try {
      final response = await _dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://nextron-ai.app',
            'X-Title': 'Nextron AI',
          },
          validateStatus: (status) => status! < 500,
        ),
        data: {
          'model': 'google/gemini-pro-vision',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt,
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'max_tokens': 1000,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices']?[0]?['message']?['content'] ?? '';
        return _parseAnalysis(content);
      }
      throw Exception('API error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  ImageAnalysis _parseAnalysis(String content) {
    final objects = <String>[];
    final text = <String>[];

    final objectPattern = RegExp(r'(?:objects?|items?|things?)[\s:]+([^\n]+)', caseSensitive: false);
    final textPattern = RegExp(r'(?:text|words?|letters?)[\s:]+([^\n]+)', caseSensitive: false);

    for (final match in objectPattern.allMatches(content)) {
      objects.addAll(match.group(1)?.split(RegExp(r',\s*|and\s+')) ?? []);
    }

    for (final match in textPattern.allMatches(content)) {
      text.addAll(match.group(1)?.split(RegExp(r',\s*|and\s+')) ?? []);
    }

    return ImageAnalysis(
      description: content,
      objects: objects.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      text: text.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    );
  }

  String _encodeImage(Uint8List bytes) {
    return base64Encode(bytes);
  }

  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }

  Future<bool> isAvailable() async {
    if (_apiKey.isEmpty) return false;
    try {
      final response = await _dio.get(
        'https://openrouter.ai/api/v1/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
          },
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
