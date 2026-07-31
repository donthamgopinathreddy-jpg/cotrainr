import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';
import 'provider_avatar.dart';

/// Summary model for Discover provider cards (trainers + nutritionists).
class DiscoverProviderCardData {
  final String id;
  final String name;
  final String roleLabel;
  final String? headline;
  final List<String> specialtyChips;
  final double rating;
  final int reviewCount;
  final int? experienceYears;
  final List<String> sessionModeLabels;
  final String? distanceOrLocation;
  final bool verified;
  final bool offersOnline;
  final String? avatarUrl;
  /// none | pending | accepted
  final String requestStatus;

  const DiscoverProviderCardData({
    required this.id,
    required this.name,
    required this.roleLabel,
    this.headline,
    this.specialtyChips = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.experienceYears,
    this.sessionModeLabels = const [],
    this.distanceOrLocation,
    this.verified = false,
    this.offersOnline = false,
    this.avatarUrl,
    this.requestStatus = 'none',
  });
}

/// Shared Discover card for trainers and nutritionists.
class DiscoverProviderCard extends StatefulWidget {
  final DiscoverProviderCardData data;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onRequest;
  final VoidCallback? onCancelRequest;
  final bool submitting;

  const DiscoverProviderCard({
    super.key,
    required this.data,
    required this.accentColor,
    required this.onTap,
    this.onRequest,
    this.onCancelRequest,
    this.submitting = false,
  });

  @override
  State<DiscoverProviderCard> createState() => _DiscoverProviderCardState();
}

class _DiscoverProviderCardState extends State<DiscoverProviderCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = widget.data;
    final isPending = d.requestStatus == 'pending';

    return AnimatedScale(
      scale: _pressed ? 0.99 : 1,
      duration: const Duration(milliseconds: 130),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: widget.accentColor.withValues(alpha: 0.12),
          highlightColor: widget.accentColor.withValues(alpha: 0.06),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? const Color(0xFFEEF0F3)
                  : cs.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.light
                        ? 0.04
                        : 0.28,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProviderAvatar(
                      imageUrl: d.avatarUrl,
                      name: d.name,
                      size: 68,
                      borderRadius: 16,
                      verified: d.verified,
                      roleIcon: d.roleLabel.toLowerCase().contains('nutrition')
                          ? Icons.restaurant_rounded
                          : Icons.fitness_center_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.roleLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.accentColor,
                            ),
                          ),
                          if ((d.headline ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              d.headline!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (d.reviewCount > 0)
                                _MetaChip(
                                  icon: Icons.star_rounded,
                                  label:
                                      '${d.rating.toStringAsFixed(1)} (${d.reviewCount})',
                                  color: DesignTokens.accentOrange,
                                )
                              else
                                _MetaChip(
                                  icon: Icons.star_outline_rounded,
                                  label: 'New',
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              if (d.experienceYears != null &&
                                  d.experienceYears! > 0)
                                _MetaChip(
                                  icon: Icons.timeline_rounded,
                                  label: '${d.experienceYears}y exp',
                                  color: cs.onSurface.withValues(alpha: 0.65),
                                ),
                              if (d.offersOnline)
                                _MetaChip(
                                  icon: Icons.wifi_rounded,
                                  label: 'Online',
                                  color: const Color(0xFF2EBD85),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (d.specialtyChips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: d.specialtyChips.take(3).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (d.sessionModeLabels.isNotEmpty ||
                    (d.distanceOrLocation ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (d.sessionModeLabels.isNotEmpty)
                        Expanded(
                          child: Text(
                            d.sessionModeLabels.take(2).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      if ((d.distanceOrLocation ?? '').isNotEmpty)
                        Text(
                          d.distanceOrLocation!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: isPending
                      ? OutlinedButton(
                          onPressed: widget.submitting
                              ? null
                              : widget.onCancelRequest,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.accentColor,
                            side: BorderSide.none,
                            backgroundColor:
                                widget.accentColor.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(
                            widget.submitting ? 'Updating…' : 'Pending · Cancel',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      : FilledButton(
                          onPressed:
                              widget.submitting ? null : widget.onRequest,
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.accentColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(
                            widget.submitting
                                ? 'Sending…'
                                : 'Request',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
