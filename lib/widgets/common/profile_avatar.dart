import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final String? initials;
  final double size;
  final bool isAI;
  final Color? borderColor;

  const ProfileAvatar({
    super.key,
    this.imagePath,
    this.initials,
    this.size = 40,
    this.isAI = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final effectiveBorderColor = borderColor ?? AppColors.glassBorder;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveBorderColor,
          width: 2,
        ),
        boxShadow: isAI
            ? [
                BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: hasImage
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isAI
            ? const LinearGradient(
                colors: [AppColors.accent, AppColors.accentMuted],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isAI ? null : AppColors.backgroundElevated,
      ),
      child: Center(
        child: Text(
          initials ?? (isAI ? '◉' : '?'),
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: isAI ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
