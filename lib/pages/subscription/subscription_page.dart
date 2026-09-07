import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/subscription_plans.dart';
import '../../providers/entitlements_provider.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../services/entitlement_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/cotrainr_identity_colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/cotrainr_back_button.dart';

export '../../theme/cotrainr_identity_colors.dart'
    show SubscriptionPlanColors, CotrainrIdentityColors, PassIdentity;

/// Locked plan colour identity — see [SubscriptionPlanColors] /
/// [CotrainrIdentityColors].

IconData subscriptionPlanIcon(String plan) {
  final p = plan.toLowerCase();
  if (p == SubscriptionPlans.basic) return Icons.group_add_rounded;
  if (p == SubscriptionPlans.unlimited) return Icons.diamond_rounded;
  return Icons.travel_explore_rounded;
}

class SubscriptionPage extends ConsumerStatefulWidget {
  /// Test hooks — production callers omit these.
  final String? initialPlanOverride;
  final Entitlements? entitlementsOverride;
  final Future<SubscriptionRow?> Function()? fetchMineOverride;

  const SubscriptionPage({
    super.key,
    this.initialPlanOverride,
    this.entitlementsOverride,
    this.fetchMineOverride,
  });

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  static const _freeBenefits = [
    'Browse trainers & nutritionists',
    '5 new Trainer connections/month',
    'Unlimited messaging with accepted providers',
    'Nutritionist connections require Basic or Ultimate',
  ];

  static const _basicBenefits = [
    'Trainers + Nutritionists',
    '15 new provider connections/month combined',
    'Unlimited messaging with accepted providers',
    'Review your connected trainer',
  ];

  static const _ultimateBenefits = [
    'Trainers + Nutritionists',
    'Unlimited new provider connections',
    'Unlimited messaging with accepted providers',
    'Priority support',
  ];

  SubscriptionsRepository? _subsRepo;
  String _plan = SubscriptionPlans.free;
  bool _loading = true;

  /// Only one compare-plan card expanded at a time.
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialPlanOverride;
    if (seeded != null) {
      _plan = seeded;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.fetchMineOverride == null && widget.initialPlanOverride != null) {
      // Widget tests seed plan + entitlements without hitting Supabase.
      if (mounted) setState(() => _loading = false);
      return;
    }
    final fetch = widget.fetchMineOverride ??
        () {
          _subsRepo ??= SubscriptionsRepository();
          return _subsRepo!.fetchMine();
        };
    final row = await fetch();
    if (!mounted) return;
    setState(() {
      _plan = row?.plan ?? SubscriptionPlans.free;
      _loading = false;
    });
    if (widget.entitlementsOverride == null) {
      ref.read(entitlementsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final Entitlements? entitlements;
    if (widget.entitlementsOverride != null) {
      entitlements = widget.entitlementsOverride;
    } else {
      entitlements = ref.watch(entitlementsProvider).valueOrNull;
    }
    final planName = entitlements?.planDisplayName.isNotEmpty == true
        ? entitlements!.planDisplayName
        : SubscriptionPlans.displayName(_plan);

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  MembershipSummaryCard(
                    planId: _plan,
                    planDisplayName: planName,
                    entitlements: entitlements,
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text(
                      'Compare plans',
                      style: AccountHubTheme.sectionTitle(context),
                    ),
                  ),
                  ComparePlanCard(
                    planId: SubscriptionPlans.free,
                    title: 'Free',
                    subtitle: '5 new Trainer connections/month',
                    accessLine: 'Trainer connections only',
                    icon: subscriptionPlanIcon(SubscriptionPlans.free),
                    isCurrent: _plan == SubscriptionPlans.free,
                    isPopular: false,
                    benefits: _freeBenefits,
                    expanded: _expandedIndex == 0,
                    onToggle: () => setState(() {
                      _expandedIndex = _expandedIndex == 0 ? null : 0;
                    }),
                  ),
                  const SizedBox(height: 10),
                  ComparePlanCard(
                    planId: SubscriptionPlans.basic,
                    title: 'Basic',
                    subtitle: '15 new provider connections/month',
                    accessLine: 'Trainer + Nutritionist',
                    icon: subscriptionPlanIcon(SubscriptionPlans.basic),
                    isCurrent: _plan == SubscriptionPlans.basic,
                    isPopular: false,
                    benefits: _basicBenefits,
                    expanded: _expandedIndex == 1,
                    onToggle: () => setState(() {
                      _expandedIndex = _expandedIndex == 1 ? null : 1;
                    }),
                  ),
                  const SizedBox(height: 10),
                  ComparePlanCard(
                    planId: SubscriptionPlans.unlimited,
                    title: 'Ultimate',
                    subtitle: 'Unlimited new provider connections',
                    accessLine: 'Trainer + Nutritionist',
                    icon: subscriptionPlanIcon(SubscriptionPlans.unlimited),
                    isCurrent: _plan == SubscriptionPlans.unlimited,
                    isPopular: true,
                    benefits: _ultimateBenefits,
                    expanded: _expandedIndex == 2,
                    onToggle: () => setState(() {
                      _expandedIndex = _expandedIndex == 2 ? null : 2;
                    }),
                  ),
                  const SizedBox(height: 28),
                  const _UpgradesComingSoonFooter(),
                ],
              ),
            ),
    );
  }
}

