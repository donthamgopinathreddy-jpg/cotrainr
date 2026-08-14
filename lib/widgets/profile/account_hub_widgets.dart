import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/account_hub_theme.dart';
import '../common/pressable_card.dart';

class HubSectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final int animationDelayMs;

  const HubSectionCard({
    super.key,
    this.title,
    required this.child,
    this.animationDelayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + animationDelayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AccountHubTheme.cardBg(context),
          borderRadius: BorderRadius.circular(AccountHubTheme.sectionRadius),
          boxShadow: AccountHubTheme.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: AccountHubTheme.sectionTitle(context)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class HubActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final int animationDelayMs;

  const HubActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.animationDelayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: subtitle != null ? 60 : AccountHubTheme.rowHeight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: subtitle != null ? 8 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AccountHubTheme.iconSize,
              color: iconColor ?? cs.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AccountHubTheme.rowTitle(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AccountHubTheme.rowSubtitle(context),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron)
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + animationDelayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: onTap == null
          ? content
          : PressableCard(
              onTap: onTap,
              borderRadius: 14,
              pressScale: 0.98,
              child: content,
            ),
    );
  }
}

class HubCompactStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const HubCompactStat({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AccountHubTheme.rowSubtitle(context)),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            style: AccountHubTheme.rowTitle(context).copyWith(fontSize: 14),
            children: [
              TextSpan(text: value),
              if (unit != null && unit!.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: AccountHubTheme.rowSubtitle(context),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class HubCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const HubCtaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return PressableCard(
      onTap: onTap,
      borderRadius: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class ComingSoonBadge extends StatelessWidget {
  const ComingSoonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Coming soon',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class HubToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const HubToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: enabled ? onChanged : null,
          title: Text(title, style: AccountHubTheme.rowTitle(context)),
          subtitle: subtitle != null
              ? Text(subtitle!, style: AccountHubTheme.rowSubtitle(context))
              : null,
        ),
      ),
    );
  }
}

class HubDangerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const HubDangerButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      borderRadius: AccountHubTheme.cardRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AccountHubTheme.dangerRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
          border: Border.all(
            color: AccountHubTheme.dangerRed.withValues(alpha: 0.35),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AccountHubTheme.dangerRed,
            ),
          ),
        ),
      ),
    );
  }
}

class HubLogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const HubLogoutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableCard(
      onTap: onTap,
      borderRadius: AccountHubTheme.cardRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AccountHubTheme.cardRadius),
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded,
                size: 18, color: cs.onSurface.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PulsingRoleBadge extends StatefulWidget {
  final String label;
  final LinearGradient gradient;

  const PulsingRoleBadge({
    super.key,
    required this.label,
    required this.gradient,
  });

  @override
  State<PulsingRoleBadge> createState() => _PulsingRoleBadgeState();
}

class _PulsingRoleBadgeState extends State<PulsingRoleBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glow = Tween<double>(begin: 0.08, end: 0.28).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _ctrl.stop();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: _glow.value),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class VerifiedProviderBadge extends StatelessWidget {
  const VerifiedProviderBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AccountHubTheme.goalsGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AccountHubTheme.goalsGreen.withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded,
              size: 14, color: AccountHubTheme.goalsGreen),
          SizedBox(width: 6),
          Text(
            'VERIFIED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AccountHubTheme.goalsGreen,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showHubConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool isDanger = false,
}) async {
  HapticFeedback.mediumImpact();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDanger ? AccountHubTheme.dangerRed : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showHubSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
