import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../repositories/meal_repository.dart';
import '../../providers/unread_messages_count_provider.dart';

/// Compact home hints when the same features exist in bottom navigation (MVP).
class HomeNavHintCards extends ConsumerStatefulWidget {
  final VoidCallback? onOpenMessagesTab;
  final VoidCallback? onOpenMealsTab;

  const HomeNavHintCards({
    super.key,
    this.onOpenMessagesTab,
    this.onOpenMealsTab,
  });

  @override
  ConsumerState<HomeNavHintCards> createState() => _HomeNavHintCardsState();
}

class _HomeNavHintCardsState extends ConsumerState<HomeNavHintCards> {
  DayMealsData? _todayMeals;
  bool _mealsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    try {
      final data = await MealRepository().getDayMeals(DateTime.now());
      if (mounted) {
        setState(() {
          _todayMeals = data;
          _mealsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _mealsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadState = ref.watch(unreadMessagesCountProvider);
    final unreadCount = unreadState.maybeWhen(data: (v) => v, orElse: () => 0);

    final children = <Widget>[];

    if (unreadCount > 0 && widget.onOpenMessagesTab != null) {
      children.add(_HintCard(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Messages',
        subtitle: '$unreadCount unread',
        color: AppColors.blue,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onOpenMessagesTab!();
        },
      ));
    }

    if (_mealsLoaded &&
        _todayMeals != null &&
        _todayMeals!.totalCalories > 0 &&
        widget.onOpenMealsTab != null) {
      children.add(_HintCard(
        icon: Icons.restaurant_rounded,
        title: 'Meals today',
        subtitle:
            '${_todayMeals!.totalCalories} kcal · P ${_todayMeals!.totalProtein.toStringAsFixed(0)}g · C ${_todayMeals!.totalCarbs.toStringAsFixed(0)}g · F ${_todayMeals!.totalFats.toStringAsFixed(0)}g',
        color: AppColors.green,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onOpenMealsTab!();
        },
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
