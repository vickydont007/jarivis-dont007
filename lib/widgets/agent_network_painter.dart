import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/dynamic_agent.dart';
import '../core/agent_network.dart';

class AgentNetworkPainter extends CustomPainter {
  final AgentNetwork network;
  final Animation<double> animation;
  final String? selectedAgentId;
  final double scale;
  final Offset offset;

  AgentNetworkPainter({
    required this.network,
    required this.animation,
    this.selectedAgentId,
    this.scale = 1.0,
    this.offset = Offset.zero,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    _drawBackground(canvas, size);
    _drawConnections(canvas, size);
    _drawNodes(canvas, size);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.6,
        [
          const Color(0xFF0D1117),
          const Color(0xFF0A0E14),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final dotPaint = Paint()..color = const Color(0xFF1A2030);
    for (double x = 0; x < size.width; x += 40) {
      for (double y = 0; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 0.5, dotPaint);
      }
    }
  }

  void _drawConnections(Canvas canvas, Size size) {
    final t = animation.value;

    for (final conn in network.connections) {
      final from = network.getAgentById(conn.fromId);
      final to = network.getAgentById(conn.toId);
      if (from == null || to == null) continue;

      final fromPos = from.position;
      final toPos = to.position;

      _drawFlowingConnection(canvas, fromPos, toPos, conn, from.color, to.color, t);
    }
  }

  void _drawFlowingConnection(
    Canvas canvas,
    Offset from,
    Offset to,
    AgentConnection conn,
    Color fromColor,
    Color toColor,
    double t,
  ) {
    final mid = Offset(
      (from.dx + to.dx) / 2,
      (from.dy + to.dy) / 2,
    );

    final controlPoint1 = Offset(
      from.dx + (mid.dx - from.dx) * 0.5,
      from.dy - 40,
    );
    final controlPoint2 = Offset(
      to.dx + (mid.dx - to.dx) * 0.5,
      to.dy - 40,
    );

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, to.dx, to.dy);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = conn.isActive ? 3.0 : 2.0
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(from, to, [
        fromColor.withOpacity(conn.isActive ? 0.7 : 0.35),
        toColor.withOpacity(conn.isActive ? 0.7 : 0.35),
      ]);

    canvas.drawPath(path, basePaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = conn.isActive ? 8.0 : 5.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6)
      ..shader = ui.Gradient.linear(from, to, [
        fromColor.withOpacity(conn.isActive ? 0.3 : 0.12),
        toColor.withOpacity(conn.isActive ? 0.3 : 0.12),
      ]);
    canvas.drawPath(path, glowPaint);

    _drawFlowingParticles(canvas, path, fromColor, toColor, t, conn.isActive);
  }

  void _drawFlowingParticles(
    Canvas canvas,
    Path path,
    Color fromColor,
    Color toColor,
    double t,
    bool isActive,
  ) {
    final particleCount = isActive ? 8 : 5;
    final particlePaint = Paint()..style = PaintingStyle.fill;

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;

    for (int i = 0; i < particleCount; i++) {
      final offset = (t * 1.5 + i / particleCount) % 1.0;
      final distance = offset * totalLength;
      final tangent = metrics.getTangentForOffset(distance);

      if (tangent != null) {
        final position = tangent.position;
        final particleSize = isActive ? 4.0 : 3.0;
        final alpha = (sin(offset * pi * 2) * 0.5 + 0.5) * (isActive ? 1.0 : 0.7);

        final color = Color.lerp(fromColor, toColor, offset)!;
        particlePaint.color = color.withOpacity(alpha);

        canvas.drawCircle(position, particleSize, particlePaint);

        final glowPaint = Paint()
          ..color = color.withOpacity(alpha * 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(position, particleSize * 3, glowPaint);
      }
    }
  }

  void _drawNodes(Canvas canvas, Size size) {
    final t = animation.value;

    for (final agent in network.agents) {
      if (!agent.isAlive) continue;
      _drawNode(canvas, agent, t);
    }
  }

  void _drawNode(Canvas canvas, DynamicAgent agent, double t) {
    final pos = agent.position;
    final isSelected = agent.id == selectedAgentId;
    final nodeRadius = isSelected ? 36.0 : 30.0;

    _drawGlowRings(canvas, pos, nodeRadius, agent.color, t, agent.isActive);

    final pulseScale = agent.isActive
        ? 1.0 + sin(t * 4) * 0.08
        : 1.0 + sin(t * 1.5) * 0.03;
    final drawRadius = nodeRadius * pulseScale;

    final outerGlow = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, drawRadius * 0.5)
      ..color = agent.color.withOpacity(agent.isActive ? 0.25 : 0.12);
    canvas.drawCircle(pos, drawRadius * 1.3, outerGlow);

    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        pos,
        drawRadius,
        [
          agent.color.withOpacity(agent.isActive ? 0.35 : 0.15),
          agent.color.withOpacity(agent.isActive ? 0.15 : 0.05),
          const Color(0xFF0D1117).withOpacity(0.8),
        ],
        [0.0, 0.6, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, drawRadius, bgPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3.5 : 2.5
      ..color = agent.color.withOpacity(isSelected ? 1.0 : 0.8);
    canvas.drawCircle(pos, drawRadius, borderPaint);

    if (isSelected) {
      final selectGlow = Paint()
        ..color = agent.color.withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(pos, drawRadius + 10, selectGlow);
    }

    _drawNodeIcon(canvas, pos, agent, drawRadius * 0.5);
    _drawNodeLabel(canvas, pos, agent, drawRadius);

    if (agent.isActive) {
      _drawStatusIndicator(canvas, pos, agent.color, drawRadius, t);
    }

    if (agent.tasksCompleted > 0) {
      _drawTaskBadge(canvas, pos, agent, drawRadius);
    }
  }

  void _drawGlowRings(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double t,
    bool isActive,
  ) {
    final ringCount = isActive ? 5 : 3;

    for (int i = 0; i < ringCount; i++) {
      final ringRadius = radius + 18 + i * 14.0;
      final phaseOffset = i * 0.4;
      final alpha = isActive
          ? (0.2 - i * 0.03) * (sin(t * 2.5 + phaseOffset) * 0.5 + 0.5)
          : (0.12 - i * 0.025) * (sin(t * 1.0 + phaseOffset) * 0.5 + 0.5);

      if (alpha > 0.01) {
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 1.5 : 1.0
          ..color = color.withOpacity(alpha);
        canvas.drawCircle(center, ringRadius, ringPaint);
      }
    }

    final innerGlow = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.6)
      ..color = color.withOpacity(isActive ? 0.15 : 0.08);
    canvas.drawCircle(center, radius * 1.2, innerGlow);
  }

