import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../common/pressable_card.dart';

class QuickAccessV3 extends StatelessWidget {
  const QuickAccessV3({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      _QuickTileData('MEAL TRACKER', Icons.restaurant_rounded,
          const LinearGradient(colors: [AppColors.green, Color(0xFF65E6B3)])),
      _QuickTileData('MESSAGING', Icons.chat_bubble_outline_rounded,
          const LinearGradient(colors: [AppColors.blue, AppColors.cyan])),
      _QuickTileData('VIDEO SESSIONS', Icons.videocam_rounded,
          const LinearGradient(colors: [AppColors.purple, Color(0xFFB38CFF)])),
      _QuickTileData('AI PLANNER', Icons.auto_awesome_rounded,
          const LinearGradient(colors: [AppColors.orange, AppColors.yellow])),
      _QuickTileData('BECOME A TRAINER', Icons.school_rounded,
          const LinearGradient(colors: [AppColors.orange, AppColors.pink])),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeSection,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              VoidCallback? onTap;
              if (item.title == 'MESSAGING') {
                onTap = () => context.push('/messaging');
              }
              return _QuickTile(item: item, onTap: onTap);
            },
          ),
        ),
      ],
    );
  }
}

class _QuickTileData {
  final String title;
  final IconData icon;
  final LinearGradient gradient;

  _QuickTileData(this.title, this.icon, this.gradient);
}

class _QuickTile extends StatelessWidget {
  final _QuickTileData item;
  final VoidCallback? onTap;

  const _QuickTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      borderRadius: 28,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: item.gradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const Spacer(),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
