import 'package:flutter/material.dart';
import '../core/platform/platform_helpers.dart';
import '../models/models.dart';

class AccountIcon extends StatelessWidget {
  final Account? account;
  final String? emoji;
  final String? imagePath;
  final double size;
  final double? fontSize;
  final BorderRadius? borderRadius;
  final String defaultEmoji;

  const AccountIcon({
    super.key,
    this.account,
    this.emoji,
    this.imagePath,
    this.size = 24,
    this.fontSize,
    this.borderRadius,
    this.defaultEmoji = '💳',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveImagePath = imagePath ?? account?.imagePath;
    final effectiveEmoji = (emoji != null && emoji!.isNotEmpty)
        ? emoji!
        : (account?.emoji != null && account!.emoji.isNotEmpty ? account!.emoji : defaultEmoji);

    if (effectiveImagePath != null && effectiveImagePath.isNotEmpty) {
      final provider = localImageProvider(effectiveImagePath);
      if (provider != null) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(size * 0.25),
          child: Image(
            image: provider,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildEmojiFallback(effectiveEmoji),
          ),
        );
      }
    }

    return _buildEmojiFallback(effectiveEmoji);
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
