import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/user_role.dart';
import '../../models/member_plan_view.dart';
import '../../providers/profile_role_provider.dart';
import '../../repositories/cotrainr_pass_repository.dart';
import '../../repositories/partner_centers_repository.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/cotrainr_logo.dart';
import '../../widgets/common/cotrainr_back_button.dart';

class CotrainrPassPage extends ConsumerStatefulWidget {
  const CotrainrPassPage({super.key});

  @override
  ConsumerState<CotrainrPassPage> createState() => _CotrainrPassPageState();
}

class _CotrainrPassPageState extends ConsumerState<CotrainrPassPage>
    with WidgetsBindingObserver {
  final _passRepo = CotrainrPassRepository();
  final _subsRepo = SubscriptionsRepository();
  final _partnerRepo = PartnerCentersRepository();

  bool _passLoading = true;
  String? _passError;
  CotrainrPassInfo? _info;
  PartnerCenterApplication? _application;
  bool _termsExpanded = false;

  MemberPlanView _planView = MemberPlanView.loading;

  /// Canonical role from [currentUserProvider] (profiles.role / get_my_profile).
  UserRole? get _role => ref.watch(currentUserProvider).valueOrNull?.role;

  bool get _isClient => _role == UserRole.client;

  bool get _isProvider => _role?.isProvider ?? false;

  String? get _roleDisplayLabel {
    switch (_role) {
      case UserRole.trainer:
        return 'Trainer';
      case UserRole.nutritionist:
        return 'Nutritionist';
      case UserRole.client:
      case null:
        return null;
    }
  }

  String get _aboutPassCopy {
    switch (_role) {
      case UserRole.trainer:
        return 'Your Cotrainr Pass is your permanent Trainer identity across Cotrainr. '
            'Your Pass ID stays with your account.';
      case UserRole.nutritionist:
        return 'Your Cotrainr Pass is your permanent Nutritionist identity across Cotrainr. '
            'Your Pass ID stays with your account.';
      case UserRole.client:
      case null:
        return 'Your Cotrainr Pass is your permanent member identity across Cotrainr. '
            'Your Pass ID stays with your account even when your subscription plan changes.';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _info != null && _isClient) {
      _loadPlanOnly();
    }
  }

  Future<void> _load() async {
    setState(() {
      _passLoading = true;
      _passError = null;
      _planView = MemberPlanView.loading;
    });

    // Pass identity and subscription are independent — one failure must not
    // fabricate Free or wipe the Pass.
    CotrainrPassInfo? info;
    String? passError;
    PartnerCenterApplication? app;
    MemberPlanView planView = MemberPlanView.loading;

    try {
      info = await _passRepo.loadPassInfo(planLabel: 'Free');
      try {
        app = await _partnerRepo.latestOpenOrRecentApplication();
      } catch (_) {}
    } catch (e) {
      passError = e.toString().replaceFirst('Exception: ', '');
    }

    // Client subscription UI only — providers do not see plan/subscription on Pass.
    final role = ref.read(currentUserProvider).valueOrNull?.role;
    if (role == UserRole.client) {
      try {
        final sub = await _subsRepo.fetchMineStrict();
        planView = MemberPlanView.fromSubscription(sub);
        if (info != null) {
          info = CotrainrPassInfo(
            passId: info.passId,
            passCreatedAt: info.passCreatedAt,
            memberSince: info.memberSince,
            fullName: info.fullName,
            avatarUrl: info.avatarUrl,
            planLabel: planView.isError
                ? info.planLabel
                : (planView.planDisplayName.isEmpty
                    ? 'Free'
                    : planView.planDisplayName),
          );
        }
      } catch (_) {
        planView = MemberPlanView.error;
      }
    }

    if (!mounted) return;
    setState(() {
      _info = info;
      _application = app;
      _passError = passError;
      _passLoading = false;
      _planView = planView;
    });
  }

  Future<void> _loadPlanOnly() async {
    if (!_isClient) return;
    if (!mounted) return;
    setState(() => _planView = MemberPlanView.loading);
    try {
      final sub = await _subsRepo.fetchMineStrict();
      final planView = MemberPlanView.fromSubscription(sub);
      if (!mounted) return;
      setState(() {
        _planView = planView;
        final info = _info;
        if (info != null && !planView.isError) {
          _info = CotrainrPassInfo(
            passId: info.passId,
            passCreatedAt: info.passCreatedAt,
            memberSince: info.memberSince,
            fullName: info.fullName,
            avatarUrl: info.avatarUrl,
            planLabel: planView.planDisplayName.isEmpty
                ? 'Free'
                : planView.planDisplayName,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _planView = MemberPlanView.error);
    }
  }

  Future<void> _openSubscription() async {
    HapticFeedback.selectionClick();
    await context.push('/subscription');
    if (mounted) await _loadPlanOnly();
  }

  Future<void> _copyId() async {
    final id = _info?.passId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pass ID copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openPartnerCentres() {
    HapticFeedback.selectionClick();
    context.go('/home?tab=1&discover=centers');
  }

  Future<void> _openBecomePartner() async {
    HapticFeedback.selectionClick();
    final open = _application?.isOpen == true;
    if (open) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your application ${_application!.applicationCode} is ${_application!.statusLabel.toLowerCase()}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = await context.push<bool>('/profile/partner-application');
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight
        ? const Color(0xFFF7F4F0)
        : DesignTokens.backgroundOf(context);
    final onSurface = isLight ? const Color(0xFF141414) : Colors.white;
    final muted = isLight
        ? const Color(0xFF6B6560)
        : Colors.white.withValues(alpha: 0.62);

    return Scaffold(
      backgroundColor: bg,
      body: _passLoading
          ? const Center(child: CircularProgressIndicator())
          : _passError != null && _info == null
              ? SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_passError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: DesignTokens.accentOrange,
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        backgroundColor: bg,
                        surfaceTintColor: Colors.transparent,
                        automaticallyImplyLeading: false,
                        leading: CotrainrBackButton(color: onSurface),
                        title: Text(
                          'Member Pass',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _MembershipCard(
                              info: _info!,
                              isLight: isLight,
                              roleLabel: _roleDisplayLabel,
                            ),
                            if (_isClient) ...[
                              const SizedBox(height: 20),
                              Text(
                                'YOUR PLAN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _YourPlanCard(
                                view: _planView,
                                isLight: isLight,
                                onManage: _openSubscription,
                                onRetry: _loadPlanOnly,
                              ),
                            ],
                            const SizedBox(height: 28),
                            Text(
                              'About your Cotrainr Pass',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _aboutPassCopy,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'What you can do with your Pass',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _CapabilityCard(
                              icon: Icons.fitness_center_rounded,
                              title: 'Partner Centres',
                              description:
                                  'Verify your membership at participating gyms, studios and fitness centres and access eligible Cotrainr partner offers.',
                              status: 'Available',
                              statusLive: true,
                              ctaLabel: 'Find Centres',
                              onCta: _openPartnerCentres,
                              isLight: isLight,
                            ),
                            const SizedBox(height: 10),
                            _CapabilityCard(
                              icon: Icons.verified_user_outlined,
                              title: 'Membership Verification',
                              description: _isProvider
                                  ? 'Your Pass ID securely identifies your Cotrainr account where verification is required.'
                                  : 'Your Pass ID securely identifies your Cotrainr membership and current plan where verification is required.',
                              isLight: isLight,
                            ),
                            const SizedBox(height: 10),
                            _CapabilityCard(
                              icon: Icons.school_outlined,
                              title: 'Cotrainr Academy',
                              description:
                                  'Your Cotrainr identity can be used for eligible Academy programs and certifications when launched.',
                              status: 'Coming later',
                              statusLive: false,
                              isLight: isLight,
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Partner Centres',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use your Cotrainr Pass at participating fitness businesses. '
                              'Centre access and offers depend on each partner and your eligibility — the Pass alone is not free gym entry.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_application != null) ...[
                              _ApplicationStatusBanner(
                                application: _application!,
                                isLight: isLight,
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _openPartnerCentres,
                                style: FilledButton.styleFrom(
                                  backgroundColor: DesignTokens.accentOrange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Find Partner Centres'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _openBecomePartner,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: onSurface,
                                  side: BorderSide(
                                    color: onSurface.withValues(alpha: 0.18),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  _application?.isOpen == true
                                      ? 'View Partner Application'
                                      : 'Become a Partner Centre',
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Your Pass ID',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isLight
                                    ? Colors.white
                                    : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isLight
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _info!.passId,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.4,
                                        color: onSurface,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _copyId,
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 18),
                                    label: const Text('Copy ID'),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          DesignTokens.accentOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            InkWell(
                              onTap: () => setState(
                                () => _termsExpanded = !_termsExpanded,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Cotrainr Pass Terms',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: onSurface,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _termsExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_termsExpanded) ...[
                              const SizedBox(height: 6),
                              ..._termsPoints.map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('•  ', style: TextStyle(color: muted)),
                                      Expanded(
                                        child: Text(
                                          t,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  static const _termsPoints = [
    'Your Cotrainr Pass is personal to the account holder.',
    'Your Pass ID identifies your Cotrainr account; it is not a payment card.',
    'The Pass does not automatically grant gym entry or discounts.',
    'Partner benefits have separate eligibility and can change or expire.',
    'Misuse may result in benefit restrictions or account action.',
    'Your account Terms of Service and Privacy Policy continue to apply.',
  ];
}

class _YourPlanCard extends StatelessWidget {
  final MemberPlanView view;
  final bool isLight;
  final VoidCallback onManage;
  final VoidCallback onRetry;

  const _YourPlanCard({
    required this.view,
    required this.isLight,
    required this.onManage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = isLight ? const Color(0xFF141414) : Colors.white;
    final muted = isLight
        ? const Color(0xFF6B6560)
        : Colors.white.withValues(alpha: 0.62);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: view.isLoading
          ? _planShell(
              key: const ValueKey('plan-loading'),
              isLight: isLight,
              child: Row(
                children: [
                  _shimmerBox(44, 44, radius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(120, 14),
                        const SizedBox(height: 8),
                        _shimmerBox(80, 12),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : view.isError
              ? _planShell(
                  key: const ValueKey('plan-error'),
                  isLight: isLight,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: muted,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Unable to load plan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: DesignTokens.accentOrange,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _planShell(
                  key: ValueKey(
                    '${view.planDisplayName}-${view.statusLabel}-${view.detailLine}',
                  ),
                  isLight: isLight,
                  onTap: onManage,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DesignTokens.accentOrange
                              .withValues(alpha: isLight ? 0.12 : 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: DesignTokens.accentOrange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              view.planDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
                              ),
                            ),
                            if (view.detailLine != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                view.detailLine!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              view.ctaLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(view: view, isLight: isLight),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: muted,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _shimmerBox(double w, double h, {double radius = 6}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _planShell({
    required Key key,
    required bool isLight,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      key: key,
      color: isLight ? Colors.white : const Color(0xFF141414),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MemberPlanView view;
  final bool isLight;

  const _StatusChip({required this.view, required this.isLight});

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    switch (view.state) {
      case MemberPlanUiState.active:
      case MemberPlanUiState.trial:
        fg = const Color(0xFF0FA35F);
        bg = const Color(0xFF19C37D).withValues(alpha: 0.14);
        break;
      case MemberPlanUiState.expired:
      case MemberPlanUiState.pastDue:
        fg = const Color(0xFFC62828);
        bg = const Color(0xFFC62828).withValues(alpha: 0.12);
        break;
      case MemberPlanUiState.cancelledActive:
        fg = DesignTokens.accentOrange;
        bg = DesignTokens.accentOrange.withValues(alpha: 0.12);
        break;
      default:
        fg = isLight ? const Color(0xFF6B6560) : Colors.white70;
        bg = (isLight ? Colors.black : Colors.white).withValues(alpha: 0.07);
    }
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        view.statusLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _ApplicationStatusBanner extends StatelessWidget {
  final PartnerCenterApplication application;
  final bool isLight;

  const _ApplicationStatusBanner({
    required this.application,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final live = application.status == 'approved';
    final color = live
        ? const Color(0xFF0FA35F)
        : application.status == 'rejected'
            ? const Color(0xFFC62828)
            : DesignTokens.accentOrange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isLight ? 0.1 : 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Partner Application',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            application.statusLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isLight ? const Color(0xFF141414) : Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${application.businessName} · ${application.applicationCode}',
            style: TextStyle(
              fontSize: 12,
              color: isLight
                  ? const Color(0xFF6B6560)
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? status;
  final bool statusLive;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool isLight;

  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.description,
    this.status,
    this.statusLive = false,
    this.ctaLabel,
    this.onCta,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = isLight ? const Color(0xFF141414) : Colors.white;
    final muted = isLight
        ? const Color(0xFF6B6560)
        : Colors.white.withValues(alpha: 0.62);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DesignTokens.accentOrange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: onSurface,
                  ),
                ),
              ),
              if (status != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusLive
                        ? const Color(0xFF19C37D).withValues(alpha: 0.14)
                        : onSurface.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusLive
                          ? const Color(0xFF0FA35F)
                          : muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(fontSize: 13, height: 1.4, color: muted),
          ),
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCta,
                style: TextButton.styleFrom(
                  foregroundColor: DesignTokens.accentOrange,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  ctaLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembershipCard extends StatefulWidget {
  final CotrainrPassInfo info;
  final bool isLight;
  /// When non-null (Trainer / Nutritionist), card shows ROLE instead of PLAN.
  final String? roleLabel;

  const _MembershipCard({
    required this.info,
    required this.isLight,
    this.roleLabel,
  });

  @override
  State<_MembershipCard> createState() => _MembershipCardState();
}

class _MembershipCardState extends State<_MembershipCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final isLight = widget.isLight;
    final roleLabel = widget.roleLabel;
    final showRole = roleLabel != null && roleLabel.isNotEmpty;
    final name = (info.fullName?.trim().isNotEmpty == true)
        ? info.fullName!.trim().toUpperCase()
        : 'COTRAINR MEMBER';
    final memberSince = info.memberSince ?? info.passCreatedAt;
    final sinceLabel = memberSince == null ? '—' : _monthYear(memberSince);
    final planLabel = info.planLabel;
    final metaLabel = showRole ? 'ROLE' : 'PLAN';
    final metaValue = showRole ? roleLabel : planLabel;

    // Orange membership card in both light and dark themes.
    final primaryText = Colors.white;
    final secondaryText = Colors.white.withValues(alpha: 0.75);
    final passIdColor = Colors.white;
    final planValueColor = Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final photoSize = (width * 0.20).clamp(70.0, 82.0);
        final identityRightPad = (width * 0.26).clamp(84.0, 120.0);
        final nameSize = (width * 0.062).clamp(22.0, 28.0);
        final passIdSize = (width * 0.042).clamp(15.0, 18.0);

        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AspectRatio(
              aspectRatio: 1 / 0.60,
              child: Semantics(
                label: showRole
                    ? 'Cotrainr Pass for $name, member ID ${info.passId}, role $metaValue'
                    : 'Cotrainr Pass for $name, member ID ${info.passId}, plan $planLabel',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFE65100),
                        Color(0xFFFF8A00),
                        Color(0xFFFFA040),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.18 : 0.5,
                        ),
                        blurRadius: isLight ? 22 : 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _CardBrandGraphic(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardBrandLockup(),
                            const Spacer(flex: 1),
                            Padding(
                              padding: EdgeInsets.only(right: identityRightPad),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _PassPortrait(
                                    url: info.avatarUrl,
                                    size: photoSize,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              fontSize: nameSize,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.4,
                                              color: primaryText,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'MEMBER ID',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.4,
                                            color: secondaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          info.passId,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: passIdSize,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: passIdColor,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(flex: 1),
                            Container(
                              height: 1,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.35),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _MembershipMeta(
                                    label: 'MEMBER SINCE',
                                    value: sinceLabel,
                                    labelColor: secondaryText,
                                    valueColor: primaryText,
                                    alignEnd: false,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 34,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                                Expanded(
                                  child: _MembershipMeta(
                                    label: metaLabel,
                                    value: metaValue,
                                    labelColor: secondaryText,
                                    valueColor: planValueColor,
                                    alignEnd: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _monthYear(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

/// Single light wordmark: COTRAINR PASS (no logo mark, no tagline).
class _CardBrandLockup extends StatelessWidget {
  const _CardBrandLockup();

  @override
  Widget build(BuildContext context) {
    return Text(
      'COTRAINR PASS',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        height: 1.0,
        color: Colors.white.withValues(alpha: 0.92),
      ),
    );
  }
}

/// One oversized official Cotrainr SVG mark as clipped brand geometry.
class _CardBrandGraphic extends StatelessWidget {
  const _CardBrandGraphic();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -40,
      top: -28,
      bottom: -36,
      width: 200,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.centerRight,
          child: Transform.rotate(
            angle: -0.12,
            child: Opacity(
              opacity: 0.28,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFFBF360C),
                  BlendMode.srcIn,
                ),
                child: const CotrainrLogo(
                  height: 220,
                  variant: CotrainrLogoVariant.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipMeta extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final bool alignEnd;

  const _MembershipMeta({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final cross = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          label,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _PassPortrait extends StatelessWidget {
  final String? url;
  final double size;

  const _PassPortrait({
    required this.url,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    const radius = BorderRadius.all(Radius.circular(18));
    return Semantics(
      label: 'Profile photo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.2),
              child: hasUrl
                  ? Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _DefaultPassAvatar(),
                    )
                  : const _DefaultPassAvatar(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultPassAvatar extends StatelessWidget {
  const _DefaultPassAvatar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: DesignTokens.accentOrange.withValues(alpha: 0.85),
          size: 34,
        ),
      ),
    );
  }
}
