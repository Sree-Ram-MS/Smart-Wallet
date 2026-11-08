import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/platform/platform_helpers.dart';
import '../core/theme/app_colors.dart';
import '../models/models.dart';

class UserAvatar extends StatelessWidget {
  final UserProfile? user;
  final String? photoUrl;
  final String? name;
  final double radius;
  final VoidCallback? onEdit;
  final bool showEditBadge;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const UserAvatar({
    super.key,
    this.user,
    this.photoUrl,
    this.name,
    this.radius = 24,
    this.onEdit,
    this.showEditBadge = false,
    this.backgroundColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePhoto = photoUrl ?? user?.photoUrl ?? '';
    final effectiveName = name ?? user?.name ?? 'Guest';
    final initial = effectiveName.trim().isNotEmpty
        ? effectiveName.trim()[0].toUpperCase()
        : 'G';

    ImageProvider? imageProvider;
    if (effectivePhoto.isNotEmpty) {
      if (effectivePhoto.startsWith('http://') || effectivePhoto.startsWith('https://')) {
        imageProvider = CachedNetworkImageProvider(effectivePhoto);
      } else {
        imageProvider = localImageProvider(effectivePhoto);
      }
    }

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              initial,
              style: textStyle ??
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.75,
                  ),
            )
          : null,
    );

    if (!showEditBadge && onEdit == null) {
      return avatar;
    }

    return GestureDetector(
      onTap: onEdit,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(radius * 0.14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: radius * 0.45,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
