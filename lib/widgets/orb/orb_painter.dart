import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../core/models/orb_state.dart';

class OrbPainter extends CustomPainter {
  final OrbState state;
  final double animationValue;
  final double rotationValue;

  OrbPainter({
    required this.state,
    required this.animationValue,
    required this.rotationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    switch (state) {
      case OrbState.idle:
        _paintIdle(canvas, center, radius);
        break;
      case OrbState.listening:
        _paintListening(canvas, center, radius);
        break;
      case OrbState.thinking:
        _paintThinking(canvas, center, radius);
        break;
      case OrbState.speaking:
        _paintSpeaking(canvas, center, radius);
        break;
    }
  }

  void _paintIdle(Canvas canvas, Offset center, double radius) {
    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.orbGlowIdle,
          AppColors.orbGlowIdle.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 1.5),
      );
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    // Orb body gradient
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          AppColors.orbCenter,
          AppColors.orbMid,
          AppColors.orbEdge,
        ],
        stops: const [0.0, 0.4, 0.7],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, bodyPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(center.dx - radius * 0.2, center.dy - radius * 0.2),
          radius: radius * 0.5,
        ),
      );
    canvas.drawCircle(
      Offset(center.dx - radius * 0.2, center.dy - radius * 0.2),
      radius * 0.5,
      highlightPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = AppColors.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _paintListening(Canvas canvas, Offset center, double radius) {
    final breathe = 1.0 + (animationValue * 0.08);
    final actualRadius = radius * breathe;

    // Outer glow (expanded)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.orbGlowActive,
          AppColors.orbGlowActive.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: actualRadius * 2.0),
      );
    canvas.drawCircle(center, actualRadius * 2.0, glowPaint);

    // Orb body
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          AppColors.accentHover,
          AppColors.accent,
          AppColors.orbMid,
        ],
        stops: const [0.0, 0.4, 0.8],
      ).createShader(
        Rect.fromCircle(center: center, radius: actualRadius),
      );
    canvas.drawCircle(center, actualRadius, bodyPaint);

    // Waveform bars
    _paintWaveform(canvas, center, actualRadius, 5);

    // Border
    final borderPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, actualRadius, borderPaint);
  }

  void _paintThinking(Canvas canvas, Offset center, double radius) {
    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.orbGlowIdle,
          AppColors.orbGlowIdle.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 1.8),
      );
    canvas.drawCircle(center, radius * 1.8, glowPaint);

    // Orb body
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          AppColors.orbCenter,
          AppColors.orbMid,
          AppColors.orbEdge,
        ],
        stops: const [0.0, 0.4, 0.7],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, bodyPaint);

    // Rotating ring segments
    _paintRotatingRing(canvas, center, radius);

    // Border
    final borderPaint = Paint()
      ..color = AppColors.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _paintSpeaking(Canvas canvas, Offset center, double radius) {
    final speakScale = 1.0 + (animationValue * 0.05);
    final actualRadius = radius * speakScale;

    // Ripple rings
    for (int i = 0; i < 3; i++) {
      final rippleProgress = (animationValue + (i * 0.33)) % 1.0;
      final rippleRadius = actualRadius * (1.0 + rippleProgress * 0.5);
      final rippleOpacity = (1.0 - rippleProgress) * 0.15;

      final ripplePaint = Paint()
        ..color = AppColors.accent.withOpacity(rippleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, rippleRadius, ripplePaint);
    }

    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.orbGlowSpeaking,
          AppColors.orbGlowSpeaking.withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: actualRadius * 1.8),
      );
    canvas.drawCircle(center, actualRadius * 1.8, glowPaint);

    // Orb body
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          AppColors.accentHover,
          AppColors.accent,
          AppColors.orbMid,
        ],
        stops: const [0.0, 0.4, 0.8],
      ).createShader(
        Rect.fromCircle(center: center, radius: actualRadius),
      );
    canvas.drawCircle(center, actualRadius, bodyPaint);

    // Waveform bars (wider)
    _paintWaveform(canvas, center, actualRadius, 7);

    // Border
    final borderPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, actualRadius, borderPaint);
  }

  void _paintWaveform(Canvas canvas, Offset center, double radius, int barCount) {
    final barPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final barWidth = radius * 0.12;
    final maxHeight = radius * 0.5;
    final totalWidth = barCount * barWidth + (barCount - 1) * barWidth;
    final startX = center.dx - totalWidth / 2;

    for (int i = 0; i < barCount; i++) {
      final x = startX + i * (barWidth * 2);
      final normalizedI = i / (barCount - 1);
      final heightFactor = 0.4 + (sin((animationValue * 2 * pi) + (normalizedI * pi)) * 0.3 + 0.3);
      final barHeight = maxHeight * heightFactor;

      canvas.drawLine(
        Offset(x, center.dy - barHeight / 2),
        Offset(x, center.dy + barHeight / 2),
        barPaint,
      );
    }
  }

  void _paintRotatingRing(Canvas canvas, Offset center, double radius) {
    final ringRadius = radius * 1.2;
    final segmentCount = 3;
    final segmentAngle = (2 * pi) / segmentCount;
    final gapAngle = segmentAngle * 0.4;

    final ringPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < segmentCount; i++) {
      final startAngle = rotationValue * 2 * pi + (i * segmentAngle);
      final sweepAngle = segmentAngle - gapAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        startAngle,
        sweepAngle,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(OrbPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.rotationValue != rotationValue;
  }
}
