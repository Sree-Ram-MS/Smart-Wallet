import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';

class CategoryIcon extends StatelessWidget {
  final Category? category;
  final String? icon;
  final String? imagePath;
  final double size;
  final double? fontSize;
  final BorderRadius? borderRadius;
  final String defaultEmoji;

  const CategoryIcon({
    super.key,
    this.category,
    this.icon,
    this.imagePath,
    this.size = 24,
    this.fontSize,
    this.borderRadius,
    this.defaultEmoji = '📦',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveImagePath = imagePath ?? category?.imagePath;
    final effectiveIcon = (icon != null && icon!.isNotEmpty)
        ? icon!
        : (category?.icon != null && category!.icon.isNotEmpty ? category!.icon : defaultEmoji);

    // Check if custom image path is provided and exists
    if (effectiveImagePath != null && effectiveImagePath.isNotEmpty) {
      final file = File(effectiveImagePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(size * 0.25),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => _buildEmojiFallback(effectiveIcon),
          ),
        );
      }
    }

    // Check if icon string itself is a file path
    if (effectiveIcon.startsWith('/') || effectiveIcon.contains('\\') || effectiveIcon.startsWith('file:')) {
      final cleanPath = effectiveIcon.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(size * 0.25),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => _buildEmojiFallback(defaultEmoji),
          ),
        );
      }
    }

    return _buildEmojiFallback(effectiveIcon);
  }

  Widget _buildEmojiFallback(String emoji) {
    return Text(
      emoji,
      style: TextStyle(
        fontSize: fontSize ?? (size * 0.8),
      ),
      textAlign: TextAlign.center,
    );
  }
}
