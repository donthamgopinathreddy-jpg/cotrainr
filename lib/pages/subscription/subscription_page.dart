import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription_plans.dart';
import '../../providers/entitlements_provider.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/profile/account_hub_widgets.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  static const _accent = Color(0xFFD4187A);

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

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = AccountHubTheme.pageBg(context);
    final entitlements = ref.watch(entitlementsProvider).valueOrNull;
    final remainingMsgs = entitlements?.remaining.requests;
    final usedMsgs = entitlements?.used.requests;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Subscription'),
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
                _HeroCard(
                  isLight: isLight,
                  planName: SubscriptionPlans.displayName(_plan),
                ),
                const SizedBox(height: 12),
                HubSectionCard(
                  animationDelayMs: 40,
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Status',
                          value: _status.replaceAll('_', ' '),
                          icon: Icons.verified_outlined,
                          accent: AccountHubTheme.goalsGreen,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 52,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                      ),
                      Expanded(
                        child: _StatTile(
                          label: _plan == SubscriptionPlans.free
                              ? 'Chats left'
                              : 'Messaging',
                          value: _plan == SubscriptionPlans.free
                              ? (remainingMsgs != null
                                  ? '$remainingMsgs / 5'
                                  : '—')
                              : 'Unlimited',
                          icon: Icons.chat_bubble_outline_rounded,
                          accent: _accent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_plan == SubscriptionPlans.free && usedMsgs != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${usedMsgs.clamp(0, 5)} of 5 trainer chats used this month',
                      style: AccountHubTheme.rowSubtitle(context),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Compare plans',
                    style: AccountHubTheme.sectionTitle(context),
                  ),
                ),
                _PlanCard(
                  title: 'Free',
                  tagline: 'Discover trainers near you',
                  icon: Icons.explore_outlined,
                  accent: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  isLight: isLight,
                  isCurrent: _plan == SubscriptionPlans.free,
                  benefits: SubscriptionPlans.freeBenefits,
                  animationDelayMs: 80,
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Basic',
                  tagline: 'Unlimited trainer access',
                  icon: Icons.fitness_center_outlined,
                  accent: AccountHubTheme.subscriptionAmber,
                  isLight: isLight,
                  isCurrent: _plan == SubscriptionPlans.basic,
                  benefits: SubscriptionPlans.basicBenefits,
                  animationDelayMs: 120,
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Unlimited',
                  tagline: 'Trainers & nutritionists',
                  icon: Icons.workspace_premium_rounded,
                  accent: _accent,
                  isLight: isLight,
                  isCurrent: _plan == SubscriptionPlans.unlimited,
                  benefits: SubscriptionPlans.unlimitedBenefits,
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
                        'In-app purchases and billing management are coming soon. '
                        'Contact support if you need a plan change before launch.',
                        style: AccountHubTheme.rowSubtitle(context).copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent.withValues(alpha: 0.35),
                          disabledBackgroundColor: _accent.withValues(alpha: 0.2),
                          foregroundColor: Colors.white.withValues(alpha: 0.9),
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

class _HeroCard extends StatelessWidget {
  final bool isLight;
  final String planName;

  const _HeroCard({
    required this.isLight,
    required this.planName,
  });

  @override
  Widget build(BuildContext context) {
    return HubSectionCard(
      animationDelayMs: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          gradient: HomePremiumTheme.bmiTileGradient(
            isLight,
            _SubscriptionPageState._accent,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _SubscriptionPageState._accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _SubscriptionPageState._accent,
                size: 22,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your membership',
              style: AccountHubTheme.rowTitle(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You\'re on the $planName plan. Compare tiers below to see what unlocks as you grow.',
              style: AccountHubTheme.rowSubtitle(context).copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Text(
            value,
            style: AccountHubTheme.rowTitle(context).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AccountHubTheme.rowSubtitle(context)),
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
          color: AccountHubTheme.cardBg(context),
          borderRadius: BorderRadius.circular(AccountHubTheme.sectionRadius),
          boxShadow: AccountHubTheme.cardShadow(context),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.55)
                : cs.onSurface.withValues(alpha: 0.06),
            width: isCurrent ? 1.5 : 1,
          ),
          gradient: isCurrent
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: isLight ? 0.08 : 0.14),
                    AccountHubTheme.cardBg(context),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(tagline, style: AccountHubTheme.rowSubtitle(context)),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
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
            const SizedBox(height: 14),
            ...benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: isCurrent ? accent : AccountHubTheme.goalsGreen,
                    ),
                    const SizedBox(width: 10),
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
