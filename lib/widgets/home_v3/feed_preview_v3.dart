import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../common/pressable_card.dart';

class FeedPreviewV3 extends StatefulWidget {
  const FeedPreviewV3({super.key});

  @override
  State<FeedPreviewV3> createState() => _FeedPreviewV3State();
}

class _FeedPreviewV3State extends State<FeedPreviewV3> {
  bool _isFollowing = false;

  static const _feedGradient = LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Community Feed',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSection,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.cardShadowOf(context),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'fitness_john • 2h ago',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  PressableCard(
                    onTap: () => setState(() => _isFollowing = !_isFollowing),
                    borderRadius: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: _isFollowing ? null : _feedGradient,
                        color: _isFollowing ? cs.surfaceContainerHighest : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isFollowing
                              ? cs.onSurface
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.more_horiz,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.favorite_border, color: cs.onSurface),
                  const SizedBox(width: 12),
                  Icon(Icons.mode_comment_outlined, color: cs.onSurface),
                  const Spacer(),
                  Icon(Icons.bookmark_border, color: cs.onSurface),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
