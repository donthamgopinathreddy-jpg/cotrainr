import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home_v3/home_premium_theme.dart';
import '../common/pressable_card.dart';
import '../trainer/trainer_overview_section.dart';
import '../trainer/trainer_theme.dart';

class NutritionistOverviewSection extends StatelessWidget {
  final int totalClients;
  final int pendingRequests;
  final List<TrainerClientPreview> recentClients;
  final VoidCallback? onViewAllClients;

  const NutritionistOverviewSection({
    super.key,
    required this.totalClients,
    required this.pendingRequests,
    this.recentClients = const [],
    this.onViewAllClients,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(isLight, 'Your practice'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Clients',
                value: '$totalClients',
                icon: Icons.people_rounded,
                isLight: isLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Pending',
                value: '$pendingRequests',
                icon: Icons.person_add_alt_1_rounded,
                isLight: isLight,
                highlight: pendingRequests > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PressableCard(
                borderRadius: 16,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/nutrition-goals');
                },
                child: _ActionChip(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Nutrition plans',
                  isLight: isLight,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PressableCard(
                borderRadius: 16,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/video');
                },
                child: _ActionChip(
                  icon: Icons.videocam_rounded,
                  label: 'Video sessions',
                  isLight: isLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PressableCard(
          borderRadius: 16,
          onTap: onViewAllClients == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onViewAllClients!();
                },
          child: _ActionChip(
            icon: Icons.groups_rounded,
            label: 'All clients',
            isLight: isLight,
            fullWidth: true,
          ),
        ),
        if (recentClients.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Recent',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomePremiumTheme.primaryText(isLight),
                ),
              ),
              const Spacer(),
              if (onViewAllClients != null)
                TextButton(
                  onPressed: onViewAllClients,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: TrainerTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...recentClients.take(3).map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ClientPreviewRow(client: c, isLight: isLight),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(bool isLight, String title) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (b) => TrainerTheme.gradient.createShader(b),
          child: const Icon(Icons.restaurant_menu_rounded, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: TrainerTheme.gradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HomePremiumTheme.primaryText(isLight),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isLight;
  final bool highlight;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.isLight,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: highlight ? TrainerTheme.gradient : null,
        color: highlight
            ? null
            : (isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard),
        borderRadius: BorderRadius.circular(16),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: highlight ? Colors.white : TrainerTheme.accent,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? Colors.white
                  : HomePremiumTheme.primaryText(isLight),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight
                  ? Colors.white.withValues(alpha: 0.9)
                  : HomePremiumTheme.secondaryText(isLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLight;
  final bool fullWidth;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.isLight,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TrainerTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: HomePremiumTheme.primaryText(isLight),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientPreviewRow extends StatelessWidget {
  final TrainerClientPreview client;
  final bool isLight;

  const _ClientPreviewRow({required this.client, required this.isLight});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      borderRadius: 14,
      onTap: () {
        HapticFeedback.lightImpact();
        if (client.id.isNotEmpty) {
          context.push('/nutritionist/clients/${client.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : HomePremiumTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: HomePremiumTheme.softCardShadow(isLight),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: TrainerTheme.accent.withValues(alpha: 0.15),
              backgroundImage:
                  client.avatarUrl != null ? NetworkImage(client.avatarUrl!) : null,
              child: client.avatarUrl == null
                  ? Text(
                      client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: TrainerTheme.accent,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: HomePremiumTheme.primaryText(isLight),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    client.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: HomePremiumTheme.secondaryText(isLight),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (client.isPending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9500),
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: HomePremiumTheme.secondaryText(isLight),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