/// Consolidated current plan + connection allowance.
@visibleForTesting
class MembershipSummaryCard extends StatelessWidget {
  final String planId;
  final String planDisplayName;
  final Entitlements? entitlements;

  const MembershipSummaryCard({
    super.key,
    required this.planId,
    required this.planDisplayName,
    required this.entitlements,
  });

  static String formatResetDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = SubscriptionPlanColors.accentFor(planId);
    final progressColor = SubscriptionPlanColors.progressFor(planId);
    final gradient = SubscriptionPlanColors.gradientFor(planId);
    final isUltimate = planId.toLowerCase() == SubscriptionPlans.unlimited;
    final isFree = planId.toLowerCase() == SubscriptionPlans.free;
    final unlimited = entitlements?.unlimited == true;
    final used = entitlements?.used;
    final remaining = entitlements?.remaining;
    final limit = entitlements?.limit;
    final nutritionistAllowed = entitlements?.nutritionistAllowed;
    final resetAt = entitlements?.periodEnd;

    String headline;
    String headlineSub;
    String? metaLine;
    double? progress;

    if (entitlements == null) {
      headline = '—';
      headlineSub = 'Allowance unavailable right now';
    } else if (unlimited) {
      headline = 'Unlimited';
      headlineSub = 'provider connections';
    } else if (remaining != null && limit != null) {
      headline = '$remaining of $limit';
      headlineSub = 'connections remaining';
      final usedCount = used ?? (limit - remaining).clamp(0, limit);
      final reset =
          resetAt != null ? 'Resets ${formatResetDate(resetAt)}' : null;
      metaLine = [
        '$usedCount used',
        '$remaining remaining',
        ?reset,
      ].join(' • ');
      if (limit > 0) {
        progress = (usedCount / limit).clamp(0.0, 1.0);
      }
    } else {
      headline = '—';
      headlineSub = 'Allowance unavailable right now';
    }

    String? accessLine;
    if (nutritionistAllowed == true ||
        isUltimate ||
        planId.toLowerCase() == SubscriptionPlans.basic) {
      accessLine = 'Trainer + Nutritionist access';
    } else if (isFree || nutritionistAllowed == false) {
      accessLine = 'Trainer connections only';
    }

    String? nutritionistHint;
    if (isFree && nutritionistAllowed != true && !unlimited) {
      nutritionistHint = 'Nutritionists unlock with Basic';
    }

    final surface = isLight ? Colors.white : const Color(0xFF161618);
    final onSurface = isLight ? const Color(0xFF141414) : Colors.white;
    final muted = isLight
        ? const Color(0xFF6B6560)
        : Colors.white.withValues(alpha: 0.62);

