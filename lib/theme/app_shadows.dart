import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  AppShadows._();

  // ─── Glass Card ──────────────────────────────────────────────────
  static const List<BoxShadow> glass = [
    BoxShadow(
      color: Color(0x33000000),   // rgba(0,0,0,0.2)
      blurRadius: 24,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // ─── Glass Card Hover ────────────────────────────────────────────
  static const List<BoxShadow> glassHover = [
    BoxShadow(
      color: Color(0x4D000000),   // rgba(0,0,0,0.3)
      blurRadius: 32,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // ─── Orb Glow (Idle) ─────────────────────────────────────────────
  static const List<BoxShadow> orbGlowIdle = [
    BoxShadow(
      color: AppColors.orbGlowIdle,
      blurRadius: 60,
      spreadRadius: 0,
    ),
  ];

  // ─── Orb Glow (Active) ───────────────────────────────────────────
  static const List<BoxShadow> orbGlowActive = [
    BoxShadow(
      color: AppColors.orbGlowActive,
      blurRadius: 80,
      spreadRadius: 0,
    ),
  ];

  // ─── Orb Glow (Speaking) ─────────────────────────────────────────
  static const List<BoxShadow> orbGlowSpeaking = [
    BoxShadow(
      color: AppColors.orbGlowSpeaking,
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];

  // ─── Accent Glow ─────────────────────────────────────────────────
  static const List<BoxShadow> accentGlow = [
    BoxShadow(
      color: AppColors.accentGlow,
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];

  // ─── Button Primary ──────────────────────────────────────────────
  static const List<BoxShadow> buttonPrimary = [
    BoxShadow(
      color: Color(0x4D3B82F6),   // rgba(59,130,246,0.3)
      blurRadius: 8,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // ─── Modal ───────────────────────────────────────────────────────
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x80000000),   // rgba(0,0,0,0.5)
      blurRadius: 80,
      offset: Offset(0, 24),
      spreadRadius: 0,
    ),
  ];

  // ─── Subtle (for floating elements) ──────────────────────────────
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x1A000000),   // rgba(0,0,0,0.1)
      blurRadius: 16,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];
}