  void _drawNodeIcon(Canvas canvas, Offset center, DynamicAgent agent, double iconRadius) {
    final iconData = _getIconData(agent.icon);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final iconCodePoint = iconData.codePoint;
    final iconStr = String.fromCharCode(iconCodePoint);

    textPainter.text = TextSpan(
      text: iconStr,
      style: TextStyle(
        fontFamily: 'MaterialIcons',
        fontSize: iconRadius * 2.2,
        color: agent.color,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawNodeLabel(Canvas canvas, Offset center, DynamicAgent agent, double radius) {
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    labelPainter.text = TextSpan(
      text: agent.name,
      style: TextStyle(
        color: Colors.white.withOpacity(0.95),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.9),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          Shadow(
            color: agent.color.withOpacity(0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy + radius + 10,
      ),
    );
  }

  void _drawStatusIndicator(
    Canvas canvas,
    Offset center,
    Color color,
    double radius,
    double t,
  ) {
    final angle = t * 2;
    final orbitRadius = radius + 6;
    final dotPos = Offset(
      center.dx + cos(angle) * orbitRadius,
      center.dy + sin(angle) * orbitRadius,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;
    dotPaint.color = color.withOpacity(0.9);
    canvas.drawCircle(dotPos, 3, dotPaint);

    final dotGlow = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(dotPos, 6, dotGlow);
  }

  void _drawTaskBadge(Canvas canvas, Offset center, DynamicAgent agent, double radius) {
    final badgeCenter = Offset(center.dx + radius * 0.7, center.dy - radius * 0.7);
    final badgeRadius = 10.0;

    final badgeBg = Paint()
      ..color = const Color(0xFF1A2030)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, badgeBg);

    final badgeBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = agent.color.withOpacity(0.6);
    canvas.drawCircle(badgeCenter, badgeRadius, badgeBorder);

    final countPainter = TextPainter(textDirection: TextDirection.ltr);
    countPainter.text = TextSpan(
      text: '${agent.tasksCompleted}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
    countPainter.layout();
    countPainter.paint(
      canvas,
      Offset(
        badgeCenter.dx - countPainter.width / 2,
        badgeCenter.dy - countPainter.height / 2,
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'hub':
        return Icons.hub;
      case 'send':
        return Icons.send;
      case 'palette':
        return Icons.palette;
      case 'chat':
        return Icons.chat;
      case 'comment':
        return Icons.comment;
      case 'target':
        return Icons.gps_fixed;
      case 'search':
        return Icons.search;
      case 'eye':
        return Icons.visibility;
      case 'code':
        return Icons.code;
      case 'schedule':
        return Icons.schedule;
      case 'extension':
        return Icons.extension;
      default:
        return Icons.circle;
    }
  }

  @override
  bool shouldRepaint(covariant AgentNetworkPainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
        oldDelegate.selectedAgentId != selectedAgentId ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}
