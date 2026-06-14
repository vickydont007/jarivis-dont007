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

    _drawSpaceBackground(canvas, size);
    _drawStarField(canvas, size);
    _drawOrbitalRings(canvas, size);
    _drawSun(canvas, size);
    _drawPlanets(canvas, size);
    _drawEnergyStreams(canvas, size);

    canvas.restore();
  }

  void _drawSpaceBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.7,
        [
          const Color(0xFF0A0E1A),
          const Color(0xFF050810),
          const Color(0xFF020408),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Nebula glow
    final nebulaPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.3, size.height * 0.4),
        size.width * 0.4,
        [
          const Color(0xFF1A0A2E).withOpacity(0.3),
          const Color(0xFF0A0E1A).withOpacity(0.0),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), nebulaPaint);

    final nebula2Paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.7, size.height * 0.6),
        size.width * 0.35,
        [
          const Color(0xFF0A1E2E).withOpacity(0.25),
          const Color(0xFF050810).withOpacity(0.0),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), nebula2Paint);
  }

  void _drawStarField(Canvas canvas, Size size) {
    final random = Random(42);
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = random.nextDouble() * 1.5 + 0.3;
      final brightness = random.nextDouble() * 0.6 + 0.2;

      starPaint.color = Colors.white.withOpacity(brightness);
      canvas.drawCircle(Offset(x, y), starSize, starPaint);
    }

    // Twinkling stars
    final t = animation.value;
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final twinkle = (sin(t * 3 + i * 0.7) * 0.5 + 0.5) * 0.8 + 0.2;

      starPaint.color = Colors.white.withOpacity(twinkle);
      canvas.drawCircle(Offset(x, y), 1.5, starPaint);

      // Glow
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(twinkle * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), 4, glowPaint);
    }
  }

  void _drawOrbitalRings(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = animation.value;

    final ringRadii = [70.0, 120.0, 170.0, 220.0, 270.0];

    for (int i = 0; i < ringRadii.length; i++) {
      final radius = ringRadii[i];
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF1E3A5F).withOpacity(0.3 + sin(t + i) * 0.1);

      canvas.drawCircle(Offset(cx, cy), radius, ringPaint);

      // Dotted ring effect
      final dotCount = (radius * 0.15).toInt();
      final dotPaint = Paint()..style = PaintingStyle.fill;
      for (int j = 0; j < dotCount; j++) {
        final angle = (j / dotCount) * 2 * pi + t * 0.1 * (i % 2 == 0 ? 1 : -1);
        final dotX = cx + cos(angle) * radius;
        final dotY = cy + sin(angle) * radius;
        final dotAlpha = (sin(t * 2 + j * 0.3) * 0.3 + 0.4).clamp(0.0, 0.7);

        dotPaint.color = const Color(0xFF4A90D9).withOpacity(dotAlpha * 0.5);
        canvas.drawCircle(Offset(dotX, dotY), 1.0, dotPaint);
      }
    }
  }

  void _drawEnergyStreams(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = animation.value;

    for (final agent in network.agents) {
      if (!agent.isAlive || agent.role == AgentRole.orchestrator) continue;

      final agentPos = agent.position;
      final dx = agentPos.dx - cx;
      final dy = agentPos.dy - cy;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance < 10) continue;

      // Energy stream from sun to planet
      final streamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(
          Offset(cx, cy),
          agentPos,
          [
            const Color(0xFFFFA500).withOpacity(0.4),
            agent.color.withOpacity(0.3),
            agent.color.withOpacity(0.1),
          ],
        );

      final path = Path()
        ..moveTo(cx, cy);

      // Spiral energy path
      final segments = 30;
      for (int i = 1; i <= segments; i++) {
        final progress = i / segments;
        final angle = atan2(dy, dx) + progress * 0.5;
        final r = distance * progress;
        final spiralX = cx + cos(angle) * r;
        final spiralY = cy + sin(angle) * r;
        path.lineTo(spiralX, spiralY);
      }

      canvas.drawPath(path, streamPaint);

      // Flowing particles along stream
      _drawStreamParticles(canvas, cx, cy, agentPos, agent.color, t);
    }

    // Draw planet-to-planet connections
    _drawPlanetConnections(canvas, size, t);
  }

  void _drawPlanetConnections(Canvas canvas, Size size, double t) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Define connections between related agents
    final connections = [
      [AgentRole.research, AgentRole.monitor],      // Research <-> Monitor
      [AgentRole.dm, AgentRole.comment],            // DM <-> Comment
      [AgentRole.content, AgentRole.outreach],      // Content <-> Outreach
      [AgentRole.scheduler, AgentRole.lead],        // Scheduler <-> Lead Gen
      [AgentRole.research, AgentRole.code],         // Research <-> Code
      [AgentRole.monitor, AgentRole.content],       // Monitor <-> Content
    ];

    final agents = network.agents.where((a) => a.isAlive).toList();

    for (final conn in connections) {
      final agent1 = agents.firstWhere(
        (a) => a.role == conn[0],
        orElse: () => agents.first,
      );
      final agent2 = agents.firstWhere(
        (a) => a.role == conn[1],
        orElse: () => agents.last,
      );

      if (agent1.role == agent2.role) continue;

      final pos1 = agent1.position;
      final pos2 = agent2.position;

      // Calculate distance
      final dx = pos2.dx - pos1.dx;
      final dy = pos2.dy - pos1.dy;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance < 50) continue;

      // Draw curved connection
      final midX = (pos1.dx + pos2.dx) / 2;
      final midY = (pos1.dy + pos2.dy) / 2;
      final perpX = -(dy / distance) * 20;
      final perpY = (dx / distance) * 20;

      final controlPoint = Offset(midX + perpX, midY + perpY);

      final path = Path()
        ..moveTo(pos1.dx, pos1.dy)
        ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, pos2.dx, pos2.dy);

      // Connection line
      final connPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = ui.Gradient.linear(pos1, pos2, [
          agent1.color.withOpacity(0.25),
          agent2.color.withOpacity(0.25),
        ]);

      canvas.drawPath(path, connPaint);

      // Glow
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4)
        ..shader = ui.Gradient.linear(pos1, pos2, [
          agent1.color.withOpacity(0.1),
          agent2.color.withOpacity(0.1),
        ]);
      canvas.drawPath(path, glowPaint);

      // Flowing particles
      _drawConnectionParticles(canvas, path, agent1.color, agent2.color, t);
    }
  }

  void _drawConnectionParticles(Canvas canvas, Path path, Color color1, Color color2, double t) {
    final particleCount = 3;
    final particlePaint = Paint()..style = PaintingStyle.fill;

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;

    for (int i = 0; i < particleCount; i++) {
      final offset = (t * 0.6 + i / particleCount) % 1.0;
      final distance = offset * totalLength;
      final tangent = metrics.getTangentForOffset(distance);

      if (tangent != null) {
        final position = tangent.position;
        final alpha = (sin(offset * pi * 2) * 0.5 + 0.5) * 0.7;
        final color = Color.lerp(color1, color2, offset)!;

        particlePaint.color = color.withOpacity(alpha);
        canvas.drawCircle(position, 2.0, particlePaint);

        final glowPaint = Paint()
          ..color = color.withOpacity(alpha * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(position, 5, glowPaint);
      }
    }
  }

  void _drawStreamParticles(Canvas canvas, double cx, double cy, Offset target, Color color, double t) {
    final dx = target.dx - cx;
    final dy = target.dy - cy;
    final distance = sqrt(dx * dx + dy * dy);
    final angle = atan2(dy, dx);

    final particleCount = 5;
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particleCount; i++) {
      final progress = (t * 0.8 + i / particleCount) % 1.0;
      final r = distance * progress;
      final wobble = sin(t * 4 + i * 1.5) * 8;
      final perpAngle = angle + pi / 2;

      final px = cx + cos(angle) * r + cos(perpAngle) * wobble;
      final py = cy + sin(angle) * r + sin(perpAngle) * wobble;

      final alpha = (1.0 - progress) * 0.8;
      particlePaint.color = color.withOpacity(alpha);
      canvas.drawCircle(Offset(px, py), 2.5, particlePaint);

      // Particle glow
      final glowPaint = Paint()
        ..color = color.withOpacity(alpha * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(px, py), 6, glowPaint);
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = animation.value;

    final sunRadius = 40.0;

    // Outer corona
    for (int i = 5; i >= 0; i--) {
      final coronaRadius = sunRadius + 30 + i * 15;
      final coronaPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          coronaRadius,
          [
            const Color(0xFFFFA500).withOpacity(0.05 - i * 0.008),
            const Color(0xFFFF6B00).withOpacity(0.0),
          ],
        );
      canvas.drawCircle(Offset(cx, cy), coronaRadius, coronaPaint);
    }

    // Pulsing glow
    final pulseScale = 1.0 + sin(t * 2) * 0.05;
    final glowRadius = sunRadius * 2 * pulseScale;

    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        glowRadius,
        [
          const Color(0xFFFFA500).withOpacity(0.4),
          const Color(0xFFFF6B00).withOpacity(0.2),
          const Color(0xFFFF4500).withOpacity(0.0),
        ],
        [0.0, 0.4, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), glowRadius, glowPaint);

    // Sun body
    final sunPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - 8, cy - 8),
        sunRadius,
        [
          const Color(0xFFFFD700),
          const Color(0xFFFFA500),
          const Color(0xFFFF6B00),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), sunRadius, sunPaint);

    // Sun surface detail
    final detailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFD700).withOpacity(0.5);

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi + t * 0.3;
      final r1 = sunRadius * 0.4;
      final r2 = sunRadius * 0.7;
      canvas.drawLine(
        Offset(cx + cos(angle) * r1, cy + sin(angle) * r1),
        Offset(cx + cos(angle) * r2, cy + sin(angle) * r2),
        detailPaint,
      );
    }

    // Sun icon
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(Icons.hub.codePoint),
      style: TextStyle(
        fontFamily: 'MaterialIcons',
        fontSize: 30,
        color: Colors.white.withOpacity(0.9),
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(cx - iconPainter.width / 2, cy - iconPainter.height / 2),
    );

    // Sun label
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    labelPainter.text = TextSpan(
      text: 'Orchestrator',
      style: TextStyle(
        color: const Color(0xFFFFD700),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: const Color(0xFFFFA500).withOpacity(0.8), blurRadius: 8),
        ],
      ),
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(cx - labelPainter.width / 2, cy + sunRadius + 15),
    );
  }

  void _drawPlanets(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final t = animation.value;

    // Orbital distances for each agent role
    final orbitalDistances = {
      AgentRole.research: 120.0,
      AgentRole.monitor: 120.0,
      AgentRole.dm: 170.0,
      AgentRole.code: 170.0,
      AgentRole.content: 220.0,
      AgentRole.comment: 220.0,
      AgentRole.scheduler: 270.0,
      AgentRole.lead: 270.0,
      AgentRole.outreach: 270.0,
    };

    // Base angles for each role
    final baseAngles = {
      AgentRole.research: -pi / 3,
      AgentRole.monitor: -2 * pi / 3,
      AgentRole.dm: pi / 6,
      AgentRole.code: pi / 3,
      AgentRole.content: -5 * pi / 6,
      AgentRole.comment: 5 * pi / 6,
      AgentRole.scheduler: pi / 2,
      AgentRole.lead: -pi / 2,
      AgentRole.outreach: pi,
    };

    for (final agent in network.agents) {
      if (!agent.isAlive || agent.role == AgentRole.orchestrator) continue;

      final orbitalRadius = orbitalDistances[agent.role] ?? 200.0;
      final baseAngle = baseAngles[agent.role] ?? 0;
      final orbitalSpeed = 0.1 / (orbitalRadius / 100);

      final angle = baseAngle + t * orbitalSpeed;
      final planetX = cx + cos(angle) * orbitalRadius;
      final planetY = cy + sin(angle) * orbitalRadius;

      agent.position = Offset(planetX, planetY);

      _drawPlanet(canvas, Offset(planetX, planetY), agent, t);
    }
  }

  void _drawPlanet(Canvas canvas, Offset pos, DynamicAgent agent, double t) {
    final isSelected = agent.id == selectedAgentId;
    final planetRadius = isSelected ? 32.0 : 28.0;
    final pulseScale = agent.isActive
        ? 1.0 + sin(t * 3) * 0.06
        : 1.0;
    final drawRadius = planetRadius * pulseScale;

    // Planet glow
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        pos,
        drawRadius * 2,
        [
          agent.color.withOpacity(0.3),
          agent.color.withOpacity(0.0),
        ],
      );
    canvas.drawCircle(pos, drawRadius * 2, glowPaint);

    // Planet body
    final planetPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(pos.dx - 4, pos.dy - 4),
        drawRadius,
        [
          agent.color.withOpacity(0.9),
          agent.color.withOpacity(0.5),
          agent.color.withOpacity(0.2),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(pos, drawRadius, planetPaint);

    // Planet border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.5
      ..color = agent.color.withOpacity(isSelected ? 1.0 : 0.6);
    canvas.drawCircle(pos, drawRadius, borderPaint);

    // Selection ring
    if (isSelected) {
      final selectRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = agent.color.withOpacity(0.8);
      canvas.drawCircle(pos, drawRadius + 8, selectRingPaint);
    }

    // Planet icon
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(_getIconData(agent.icon).codePoint),
      style: TextStyle(
        fontFamily: 'MaterialIcons',
        fontSize: drawRadius * 0.9,
        color: Colors.white.withOpacity(0.9),
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(pos.dx - iconPainter.width / 2, pos.dy - iconPainter.height / 2),
    );

    // Planet label
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    labelPainter.text = TextSpan(
      text: agent.name,
      style: TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
          Shadow(color: agent.color.withOpacity(0.5), blurRadius: 6),
        ],
      ),
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(pos.dx - labelPainter.width / 2, pos.dy + drawRadius + 8),
    );

    // Status indicator
    if (agent.isActive) {
      final statusAngle = t * 3;
      final orbitR = drawRadius + 4;
      final statusPos = Offset(
        pos.dx + cos(statusAngle) * orbitR,
        pos.dy + sin(statusAngle) * orbitR,
      );

      final statusPaint = Paint()..style = PaintingStyle.fill;
      statusPaint.color = const Color(0xFF00FF00);
      canvas.drawCircle(statusPos, 3, statusPaint);

      final statusGlow = Paint()
        ..color = const Color(0xFF00FF00).withOpacity(0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(statusPos, 6, statusGlow);
    }

    // Task badge
    if (agent.tasksCompleted > 0) {
      final badgePos = Offset(pos.dx + drawRadius * 0.7, pos.dy - drawRadius * 0.7);
      final badgeRadius = 8.0;

      final badgeBg = Paint()..color = const Color(0xFF1A2030);
      canvas.drawCircle(badgePos, badgeRadius, badgeBg);

      final badgeBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = agent.color.withOpacity(0.6);
      canvas.drawCircle(badgePos, badgeRadius, badgeBorder);

      final countPainter = TextPainter(textDirection: TextDirection.ltr);
      countPainter.text = TextSpan(
        text: '${agent.tasksCompleted}',
        style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
      );
      countPainter.layout();
      countPainter.paint(
        canvas,
        Offset(badgePos.dx - countPainter.width / 2, badgePos.dy - countPainter.height / 2),
      );
    }
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
