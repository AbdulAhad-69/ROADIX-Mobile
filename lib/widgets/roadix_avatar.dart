import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared avatar widget and image-provider resolver handling local bytes preview,
/// `data:` base64 URIs, Cloudinary / Supabase Storage `https:` URLs, asset paths,
/// and accessible monogram fallback on error.
class RoadixAvatar extends StatefulWidget {
  final String? avatarUrl;
  final Uint8List? localBytes;
  final String displayName;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showInitialFallback;

  const RoadixAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.localBytes,
    this.radius = 28,
    this.backgroundColor = AppColors.crimsonLight,
    this.foregroundColor = AppColors.crimsonHover,
    this.showInitialFallback = true,
  });

  static ImageProvider? resolveProvider({
    String? avatarUrl,
    Uint8List? localBytes,
  }) {
    if (localBytes != null && localBytes.isNotEmpty) {
      return MemoryImage(localBytes);
    }
    final url = avatarUrl?.trim() ?? '';
    if (url.isEmpty) return null;

    if (url.startsWith('data:image/') && url.contains(';base64,')) {
      try {
        final b64 = url.split(';base64,').last;
        return MemoryImage(base64Decode(b64));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return null;
  }

  @override
  State<RoadixAvatar> createState() => _RoadixAvatarState();
}

class _RoadixAvatarState extends State<RoadixAvatar> {
  bool _loadFailed = false;

  @override
  void didUpdateWidget(covariant RoadixAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl ||
        oldWidget.localBytes != widget.localBytes) {
      _loadFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _loadFailed
        ? null
        : RoadixAvatar.resolveProvider(
            avatarUrl: widget.avatarUrl,
            localBytes: widget.localBytes,
          );
    final trimmedName = widget.displayName.trim();
    final initial =
        trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '';

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      backgroundImage: provider,
      onBackgroundImageError: provider != null
          ? (_, _) {
              if (mounted) setState(() => _loadFailed = true);
            }
          : null,
      child: provider == null
          ? (widget.showInitialFallback && initial.isNotEmpty
              ? Text(
                  initial,
                  style: TextStyle(
                    color: widget.foregroundColor,
                    fontSize: widget.radius * 0.72,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : Icon(
                  Icons.person,
                  color: widget.foregroundColor,
                  size: widget.radius,
                ))
          : null,
    );
  }
}