    return Semantics(
      container: true,
      label: 'Your membership, $planDisplayName',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accent.withValues(alpha: isLight ? 0.35 : 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isLight ? 0.14 : 0.22),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gradient.colors.first
                            .withValues(alpha: isLight ? 0.14 : 0.55),
                        surface,
                        surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR MEMBERSHIP',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _PlanIconBadge(
                          icon: subscriptionPlanIcon(planId),
                          gradient: gradient,
                          accent: accent,
                          isUltimate: isUltimate,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            planDisplayName.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: onSurface,
                              height: 1.05,
                            ),
                          ),
                        ),
                        _StatusChip(
                          label: 'CURRENT',
                          accent: accent,
                          isUltimate: isUltimate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      headline,
                      style: GoogleFonts.montserrat(
                        fontSize: unlimited ? 28 : 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: onSurface,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headlineSub,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: muted,
                        height: 1.3,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        label: 'Connection allowance progress',
                        value: metaLine ?? '',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: progressColor.withValues(
                              alpha: isLight ? 0.14 : 0.22,
                            ),
                            color: progressColor,
                          ),
                        ),
                      ),
                    ],
                    if (metaLine != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        metaLine,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (accessLine != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        accessLine,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onSurface.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    if (nutritionistHint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        nutritionistHint,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanIconBadge extends StatelessWidget {
  final IconData icon;
  final LinearGradient gradient;
  final Color accent;
  final bool isUltimate;

  const _PlanIconBadge({
    required this.icon,
    required this.gradient,
    required this.accent,
    required this.isUltimate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: isUltimate
            ? LinearGradient(
                colors: [
                  SubscriptionPlanColors.ultimateEnd,
                  accent.withValues(alpha: 0.35),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : gradient,
        borderRadius: BorderRadius.circular(14),
        border: isUltimate
            ? Border.all(color: accent.withValues(alpha: 0.55))
            : null,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 22,
        color: isUltimate ? accent : Colors.white,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color accent;
  final bool isUltimate;

  const _StatusChip({
    required this.label,
    required this.accent,
    required this.isUltimate,
  });

  @override
  Widget build(BuildContext context) {
    final bg = accent.withValues(alpha: isUltimate ? 0.16 : 0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: accent,
        ),
      ),
    );
  }
}

@visibleForTesting
class ComparePlanCard extends StatelessWidget {
  final String planId;
  final String title;
  final String subtitle;
  final String accessLine;
  final IconData icon;
  final bool isCurrent;
  final bool isPopular;
  final List<String> benefits;
  final bool expanded;
  final VoidCallback onToggle;

  const ComparePlanCard({
    super.key,
    required this.planId,
    required this.title,
    required this.subtitle,
    required this.accessLine,
    required this.icon,
    required this.isCurrent,
    required this.isPopular,
    required this.benefits,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = SubscriptionPlanColors.accentFor(planId);
    final gradient = SubscriptionPlanColors.gradientFor(planId);
    final isUltimate = planId.toLowerCase() == SubscriptionPlans.unlimited;
    final surface = isLight ? Colors.white : const Color(0xFF141416);
    final onSurface = isLight ? const Color(0xFF141414) : Colors.white;
    final muted = isLight
        ? const Color(0xFF6B6560)
        : Colors.white.withValues(alpha: 0.62);

    final showPopular = isPopular && !isCurrent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrent
                  ? accent.withValues(alpha: 0.65)
                  : accent.withValues(alpha: isLight ? 0.22 : 0.32),
              width: isCurrent ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isCurrent ? 0.16 : 0.08),
                blurRadius: isCurrent ? 16 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: isUltimate
                        ? LinearGradient(
                            colors: [
                              SubscriptionPlanColors.ultimateEnd,
                              accent,
                            ],
                          )
                        : gradient,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PlanIconBadge(
                            icon: icon,
                            gradient: gradient,
                            accent: accent,
                            isUltimate: isUltimate,
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
                                        title.toUpperCase(),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: onSurface,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      _StatusChip(
                                        label: 'CURRENT',
                                        accent: accent,
                                        isUltimate: isUltimate,
                                      )
                                    else if (showPopular)
                                      _StatusChip(
                                        label: 'POPULAR',
                                        accent: accent,
                                        isUltimate: true,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: muted,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  accessLine,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accent.withValues(
                                      alpha: isLight ? 0.95 : 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            expanded ? 'Hide benefits' : 'View benefits',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: expanded
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  children: [
                                    for (final b in benefits)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.check_rounded,
                                              size: 17,
                                              color: accent,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                b,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.35,
                                                  color: onSurface.withValues(
                                                    alpha: 0.82,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpgradesComingSoonFooter extends StatelessWidget {
  const _UpgradesComingSoonFooter();

  @override
  Widget build(BuildContext context) {
    final muted = DesignTokens.textSecondaryOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            'Upgrades coming soon',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimaryOf(context)
                  .withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You'll be able to change your Cotrainr plan directly in the app.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}
