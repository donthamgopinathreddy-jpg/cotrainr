import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../common/pressable_card.dart';

class QuickAccessV3 extends StatelessWidget {
  const QuickAccessV3({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Get user role from Supabase
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final userRole = user?.userMetadata?['role']?.toString().toLowerCase() ?? 'client';
    
    // Filter items based on role
    final itemsToExclude = <String>[];
    
    // For trainers and nutritionists, exclude these tiles
    if (userRole == 'trainer' || userRole == 'nutritionist') {
      itemsToExclude.addAll(['BECOME A TRAINER', 'SUBSCRIPTION', 'AI PLANNER']);
    }
    
    final allItems = [
      _QuickTileData('MEAL TRACKER', Icons.restaurant_rounded,
          const LinearGradient(colors: [AppColors.green, Color(0xFF65E6B3)])),
      _QuickTileData('MESSAGING', Icons.chat_bubble_outline_rounded,
          const LinearGradient(colors: [AppColors.blue, AppColors.cyan])),
      _QuickTileData('VIDEO SESSIONS', Icons.videocam_rounded,
          const LinearGradient(colors: [AppColors.purple, Color(0xFFB38CFF)])),
      if (!itemsToExclude.contains('AI PLANNER'))
        _QuickTileData('AI PLANNER', Icons.auto_awesome_rounded,
            const LinearGradient(colors: [AppColors.orange, AppColors.yellow])),
      if (!itemsToExclude.contains('BECOME A TRAINER'))
        _QuickTileData('BECOME A TRAINER', Icons.school_rounded,
            const LinearGradient(colors: [AppColors.orange, AppColors.pink])),
      if (!itemsToExclude.contains('SUBSCRIPTION'))
        _QuickTileData('SUBSCRIPTION', Icons.card_membership_rounded,
            const LinearGradient(colors: [AppColors.purple, AppColors.pink])),
    ];
    
    final items = allItems;

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
              bool showBadge = false;
              if (item.title == 'MEAL TRACKER') {
                onTap = () => context.push('/meal-tracker');
              } else if (item.title == 'MESSAGING') {
                onTap = () => context.push('/messaging');
              } else if (item.title == 'BECOME A TRAINER') {
                onTap = () => context.push('/trainer/become');
              } else if (item.title == 'VIDEO SESSIONS') {
                // Navigate based on user role
                if (userRole == 'trainer') {
                  onTap = () => context.push('/video?role=trainer');
                } else if (userRole == 'nutritionist') {
                  onTap = () => context.push('/video?role=nutritionist');
                } else {
                  onTap = () => context.push('/video?role=client');
                }
              }
              return _QuickTile(item: item, onTap: onTap, showBadge: showBadge);
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
  final bool showBadge;

  const _QuickTile({required this.item, this.onTap, this.showBadge = false});

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
            Stack(
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
                if (showBadge)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
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
