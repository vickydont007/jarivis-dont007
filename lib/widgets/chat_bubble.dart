import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? imageUrls;
  final List<String>? imagePaths;
  final String? aiAvatarImage;
  final String? userAvatarImage;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.imageUrls,
    this.imagePaths,
    this.aiAvatarImage,
    this.userAvatarImage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.cyan,
              backgroundImage: aiAvatarImage != null ? FileImage(File(aiAvatarImage!)) : null,
              child: aiAvatarImage == null ? const Icon(Icons.android, color: Colors.white, size: 20) : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? Colors.cyan : const Color(0xFF161B22),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 12),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imagePaths != null && imagePaths!.isNotEmpty) ...[
                    ...imagePaths!.map((path) => _buildLocalImagePreview(context, path)),
                    if (message.isNotEmpty) const SizedBox(height: 4),
                  ],
                  if (message.isNotEmpty) Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  if (imageUrls != null && imageUrls!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...imageUrls!.map((url) => _buildNetworkImagePreview(context, url)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(timestamp),
                    style: TextStyle(
                      color: isUser ? Colors.white.withValues(alpha: 0.7) : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              backgroundImage: userAvatarImage != null ? FileImage(File(userAvatarImage!)) : null,
              child: userAvatarImage == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalImagePreview(BuildContext context, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(context, path, isLocal: true),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF0D1117),
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImagePreview(BuildContext context, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(context, url, isLocal: false),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: const Color(0xFF0D1117),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF0D1117),
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String source, {required bool isLocal}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: isLocal
                  ? Image.file(File(source), fit: BoxFit.contain)
                  : Image.network(source, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
