import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Background System ───────────────────────────────────────────
  static const background = Color(0xFF0A0A0A);
  static const backgroundSecondary = Color(0xFF141414);
  static const backgroundTertiary = Color(0xFF1C1C1E);
  static const backgroundElevated = Color(0xFF232326);

  // ─── Glass System ────────────────────────────────────────────────
  static const glassFill = Color(0x0DFFFFFF);       // rgba(255,255,255,0.05)
  static const glassFillHover = Color(0x14FFFFFF);  // rgba(255,255,255,0.08)
  static const glassFillActive = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
  static const glassBorder = Color(0x14FFFFFF);     // rgba(255,255,255,0.08)
  static const glassBorderHover = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
  static const glassBorderActive = Color(0x29FFFFFF); // rgba(255,255,255,0.16)

  // ─── Accent System ───────────────────────────────────────────────
  static const accent = Color(0xFF3B82F6);
  static const accentHover = Color(0xFF60A5FA);
  static const accentMuted = Color(0xFF1E3A5F);
  static const accentGhost = Color(0x1A3B82F6);     // rgba(59,130,246,0.10)
  static const accentGlow = Color(0x333B82F6);      // rgba(59,130,246,0.20)

  // ─── Text System ─────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textTertiary = Color(0xFF71717A);
  static const textDisabled = Color(0xFF52525B);

  // ─── Status System ───────────────────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const successGhost = Color(0x1F22C55E);    // rgba(34,197,94,0.12)
  static const warning = Color(0xFFF59E0B);
  static const warningGhost = Color(0x1FF59E0B);    // rgba(245,158,11,0.12)
  static const error = Color(0xFFEF4444);
  static const errorGhost = Color(0x1FEF4444);      // rgba(239,68,68,0.12)
  static const info = Color(0xFF3B82F6);
  static const infoGhost = Color(0x1A3B82F6);       // rgba(59,130,246,0.10)

  // ─── Orb Colors ──────────────────────────────────────────────────
  static const orbCenter = Color(0xFF3B82F6);
  static const orbMid = Color(0xFF1E3A5F);
  static const orbEdge = Color(0xFF0F172A);
  static const orbGlowIdle = Color(0x143B82F6);     // rgba(59,130,246,0.08)
  static const orbGlowActive = Color(0x263B82F6);   // rgba(59,130,246,0.15)
  static const orbGlowSpeaking = Color(0x333B82F6); // rgba(59,130,246,0.20)

  // ─── Overlay ─────────────────────────────────────────────────────
  static const overlay = Color(0x99000000);          // rgba(0,0,0,0.6)
  static const modalBackground = Color(0xF2141414);  // rgba(20,20,20,0.95)

  // ─── Agent Status ────────────────────────────────────────────────
  static const agentIdle = Color(0xFF71717A);
  static const agentActive = Color(0xFF22C55E);
  static const agentBusy = Color(0xFFF59E0B);
  static const agentFailed = Color(0xFFEF4444);
  static const agentSpawning = Color(0xFF3B82F6);
}
