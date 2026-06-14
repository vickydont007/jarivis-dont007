import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  // ─── Font Family ─────────────────────────────────────────────────
  static const String fontFamily = '.AppleSystemUIFont';
  static const String fallbackFont = 'Inter';
  static const String monoFont = 'SF Mono';

  // ─── Display (32px) ──────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,        // 40px line-height
    letterSpacing: -0.02,
    color: AppColors.textPrimary,
  );

  // ─── Title (24px) ────────────────────────────────────────────────
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,        // 32px line-height
    letterSpacing: -0.01,
    color: AppColors.textPrimary,
  );

  // ─── Headline (20px) ─────────────────────────────────────────────
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,         // 28px line-height
    letterSpacing: -0.01,
    color: AppColors.textPrimary,
  );

  // ─── Subhead (16px) ──────────────────────────────────────────────
  static const TextStyle subhead = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,         // 24px line-height
    letterSpacing: 0.0,
    color: AppColors.textPrimary,
  );

  // ─── Body (14px) ─────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,        // 20px line-height
    letterSpacing: 0.0,
    color: AppColors.textPrimary,
  );

  // ─── Body Small (13px) ───────────────────────────────────────────
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38,        // 18px line-height
    letterSpacing: 0.01,
    color: AppColors.textSecondary,
  );

  // ─── Caption (12px) ──────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,        // 16px line-height
    letterSpacing: 0.02,
    color: AppColors.textTertiary,
  );

  // ─── Overline (10px) ─────────────────────────────────────────────
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.4,         // 14px line-height
    letterSpacing: 0.08,
    color: AppColors.textTertiary,
  );

  // ─── Code (13px) ─────────────────────────────────────────────────
  static const TextStyle code = TextStyle(
    fontFamily: monoFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38,        // 18px line-height
    letterSpacing: 0.0,
    color: AppColors.textSecondary,
  );
}
