import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class QuickAccessV3 extends StatelessWidget {
  const QuickAccessV3({super.key});

  @override
  Widget build(BuildContext context) {
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
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
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
              return _QuickTile(item: item);
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

class _QuickTile extends StatefulWidget {
  final _QuickTileData item;

  const _QuickTile({required this.item});

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: widget.item.gradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.item.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                widget.item.title,
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
      ),
    );
  }
}
