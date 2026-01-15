import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../common/glass_card.dart';
import '../common/gradient_icon_blob.dart';

class QuickAccessItem {
  final String label;
  final IconData icon;
  final String route;
  final LinearGradient gradient;

  QuickAccessItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.gradient,
  });
}

class QuickAccessV2 extends StatelessWidget {
  final String userRole; // 'client', 'trainer', 'nutritionist'

  const QuickAccessV2({
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
            gradient: DesignTokens.secondaryGradient,
          ),
          QuickAccessItem(
            label: 'Video Sessions',
            icon: Icons.video_camera_front_outlined,
            route: '/home/video-sessions',
            gradient: LinearGradient(
              colors: [DesignTokens.accentBlue, DesignTokens.accentPurple],
            ),
          ),
          QuickAccessItem(
            label: 'Meal Tracker',
            icon: Icons.restaurant_outlined,
            route: '/home/meal-tracker',
            gradient: DesignTokens.primaryGradient,
          ),
          QuickAccessItem(
            label: 'Messages',
            icon: Icons.message_outlined,
            route: '/home/messages',
            gradient: LinearGradient(
              colors: [DesignTokens.accentPurple, DesignTokens.accentBlue],
            ),
          ),
        ];
      case 'nutritionist':
        return [
          QuickAccessItem(
            label: 'Meal Review',
            icon: Icons.restaurant_menu_outlined,
            route: '/home/meal-review',
            gradient: DesignTokens.primaryGradient,
          ),
          QuickAccessItem(
            label: 'Video Sessions',
            icon: Icons.video_camera_front_outlined,
            route: '/home/video-sessions',
            gradient: LinearGradient(
              colors: [DesignTokens.accentBlue, DesignTokens.accentPurple],
            ),
          ),
          QuickAccessItem(
            label: 'Messages',
            icon: Icons.message_outlined,
            route: '/home/messages',
            gradient: LinearGradient(
              colors: [DesignTokens.accentPurple, DesignTokens.accentBlue],
            ),
          ),
        ];
      default: // client
        return [
          QuickAccessItem(
            label: 'Meal Tracker',
            icon: Icons.restaurant_outlined,
            route: '/home/meal-tracker',
            gradient: DesignTokens.primaryGradient,
          ),
          QuickAccessItem(
            label: 'Messages',
            icon: Icons.message_outlined,
            route: '/home/messages',
            gradient: LinearGradient(
              colors: [DesignTokens.accentPurple, DesignTokens.accentBlue],
            ),
          ),
          QuickAccessItem(
            label: 'AI Planner',
            icon: Icons.auto_awesome_outlined,
            route: '/home/ai-planner',
            gradient: LinearGradient(
              colors: [DesignTokens.accentBlue, DesignTokens.accentPurple],
            ),
          ),
          QuickAccessItem(
            label: 'Challenges',
            icon: Icons.emoji_events_outlined,
            route: '/home/challenges',
            gradient: LinearGradient(
              colors: [DesignTokens.accentGreen, DesignTokens.accentBlue],
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _getItemsForRole(userRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
          child: Row(
            children: [
              Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeH2,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.textPrimary,
                ),
              ),
              SizedBox(width: DesignTokens.spacing8),
              Icon(
                Icons.bolt_outlined,
                size: DesignTokens.iconSizeTile,
                color: DesignTokens.textSecondary,
              ),
            ],
          ),
        ),
        SizedBox(height: DesignTokens.spacing12),
        // Grid 2x2 shrinkWrap
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
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
                child: _QuickAccessTile(item: items[index]),
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

  const _QuickAccessTile({required this.item});

  @override
  State<_QuickAccessTile> createState() => _QuickAccessTileState();
}

class _QuickAccessTileState extends State<_QuickAccessTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        context.push(widget.item.route);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Transform.scale(
        scale: _isPressed ? 0.97 : 1.0,
        child: GlassCard(
          padding: EdgeInsets.all(DesignTokens.spacing16),
          onTap: null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GradientIconBlob(
                icon: widget.item.icon,
                gradient: widget.item.gradient,
                size: 48,
                iconSize: DesignTokens.iconSizeTile,
              ),
              SizedBox(height: DesignTokens.spacing8),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.textPrimary,
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



