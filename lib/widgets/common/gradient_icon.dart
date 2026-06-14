import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final List<Color>? colors;

  const GradientIcon({
    super.key,
    required this.icon,
    this.size = 24,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          colors: colors ?? [AppColors.accent, AppColors.accentHover],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Icon(
        icon,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
