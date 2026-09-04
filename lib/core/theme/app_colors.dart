// App-wide color palette and design tokens
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF3D35CC);

  // Accent
  static const Color accent = Color(0xFF00D9A3);
  static const Color accentDark = Color(0xFF00A87D);

  // Semantic
  static const Color income = Color(0xFF00C896);
  static const Color expense = Color(0xFFFF5C7A);
  static const Color transfer = Color(0xFF5BA4FF);
  static const Color savings = Color(0xFF9B8FFF);

  // Dark theme surfaces
  static const Color darkBg = Color(0xFF0D0E1A);
  static const Color darkSurface = Color(0xFF161829);
  static const Color darkCard = Color(0xFF1E2138);
  static const Color darkCardAlt = Color(0xFF252840);
  static const Color darkBorder = Color(0xFF2E3150);
  static const Color darkText = Color(0xFFE8EAFF);
  static const Color darkTextSecondary = Color(0xFF8890B8);
  static const Color darkTextMuted = Color(0xFF555D80);

  // Light theme surfaces
  static const Color lightBg = Color(0xFFF4F5FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE0E3FF);
  static const Color lightText = Color(0xFF0D0E1A);
  static const Color lightTextSecondary = Color(0xFF5A6080);
  static const Color lightTextMuted = Color(0xFF9BA0BE);

  // Chart palette
  static const List<Color> chartColors = [
    Color(0xFF6C63FF),
    Color(0xFF00D9A3),
    Color(0xFFFF5C7A),
    Color(0xFFFFB84D),
    Color(0xFF5BA4FF),
    Color(0xFFFF79C6),
    Color(0xFF8BE9FD),
    Color(0xFF50FA7B),
    Color(0xFFFFD166),
    Color(0xFFEF7C8E),
  ];

  // Account default colors
  static const List<Color> accountColors = [
    Color(0xFF6C63FF),
    Color(0xFF00D9A3),
    Color(0xFFFF5C7A),
    Color(0xFFFFB84D),
    Color(0xFF5BA4FF),
    Color(0xFFFF79C6),
    Color(0xFF50FA7B),
    Color(0xFFEF7C8E),
  ];
}
