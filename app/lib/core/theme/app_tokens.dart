import 'package:flutter/material.dart';

/// Design tokens for the premium-minimal dark theme.
abstract final class AppTokens {
  // Palette
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF14141B);
  static const surfaceElevated = Color(0xFF1C1C26);
  static const surfaceInteractive = Color(0xFF24242F);
  static const accent = Color(0xFF5B8CFF);
  static const accentSoft = Color(0x335B8CFF);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const textPrimary = Color(0xFFF4F4F6);
  static const textSecondary = Color(0xFF9A9AA6);
  static const textTertiary = Color(0xFF6A6A76);
  static const hairline = Color(0xFF26262F);

  // Shape
  static const radiusCard = 20.0;
  static const radiusInner = 12.0;
  static const radiusPill = 100.0;

  // Spacing
  static const space = 20.0;
  static const spaceSm = 12.0;
  static const spaceXs = 8.0;

  // Motion
  static const durationFast = Duration(milliseconds: 160);
  static const durationMed = Duration(milliseconds: 280);
  static const easeOut = Curves.easeOutCubic;
  static const easeEmphasized = Curves.easeInOutCubicEmphasized;

  static const fontFamily = 'Inter';
}
