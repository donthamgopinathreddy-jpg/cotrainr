import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription_plans.dart';
import '../../providers/entitlements_provider.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../services/entitlement_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/profile/account_hub_widgets.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  static const _accent = DesignTokens.accentOrange;

  static const _freeBenefits = [
    'Browse trainers & nutritionists in Discover',
    '5 new Trainer connections per month',
    'Unlimited messaging with accepted providers',
    'Nutritionists available on Basic & Ultimate',
  ];

  static const _basicBenefits = [
    'Unlimited trainer & nutritionist discovery',
    '15 new Trainer & Nutritionist connections per month',
    'Unlimited messaging with accepted providers',
    'Review your connected trainer',
  ];

  static const _ultimateBenefits = [
    'Unlimited trainers & nutritionists in Discover',
    'Unlimited new provider connections',
    'Unlimited messaging with accepted providers',
    'Priority support',
  ];

  final _subsRepo = SubscriptionsRepository();
  String _plan = SubscriptionPlans.free;
  String _status = 'active';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await _subsRepo.fetchMine();
    if (!mounted) return;
    setState(() {
      _plan = row?.plan ?? SubscriptionPlans.free;
      _status = row?.status ?? 'active';
      _loading = false;
    });
    ref.read(entitlementsProvider.notifier).refresh();
  }

  IconData _planIcon(String plan) {
    final p = plan.toLowerCase();
    if (p == SubscriptionPlans.basic) return Icons.fitness_center_outlined;
    if (p == SubscriptionPlans.unlimited) return Icons.workspace_premium_rounded;
    return Icons.explore_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = AccountHubTheme.pageBg(context);
    final entitlements = ref.watch(entitlementsProvider).valueOrNull;
    final planName = entitlements?.planDisplayName.isNotEmpty == true
        ? entitlements!.planDisplayName
        : SubscriptionPlans.displayName(_plan);
    final nutritionistAllowed = entitlements?.nutritionistAllowed;

    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Subscription',
        backgroundColor: bg,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              color: DesignTokens.accentOrange,
              backgroundColor: DesignTokens.surfaceOf(context),
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _PlanHero(
                    planName: planName,
                    planIcon: _planIcon(_plan),
                    isFree: _plan == SubscriptionPlans.free,
                    statusLabel: _status.replaceAll('_', ' '),
                    accent: _accent,
                    isLight: isLight,
                  ),
                  const SizedBox(height: 12),
                  _AllowanceCard(
                    entitlements: entitlements,
                    accent: _accent,
                    isLight: isLight,
                  ),
                  if (nutritionistAllowed == false) ...[
                    const SizedBox(height: 10),
                    const _NutritionistAccessRow(
                      text: 'Nutritionists available on Basic and Ultimate',
                      included: false,
                    ),
                  ] else if (nutritionistAllowed == true) ...[
                    const SizedBox(height: 10),
                    const _NutritionistAccessRow(
                      text: 'Trainer & Nutritionist connections included',
                      included: true,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Compare plans',
                      style: AccountHubTheme.sectionTitle(context),
                    ),
                  ),
                  _PlanCard(
                    title: 'Free',
                    tagline: '5 new Trainer connections per month',
                    icon: Icons.explore_outlined,
                    accent: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                    isLight: isLight,
                    isCurrent: _plan == SubscriptionPlans.free,
                    benefits: _freeBenefits,
                    animationDelayMs: 80,
                  ),
                  const SizedBox(height: 10),
                  _PlanCard(
                    title: 'Basic',
                    tagline:
                        '15 new Trainer & Nutritionist connections per month',
                    icon: Icons.fitness_center_outlined,
                    accent: AccountHubTheme.subscriptionAmber,
                    isLight: isLight,
                    isCurrent: _plan == SubscriptionPlans.basic,
                    benefits: _basicBenefits,
                    animationDelayMs: 120,
                  ),
                  const SizedBox(height: 10),
                  _PlanCard(
                    title: 'Ultimate',
                    tagline: 'Unlimited new provider connections',
                    icon: Icons.workspace_premium_rounded,
                    accent: _accent,
                    isLight: isLight,
                    isCurrent: _plan == SubscriptionPlans.unlimited,
                    benefits: _ultimateBenefits,
                    animationDelayMs: 160,
                    featured: true,
                  ),
                  const SizedBox(height: 12),
                  HubSectionCard(
                    title: 'Upgrade',
                    animationDelayMs: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "In-app purchases are coming soon. You'll be able to upgrade directly in Cotrainr.",
                          style: AccountHubTheme.rowSubtitle(context)
                              .copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent.withValues(alpha: 0.35),
                            disabledBackgroundColor:
                                _accent.withValues(alpha: 0.2),
                            foregroundColor:
                                Colors.white.withValues(alpha: 0.9),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Upgrade — coming soon'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlanHero extends StatelessWidget {
  final String planName;
  final IconData planIcon;
  final bool isFree;
  final String statusLabel;
  final Color accent;
  final bool isLight;

  const _PlanHero({
    required this.planName,
    required this.planIcon,
    required this.isFree,
    required this.statusLabel,
    required this.accent,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return HubSectionCard(
      animationDelayMs: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AccountHubTheme.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: isLight ? 0.22 : 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isLight ? 0.12 : 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(planIcon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current plan',
                    style: AccountHubTheme.rowSubtitle(context).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    planName.toUpperCase(),
                    style: AccountHubTheme.rowTitle(context).copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your current Cotrainr membership',
                    style: AccountHubTheme.rowSubtitle(context),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isFree
                    ? cs.onSurface.withValues(alpha: 0.06)
                    : AccountHubTheme.goalsGreen.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isFree ? 'Free plan' : 'Active',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isFree
                      ? cs.onSurface.withValues(alpha: 0.7)
                      : AccountHubTheme.goalsGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllowanceCard extends StatelessWidget {
  final Entitlements? entitlements;
  final Color accent;
  final bool isLight;

  const _AllowanceCard({
    required this.entitlements,
    required this.accent,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final unlimited = entitlements?.unlimited == true;
    final used = entitlements?.used;
    final remaining = entitlements?.remaining;
    final limit = entitlements?.limit;

    String headline;
    String subtitle;
    double? progress;

    if (entitlements == null) {
      headline = '—';
      subtitle = 'Allowance unavailable right now';
    } else if (unlimited) {
      headline = 'Unlimited';
      subtitle = 'Unlimited new provider connections';
    } else if (remaining != null && limit != null) {
      headline = '$remaining of $limit remaining';
      final usedCount = used ?? (limit - remaining).clamp(0, limit);
      subtitle =
          '$usedCount new provider connection${usedCount == 1 ? '' : 's'} used this month';
      if (limit > 0) {
        progress = (usedCount / limit).clamp(0.0, 1.0);
      }
    } else {
      headline = '—';
      subtitle = 'Allowance unavailable right now';
    }

    return HubSectionCard(
      animationDelayMs: 40,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 18,
                  color: accent.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection allowance',
                  style: AccountHubTheme.rowSubtitle(context).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              headline,
              style: AccountHubTheme.rowTitle(context).copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AccountHubTheme.rowSubtitle(context).copyWith(height: 1.35),
            ),
            if (progress != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: accent.withValues(alpha: isLight ? 0.12 : 0.2),
                  color: accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutritionistAccessRow extends StatelessWidget {
  final String text;
  final bool included;

  const _NutritionistAccessRow({
    required this.text,
    required this.included,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: DesignTokens.textSecondaryOf(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AccountHubTheme.rowSubtitle(context).copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String tagline;
  final IconData icon;
  final Color accent;
  final bool isLight;
  final bool isCurrent;
  final bool featured;
  final List<String> benefits;
  final int animationDelayMs;

  const _PlanCard({
    required this.title,
    required this.tagline,
    required this.icon,
    required this.accent,
    required this.isLight,
    required this.isCurrent,
    required this.benefits,
    required this.animationDelayMs,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          color: isCurrent
              ? accent.withValues(alpha: isLight ? 0.06 : 0.12)
              : AccountHubTheme.cardBg(context),
          borderRadius: BorderRadius.circular(AccountHubTheme.sectionRadius),
          boxShadow: AccountHubTheme.cardShadow(context),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.55)
                : cs.onSurface.withValues(alpha: 0.06),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isLight ? 0.12 : 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AccountHubTheme.rowTitle(context).copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (featured && !isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Popular',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tagline,
                        style: AccountHubTheme.rowSubtitle(context).copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...benefits.take(4).map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: isCurrent ? accent : AccountHubTheme.goalsGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b,
                            style: AccountHubTheme.rowSubtitle(context).copyWith(
                              fontSize: 13,
                              height: 1.35,
                              color: cs.onSurface.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
