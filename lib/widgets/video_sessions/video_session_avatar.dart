import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'video_session_theme.dart';

/// Circular profile photo for Video Sessions. Falls back to initial only
/// when [imageUrl] is empty or fails to load.
class VideoSessionAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;

  const VideoSessionAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = VideoSessionUi.avatarSize,
  });

  String get _initial {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '?';
    return raw.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final hasImage = url.isNotEmpty;
    return Semantics(
      label: name == null || name!.trim().isEmpty
          ? 'Participant'
          : 'Participant ${name!.trim()}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: VideoSessionUi.border(context),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                fadeInDuration: VideoSessionUi.motion(context),
                placeholder: (_, __) => _Fallback(size: size, initial: _initial),
                errorWidget: (_, __, ___) =>
                    _Fallback(size: size, initial: _initial),
              )
            : _Fallback(size: size, initial: _initial),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final double size;
  final String initial;

  const _Fallback({required this.size, required this.initial});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DesignTokens.videoSessionsAccent.withValues(alpha: 0.14),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: DesignTokens.videoSessionsAccent,
          ),
        ),
      ),
    );
  }
}

class VideoSessionAvatarStack extends StatelessWidget {
  final List<({String? name, String? imageUrl})> people;
  final int extra;

  const VideoSessionAvatarStack({
    super.key,
    required this.people,
    this.extra = 0,
  });

  @override
  Widget build(BuildContext context) {
    final shown = people.take(3).toList();
    return SizedBox(
      height: 28,
      width: 28.0 + (shown.length - 1) * 16 + (extra > 0 ? 20 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 16.0,
              child: VideoSessionAvatar(
                name: shown[i].name,
                imageUrl: shown[i].imageUrl,
                size: 28,
              ),
            ),
        ],
      ),
    );
  }
}
