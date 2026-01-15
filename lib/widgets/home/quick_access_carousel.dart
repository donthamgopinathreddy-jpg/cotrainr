import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class QuickAccessItem {
  final String label;
  final IconData icon;
  final String route;

  QuickAccessItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

class QuickAccessCarousel extends StatelessWidget {
  final String userRole; // 'client', 'trainer', 'nutritionist'

  const QuickAccessCarousel({
    super.key,
    this.userRole = 'client',
  });

  List<QuickAccessItem> _getItemsForRole(String role) {
    switch (role) {
      case 'trainer':
        return [
          QuickAccessItem(
            label: 'Client Stats',
            icon: Icons.analytics_outlined,
            route: '/home/client-stats',
          ),
          QuickAccessItem(
            label: 'Video Sessions',
            icon: Icons.video_camera_front_outlined,
            route: '/home/video-sessions',
          ),
          QuickAccessItem(
            label: 'Meal Tracker',
            icon: Icons.restaurant_outlined,
            route: '/home/meal-tracker',
          ),
          QuickAccessItem(
            label: 'Messages',
            icon: Icons.message_outlined,
            route: '/home/messages',
          ),
        ];
      case 'nutritionist':
        return [
          QuickAccessItem(
            label: 'Meal Review',
            icon: Icons.restaurant_menu_outlined,
            route: '/home/meal-review',
          ),
          QuickAccessItem(
            label: 'Video Sessions',
            icon: Icons.video_camera_front_outlined,
            route: '/home/video-sessions',
          ),
          QuickAccessItem(
            label: 'Messages',
            icon: Icons.message_outlined,
            route: '/home/messages',
          ),
        ];
      default: // client
        return [
          QuickAccessItem(
            label: 'Meal Tracker',
            icon: Icons.restaurant_outlined,
            route: '/home/meal-tracker',
          ),
          QuickAccessItem(
            label: 'Messages',
            icon: Icons.message_outlined,
            route: '/home/messages',
          ),
          QuickAccessItem(
            label: 'AI Planner',
            icon: Icons.auto_awesome_outlined,
            route: '/home/ai-planner',
          ),
          QuickAccessItem(
            label: 'Video Sessions',
            icon: Icons.video_camera_front_outlined,
            route: '/home/video-sessions',
          ),
          QuickAccessItem(
            label: 'Become a Trainer',
            icon: Icons.school_outlined,
            route: '/home/become-trainer',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _getItemsForRole(userRole);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E)
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'Quick access',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 200 + (index * 50)),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _QuickAccessTile(
                  item: items[index],
                  surfaceColor: surfaceColor,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatefulWidget {
  final QuickAccessItem item;
  final Color surfaceColor;

  const _QuickAccessTile({
    required this.item,
    required this.surfaceColor,
  });

  @override
  State<_QuickAccessTile> createState() => _QuickAccessTileState();
}

class _QuickAccessTileState extends State<_QuickAccessTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        context.push(widget.item.route);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: Transform.scale(
        scale: _isPressed ? 0.98 : 1.0,
        child: Container(
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.item.icon,
                  color: const Color(0xFFFF6B35),
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}





