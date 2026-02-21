import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../repositories/messages_repository.dart';
import '../common/pressable_card.dart';

final unreadMessagesCountProvider = FutureProvider<int>((ref) async {
  final messagesRepo = MessagesRepository();
  return await messagesRepo.getUnreadMessagesCount();
});

class QuickAccessV3 extends ConsumerWidget {
  const QuickAccessV3({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    
    // Get user role from Supabase
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final userRole = user?.userMetadata?['role']?.toString().toLowerCase() ?? 'client';
    
    // Filter items based on role
    final itemsToExclude = <String>[];
    
    // For trainers and nutritionists, exclude these tiles
    if (userRole == 'trainer' || userRole == 'nutritionist') {
      itemsToExclude.addAll(['BECOME A TRAINER', 'SUBSCRIPTION', 'AI PLANNER', 'NOTES']);
    }
    
    final allItems = [
      _QuickTileData('MEAL TRACKER', Icons.restaurant_rounded,
          const LinearGradient(colors: [AppColors.green, Color(0xFF65E6B3)])),
      _QuickTileData('MESSAGING', Icons.chat_bubble_outline_rounded,
          const LinearGradient(colors: [AppColors.blue, AppColors.cyan])),
      if (!itemsToExclude.contains('NOTES'))
        _QuickTileData('COACH NOTES', Icons.note_rounded,
            const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFE96A6A)])),
      _QuickTileData('VIDEO SESSIONS', Icons.videocam_rounded,
          const LinearGradient(colors: [AppColors.purple, Color(0xFFB38CFF)])),
      if (!itemsToExclude.contains('AI PLANNER'))
        _QuickTileData('AI PLANNER', Icons.auto_awesome_rounded,
            const LinearGradient(colors: [AppColors.orange, AppColors.yellow])),
      if (!itemsToExclude.contains('BECOME A TRAINER'))
        _QuickTileData('BECOME A TRAINER', Icons.school_rounded,
            AppColors.becomeTrainerGradient),
      if (!itemsToExclude.contains('SUBSCRIPTION'))
        _QuickTileData('SUBSCRIPTION', Icons.card_membership_rounded,
            const LinearGradient(colors: [AppColors.purple, AppColors.pink])),
    ];
    
    final items = allItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.blue, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                Icons.bolt_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.purple, AppColors.blue],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: GoogleFonts.montserrat(
                fontSize: DesignTokens.fontSizeSection,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: List.generate(items.length, (index) {
            final item = items[index];
            VoidCallback? onTap;
            bool showBadge = false;
            int? badgeCount;
            if (item.title == 'MEAL TRACKER') {
              onTap = () => context.push('/meal-tracker');
            } else if (item.title == 'MESSAGING') {
              onTap = () => context.push('/messaging');
              final unreadCountAsync = ref.watch(unreadMessagesCountProvider);
              unreadCountAsync.whenData((count) {
                showBadge = count > 0;
                badgeCount = count > 0 ? count : null;
              });
            } else if (item.title == 'AI PLANNER') {
              onTap = () => context.push('/ai-planner');
            } else if (item.title == 'BECOME A TRAINER') {
              onTap = () => context.push('/trainer/become');
            } else if (item.title == 'COACH NOTES') {
              onTap = () => context.push('/coach-notes');
            } else if (item.title == 'VIDEO SESSIONS') {
              onTap = () => context.push('/video');
            }
            if (item.title == 'MESSAGING') {
              final unreadCountAsync = ref.watch(unreadMessagesCountProvider);
              return unreadCountAsync.when(
                data: (count) => _QuickTile(
                  item: item,
                  onTap: onTap,
                  showBadge: count > 0,
                  badgeCount: count > 0 ? count : null,
                ),
                loading: () => _QuickTile(item: item, onTap: onTap, showBadge: false),
                error: (_, __) => _QuickTile(item: item, onTap: onTap, showBadge: false),
              );
            }
            return _QuickTile(item: item, onTap: onTap, showBadge: showBadge, badgeCount: badgeCount);
          }),
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
  final int? badgeCount;

  const _QuickTile({required this.item, this.onTap, this.showBadge = false, this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      borderRadius: 999,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: item.gradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: badgeCount != null && badgeCount! > 9
                          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                          : const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: badgeCount != null && badgeCount! > 9
                          ? const Text(
                              '9+',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : badgeCount != null
                              ? Text(
                                  '$badgeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
