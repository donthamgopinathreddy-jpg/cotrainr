import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_professional_profile.dart';
import '../../models/provider_specialty_taxonomy.dart';
import '../../models/subscription_plans.dart';
import '../../providers/accepted_client_trainers_provider.dart';
import '../../providers/provider_professional_provider.dart';
import '../../repositories/messages_repository.dart';
import '../../repositories/provider_reviews_repository.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../services/entitlement_service.dart';
import '../../services/leads_service.dart';
import '../../services/messaging_policy_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/provider/public_provider_profile_header.dart';
import '../../widgets/provider/inline_provider_review_editor.dart';
import '../../widgets/subscription/nutritionist_upgrade_sheet.dart';
import '../../widgets/subscription/connection_limit_sheet.dart';

/// Public provider profile — identity header, connection CTA, and three tabs.
///
/// UI always paints immediately from fallbacks; network fills in afterwards.
class PublicProfileReadonlyPage extends ConsumerStatefulWidget {
  final String userId;
  final String? titleFallback;
  final String? providerType;

  const PublicProfileReadonlyPage({
    super.key,
    required this.userId,
    this.titleFallback,
    this.providerType,
  });

  @override
  ConsumerState<PublicProfileReadonlyPage> createState() =>
      _PublicProfileReadonlyPageState();
}

class _PublicProfileReadonlyPageState
    extends ConsumerState<PublicProfileReadonlyPage>
    with SingleTickerProviderStateMixin {
  static const _timeout = Duration(seconds: 8);

  final _supabase = Supabase.instance.client;
  final _reviewsRepo = ProviderReviewsRepository();
  final _leadsService = LeadsService();

  late final TabController _tabController;

  /// Never gates the scaffold — only shows a small refresh indicator.
  bool _refreshing = false;
  String? _username;
  int _clientCount = 0;
  bool _bioExpanded = false;
  List<ProviderReview> _reviews = [];
  bool _canRate = false;
  bool _reviewEditorOpen = false;
  ProviderReview? _myReview;
  late ProviderProfessionalProfile _profile;
  List<ProviderCertification> _certs = [];
  String _relationship = 'none';
  String? _pendingLeadId;
  bool _canMessage = false;
  bool _actionBusy = false;
  String _clientPlan = SubscriptionPlans.free;
  int? _connectionLimit;
  bool _connectionUnlimited = false;
  /// Server nutritionist connect eligibility. null = unknown (do not block locally).
  bool? _nutritionistAllowed;

  bool get _isNutritionist =>
      (_profile.providerType).toLowerCase() == 'nutritionist' ||
      (widget.providerType ?? '').toLowerCase() == 'nutritionist';

  static const _tabs = [
    'Profile',
    'Services',
    'Reviews',
  ];

  @override
  void initState() {
    super.initState();
    _profile = ProviderProfessionalProfile(
      userId: widget.userId,
      providerType: widget.providerType ?? 'trainer',
      fullName: widget.titleFallback ?? 'Provider',
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<T?> _withTimeout<T>(Future<T> future, {String? label}) async {
    try {
      return await future.timeout(_timeout);
    } on TimeoutException {
      if (kDebugMode) debugPrint('PublicProfile timeout: $label');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('PublicProfile error ($label): $e');
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _refreshing = true);

    try {
      final repo = ref.read(providerProfessionalRepositoryProvider);

      final profile = await _withTimeout(
        repo.fetchByUserId(widget.userId),
        label: 'fetchByUserId',
      );
      final certs = await _withTimeout(
            repo.listCertifications(widget.userId, publicOnly: true),
            label: 'certs',
          ) ??
          <ProviderCertification>[];

      String? username;
      String? publicName;
      String? publicAvatar;
      String? publicBio;
      String? coverUrl;
      try {
        final raw = await _withTimeout(
          _supabase.rpc(
            'get_public_profile',
            params: {'p_user_id': widget.userId},
          ),
          label: 'get_public_profile',
        );
        if (raw is List && raw.isNotEmpty) {
          final row = Map<String, dynamic>.from(raw.first as Map);
          username = row['username'] as String?;
          publicName = row['full_name'] as String?;
          publicAvatar = row['avatar_url'] as String?;
          publicBio = row['bio'] as String?;
          coverUrl = row['cover_url'] as String?;
        }
      } catch (_) {}

      var resolved = profile ??
          ProviderProfessionalProfile(
            userId: widget.userId,
            providerType: widget.providerType ?? 'trainer',
            fullName: publicName ?? widget.titleFallback ?? 'Provider',
            avatarUrl: publicAvatar,
            coverUrl: coverUrl,
            bio: publicBio,
          );

      final needsName = (resolved.fullName == null ||
              resolved.fullName!.trim().isEmpty) &&
          ((publicName ?? widget.titleFallback)?.trim().isNotEmpty ?? false);
      final needsBio = (resolved.bio == null || resolved.bio!.trim().isEmpty) &&
          (publicBio?.trim().isNotEmpty ?? false);
      final needsAvatar =
          (resolved.avatarUrl == null || resolved.avatarUrl!.trim().isEmpty) &&
              (publicAvatar?.trim().isNotEmpty ?? false);
      final needsCover =
          (resolved.coverUrl == null || resolved.coverUrl!.trim().isEmpty) &&
              (coverUrl?.trim().isNotEmpty ?? false);
      if (needsName || needsBio || needsAvatar || needsCover) {
        resolved = ProviderProfessionalProfile(
          userId: resolved.userId,
          providerType: resolved.providerType,
          professionalHeadline: resolved.professionalHeadline,
          bio: needsBio ? publicBio : resolved.bio,
          experienceYears: resolved.experienceYears,
          specializationIds: resolved.specializationIds,
          sessionModes: resolved.sessionModes,
          languages: resolved.languages,
          hourlyRate: resolved.hourlyRate,
          acceptingNewClients: resolved.acceptingNewClients,
          verified: resolved.verified,
          discoverable: resolved.discoverable,
          rating: resolved.rating,
          totalReviews: resolved.totalReviews,
          fullName: needsName
              ? (publicName ?? widget.titleFallback)
              : resolved.fullName,
          avatarUrl: needsAvatar ? publicAvatar : resolved.avatarUrl,
          coverUrl: needsCover ? coverUrl : resolved.coverUrl,
          primaryLocationLabel: resolved.primaryLocationLabel,
          coverageKm: resolved.coverageKm,
        );
      }

      final reviews = await _withTimeout(
            _reviewsRepo.listForProvider(widget.userId),
            label: 'reviews',
          ) ??
          <ProviderReview>[];

      var clientCount = 0;
      try {
        final raw = await _withTimeout(
          _supabase.rpc(
            'get_provider_accepted_client_count',
            params: {'p_provider_id': widget.userId},
          ),
          label: 'clientCount',
        );
        if (raw is int) {
          clientCount = raw;
        } else if (raw != null) {
          clientCount = int.tryParse(raw.toString()) ?? 0;
        }
      } catch (_) {
        // Fallback (may be RLS-limited for non-participants).
        try {
          final rows = await _withTimeout(
            _supabase
                .from('leads')
                .select('id')
                .eq('provider_id', widget.userId)
                .eq('status', 'accepted'),
            label: 'clientCountFallback',
          );
          if (rows is List) clientCount = (rows as List).length;
        } catch (_) {}
      }

      final canRate = await _withTimeout(
            _resolveCanRate(resolved.providerType),
            label: 'canRate',
          ) ??
          false;

      ProviderReview? myReview;
      if (canRate) {
        try {
          myReview = await _reviewsRepo
              .getMyReviewForProvider(widget.userId)
              .timeout(_timeout);
        } catch (_) {
          myReview = null;
        }
      }

      var relationship = 'none';
      String? pendingLeadId;
      var canMessage = false;
      final me = _supabase.auth.currentUser?.id;
      if (me != null) {
        try {
          final leads = await _withTimeout(
            _leadsService.getMyLeads(),
            label: 'leads',
          );
          if (leads != null) {
            for (final lead in leads.where((l) => l.clientId == me)) {
              if (lead.providerId != widget.userId) continue;
              if (lead.status == 'accepted') {
                relationship = 'accepted';
              } else if (lead.status == 'requested') {
                relationship = 'pending';
                pendingLeadId = lead.id;
              }
            }
          }
        } catch (_) {}

        if (relationship == 'accepted') {
          canMessage = await _withTimeout(
                MessagingPolicyService.clientMayUseMessagingWithProvider(
                  supabase: _supabase,
                  clientId: me,
                  providerId: widget.userId,
                ),
                label: 'canMessage',
              ) ??
              false;
        }
      }

      var clientPlan = SubscriptionPlans.free;
      var connectionLimit = _connectionLimit;
      var connectionUnlimited = _connectionUnlimited;
      bool? nutritionistAllowed = _nutritionistAllowed;
      try {
        final sub = await _withTimeout(
          SubscriptionsRepository().fetchMine(),
          label: 'subscription',
        );
        clientPlan = sub?.plan ?? SubscriptionPlans.free;
      } catch (_) {}

      try {
        final ents = await _withTimeout(
          EntitlementService().getEntitlements(),
          label: 'entitlements',
        );
        if (ents != null) {
          connectionUnlimited = ents.unlimited;
          connectionLimit = ents.unlimited ? null : ents.limit;
          nutritionistAllowed = ents.nutritionistAllowed;
        } else {
          connectionUnlimited = false;
          connectionLimit = null;
          nutritionistAllowed = null;
        }
      } catch (_) {
        connectionUnlimited = false;
        connectionLimit = null;
        nutritionistAllowed = null;
      }

      if (!mounted) return;
      setState(() {
        _profile = resolved;
        _certs = certs;
        _username = username;
        _clientCount = clientCount;
        _reviews = reviews;
        _canRate = canRate;
        _myReview = myReview;
        _relationship = relationship;
        _pendingLeadId = pendingLeadId;
        _canMessage = canMessage;
        _clientPlan = clientPlan;
        _connectionLimit = connectionLimit;
        _connectionUnlimited = connectionUnlimited;
        _nutritionistAllowed = nutritionistAllowed;
        _refreshing = false;
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('PublicProfile _load failed: $e\n$st');
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<bool> _resolveCanRate(String? providerType) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null || providerType == null) return false;
    if (providerType != 'trainer' && providerType != 'nutritionist') {
      return false;
    }
    return MessagingPolicyService.hasAcceptedLead(
      supabase: _supabase,
      clientId: me,
      providerId: widget.userId,
    );
  }

  Future<void> _sendRequest() async {
    if (_actionBusy) return;
    // Only block locally when the server has confirmed nutritionist is not allowed.
    // null (entitlements failed to load) must reach create_lead_tx.
    if (_isNutritionist && _nutritionistAllowed == false) {
      await showNutritionistUpgradeSheet(context);
      return;
    }
    setState(() => _actionBusy = true);
    try {
      final result = await _leadsService.createLead(providerId: widget.userId);
      if (!mounted) return;
      setState(() {
        _relationship = 'pending';
        _pendingLeadId = result.leadId;
        _connectionUnlimited = result.unlimited;
        if (!result.unlimited && result.limit != null) {
          _connectionLimit = result.limit;
        }
      });
      final remainingHint = _connectionUnlimited
          ? null
          : (result.remaining != null
              ? ' · ${result.remaining} new provider connection${result.remaining == 1 ? '' : 's'} remaining this month'
              : null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent${remainingHint ?? ''}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('PublicProfile send request failed: $e');
      final err = e.toString();
      if (err.contains('Nutritionist requests require') ||
          err.contains('Nutritionist connection') ||
          (err.toLowerCase().contains('nutritionist') &&
              err.toLowerCase().contains('require'))) {
        await showNutritionistUpgradeSheet(context);
        return;
      }
      final allowanceExhausted =
          err.contains('Connection allowance reached') ||
          err.contains('connection allowance') ||
          err.contains('ENTITLEMENT_EXHAUSTED') ||
          (err.contains('limit reached') &&
              !err.contains('Lead already exists'));
      if (allowanceExhausted) {
        await showConnectionLimitSheet(
          context,
          plan: _clientPlan,
          limit: _connectionLimit,
        );
        return;
      }
      final String message;
      if (err.contains('Lead already exists')) {
        message = 'You already have a pending or active request with this provider.';
      } else if (err.contains('Only clients can create leads')) {
        message = 'Only client accounts can send coaching requests.';
      } else if (err.contains('Provider not found')) {
        message = 'This provider is no longer available.';
      } else {
        message = 'Could not send request. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cancelRequest() async {
    final leadId = _pendingLeadId;
    if (leadId == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await _leadsService.updateLeadStatus(leadId: leadId, status: 'cancelled');
      if (!mounted) return;
      setState(() {
        _relationship = 'none';
        _pendingLeadId = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('PublicProfile cancel request failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openMessage() async {
    if (_isNutritionist && _nutritionistAllowed == false) {
      await showNutritionistUpgradeSheet(context);
      return;
    }
    if (_relationship != 'accepted') {
      if (_isNutritionist && _nutritionistAllowed == false) {
        await showNutritionistUpgradeSheet(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to message and work together.'),
        ),
      );
      return;
    }
    if (!_canMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Messaging is available after your connection is accepted.',
          ),
        ),
      );
      return;
    }
    final convId =
        await MessagesRepository().createOrFindConversation(widget.userId);
    if (!mounted) return;
    if (convId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat')),
      );
      return;
    }
    context.push('/messaging/chat/$convId', extra: {
      'userName': _profile.fullName ?? widget.titleFallback ?? 'Provider',
      'avatarUrl': _profile.avatarUrl,
    });
  }

  Future<void> _openUpgrade() async {
    await showNutritionistUpgradeSheet(context);
  }

  Future<void> _toggleReviewEditor() async {
    if (!_canRate) return;
    if (!_reviewEditorOpen && _myReview == null) {
      ProviderReview? mine;
      try {
        mine = await _reviewsRepo
            .getMyReviewForProvider(widget.userId)
            .timeout(_timeout);
      } catch (_) {
        mine = null;
      }
      if (!mounted) return;
      setState(() {
        _myReview = mine;
        _reviewEditorOpen = true;
      });
      return;
    }
    setState(() => _reviewEditorOpen = !_reviewEditorOpen);
  }

  Future<void> _onReviewSaved() async {
    if (!mounted) return;
    final wasUpdate = _myReview != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasUpdate ? 'Review updated' : 'Thank you for your review',
        ),
      ),
    );
    setState(() => _reviewEditorOpen = false);
    await _load();
    if (!mounted) return;
    ref.invalidate(acceptedClientTrainersProvider);
    ref.invalidate(acceptedClientNutritionistsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight
        ? DesignTokens.lightPageBackground
        : DesignTokens.darkBackground;
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final cardBg = isLight
        ? DesignTokens.lightMutedCardBackground
        : const Color(0xFF121212);
    final chipBg =
        isLight ? const Color(0xFFEEEEF0) : const Color(0xFF1A1A1A);
    final p = _profile;
    final title =
        p.fullName ?? _username ?? widget.titleFallback ?? 'Provider';
    final professionalTitle =
        (p.professionalHeadline ?? '').trim().isNotEmpty
            ? p.professionalHeadline!.trim()
            : p.roleLabel;
    final experienceValue =
        (p.experienceYears != null && p.experienceYears! > 0)
            ? '${p.experienceYears} yrs'
            : '—';
    final reviewsValue =
        p.totalReviews > 0 ? p.rating.toStringAsFixed(1) : '—';

    return CotrainrPopScope(
      fallbackRoute: '/home',
      child: Scaffold(
        backgroundColor: bg,
        body: RefreshIndicator(
          color: DesignTokens.accentOrange,
          backgroundColor: cardBg,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.zero,
            children: [
              SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const CotrainrBackButton(fallbackRoute: '/home'),
                    const Spacer(),
                    if (_refreshing)
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DesignTokens.accentOrange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PublicProviderIdentityHeader(
                name: title,
                username: _username,
                professionalTitle: professionalTitle,
                trainerType: !_isNutritionist && p.specializationIds.isNotEmpty
                    ? p.specializationIds.first
                    : (!_isNutritionist ? professionalTitle : null),
                avatarUrl: p.avatarUrl,
                verified: p.verified,
                isNutritionist: _isNutritionist,
              ),
              PublicProviderHeaderStats(
                experienceValue: experienceValue,
                clientsValue: '$_clientCount',
                reviewsValue: reviewsValue,
              ),

            // —— Actions ——
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ActionRow(
                relationship: _relationship,
                accepting: p.acceptingNewClients,
                busy: _actionBusy,
                canMessage: _canMessage,
                canRate: _canRate,
                roleLabel: p.roleLabel,
                isNutritionist: _isNutritionist,
                requiresUpgrade:
                    _isNutritionist && _nutritionistAllowed == false,
                onRequest: _sendRequest,
                onCancel: _cancelRequest,
                onMessage: _openMessage,
                onRate: _toggleReviewEditor,
                onUpgrade: _openUpgrade,
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _reviewEditorOpen
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: AnimatedOpacity(
                        opacity: _reviewEditorOpen ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: InlineProviderReviewEditor(
                          providerId: widget.userId,
                          initialReview: _myReview,
                          onSaved: _onReviewSaved,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // —— Tabs ——
            Material(
              color: bg,
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                labelColor: DesignTokens.accentOrange,
                unselectedLabelColor: textSecondary,
                indicatorColor: DesignTokens.accentOrange,
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),

            Divider(
              height: 1,
              color: isLight
                  ? DesignTokens.lightBorder
                  : Colors.white.withValues(alpha: 0.08),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: _buildTabBody(
                p,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                cardBg: cardBg,
                chipBg: chipBg,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTabBody(
    ProviderProfessionalProfile p, {
    required Color textPrimary,
    required Color textSecondary,
    required Color cardBg,
    required Color chipBg,
  }) {
    switch (_tabController.index) {
      case 1:
        return _ServicesBody(
          sessionModes: p.sessionModes,
          providerType: p.providerType,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
        );
      case 2:
        return _ReviewsBody(
          reviews: _reviews,
          rating: p.rating,
          total: p.totalReviews,
          canRate: _canRate,
          onRate: _toggleReviewEditor,
          roleLabel: p.roleLabel,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
        );
      case 0:
      default:
        return _ProfileTabBody(
          bio: p.bio,
          expanded: _bioExpanded,
          onToggleBio: () => setState(() => _bioExpanded = !_bioExpanded),
          languages: p.languages,
          specialties: p.specialtyLabels,
          certs: _certs,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          chipBg: chipBg,
        );
    }
  }
}

// —— Small shared pieces ——

class _ActionRow extends StatelessWidget {
  final String relationship;
  final bool accepting;
  final bool busy;
  final bool canMessage;
  final bool canRate;
  final String roleLabel;
  final bool isNutritionist;
  final bool requiresUpgrade;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final VoidCallback onMessage;
  final VoidCallback onRate;
  final VoidCallback onUpgrade;

  const _ActionRow({
    required this.relationship,
    required this.accepting,
    required this.busy,
    required this.canMessage,
    required this.canRate,
    required this.roleLabel,
    required this.isNutritionist,
    required this.requiresUpgrade,
    required this.onRequest,
    required this.onCancel,
    required this.onMessage,
    required this.onRate,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final requestPal = HomePremiumTheme.metricPalette(0, isLight);
    final pendingPal = HomePremiumTheme.metricPalette(1, isLight);
    final messagePal = HomePremiumTheme.metricPalette(2, isLight);
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    final showUpgradeCta =
        isNutritionist && requiresUpgrade && relationship == 'none';

    Widget primary;
    if (relationship == 'accepted') {
      primary = _TranslucentActionButton(
        onPressed: busy
            ? null
            : (requiresUpgrade ? onUpgrade : onMessage),
        icon: requiresUpgrade
            ? Icons.lock_outline_rounded
            : Icons.chat_bubble_outline_rounded,
        label: requiresUpgrade ? 'Upgrade to Message' : 'Message',
        accent: messagePal.accent,
        shape: shape,
      );
    } else if (relationship == 'pending') {
      primary = OutlinedButton(
        onPressed: busy ? null : onCancel,
        style: OutlinedButton.styleFrom(
          foregroundColor: pendingPal.accent,
          side: BorderSide(color: pendingPal.accent.withValues(alpha: 0.55)),
          minimumSize: const Size.fromHeight(50),
          shape: shape,
          backgroundColor: pendingPal.accent.withValues(alpha: 0.12),
        ),
        child: Text(
          busy ? 'Updating…' : 'Pending · Cancel',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    } else if (showUpgradeCta) {
      primary = _MetricFilledButton(
        onPressed: busy ? null : onUpgrade,
        icon: Icons.lock_outline_rounded,
        label: 'Upgrade Plan',
        palette: requestPal,
        shape: shape,
      );
    } else {
      primary = _MetricFilledButton(
        onPressed: (!accepting || busy) ? null : onRequest,
        icon: Icons.person_add_alt_1_rounded,
        label: !accepting
            ? 'Not accepting'
            : busy
                ? 'Sending…'
                : 'Request',
        palette: requestPal,
        shape: shape,
        enabled: accepting && !busy,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showUpgradeCta) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: DesignTokens.accentOrange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: DesignTokens.accentOrange.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect with this Nutritionist',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Available with ${SubscriptionPlans.nutritionistAccessPlansLabel} plans.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: primary),
            if (relationship != 'accepted') ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                height: 50,
                child: Material(
                  color: messagePal.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onMessage,
                    child: Icon(
                      requiresUpgrade && relationship == 'none'
                          ? Icons.lock_outline_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: messagePal.accent,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showUpgradeCta) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(
              'Continue Browsing',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
          ),
        ] else if (relationship == 'none') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: requestPal.accent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Connect to message and work together.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: requestPal.accent.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (relationship == 'accepted' && canRate) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: DesignTokens.accentOrange,
                ),
                const SizedBox(width: 6),
                Text(
                  'Review $roleLabel',
                  style: const TextStyle(
                    color: DesignTokens.accentOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Filled CTA with home metric ring-style gradient.
class _MetricFilledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final MetricPalette palette;
  final OutlinedBorder shape;
  final bool enabled;

  const _MetricFilledButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.palette,
    required this.shape,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onPressed != null;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: interactive
                  ? [palette.accent, palette.accentSoft]
                  : [
                      palette.accent.withValues(alpha: 0.35),
                      palette.accentSoft.withValues(alpha: 0.25),
                    ],
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black,
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

/// Soft translucent CTA (used for Message on provider profiles).
class _TranslucentActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color accent;
  final OutlinedBorder shape;

  const _TranslucentActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.accent,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = enabled ? accent : accent.withValues(alpha: 0.45);
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: Material(
        color: accent.withValues(alpha: enabled ? 0.14 : 0.08),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// —— Tab bodies ——

class _ProfileTabBody extends StatelessWidget {
  final String? bio;
  final bool expanded;
  final VoidCallback onToggleBio;
  final List<String> languages;
  final List<String> specialties;
  final List<ProviderCertification> certs;
  final Color textPrimary;
  final Color textSecondary;
  final Color chipBg;

  const _ProfileTabBody({
    required this.bio,
    required this.expanded,
    required this.onToggleBio,
    required this.languages,
    required this.specialties,
    required this.certs,
    required this.textPrimary,
    required this.textSecondary,
    required this.chipBg,
  });

  @override
  Widget build(BuildContext context) {
    final bioText = (bio ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Me',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (bioText.isEmpty)
          Text(
            'No bio yet.',
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          )
        else ...[
          Text(
            bioText,
            maxLines: expanded ? null : 4,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (bioText.length > 160)
            TextButton(
              onPressed: onToggleBio,
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.accentOrange,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                expanded ? 'Show less' : 'Read more',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
        const SizedBox(height: 24),
        Text(
          'Specializations',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (specialties.isEmpty)
          Text(
            'No specialties listed yet.',
            style: TextStyle(color: textSecondary),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialties
                .map(
                  (s) => ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 64,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: DesignTokens.accentOrange,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              s,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 24),
        Text(
          'Languages',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          languages.isEmpty ? '—' : languages.join(', '),
          style: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Certifications',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (certs.isEmpty)
          Text(
            'No certifications listed yet.',
            style: TextStyle(color: textSecondary),
          )
        else
          ...certs.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: DesignTokens.accentOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((c.issuingOrganization ?? '').trim().isNotEmpty ||
                            c.issueYear != null)
                          Text(
                            [
                              if ((c.issuingOrganization ?? '').trim().isNotEmpty)
                                c.issuingOrganization!.trim(),
                              if (c.issueYear != null) '${c.issueYear}',
                            ].join(' · '),
                            style: TextStyle(color: textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ServicesBody extends StatelessWidget {
  final List<String> sessionModes;
  final String providerType;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBg;

  const _ServicesBody({
    required this.sessionModes,
    required this.providerType,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session modes',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (sessionModes.isEmpty)
          Text(
            'No session modes listed yet.',
            style: TextStyle(color: textSecondary),
          )
        else
          ...sessionModes.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: DesignTokens.accentOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ProviderSessionModes.labelFor(m, role: providerType),
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewsBody extends StatelessWidget {
  final List<ProviderReview> reviews;
  final double rating;
  final int total;
  final bool canRate;
  final VoidCallback onRate;
  final String roleLabel;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBg;

  const _ReviewsBody({
    required this.reviews,
    required this.rating,
    required this.total,
    required this.canRate,
    required this.onRate,
    required this.roleLabel,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: DesignTokens.accentOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                total > 0
                    ? '${rating.toStringAsFixed(1)} · $total reviews'
                    : 'No reviews yet',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ),
            if (canRate)
              TextButton(
                onPressed: onRate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: DesignTokens.accentOrange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Review $roleLabel',
                      style: const TextStyle(
                        color: DesignTokens.accentOrange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (reviews.isEmpty)
          Text(
            'Be the first to leave a review after connecting.',
            style: TextStyle(color: textSecondary),
          )
        else
          ...reviews.map(
            (r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⭐ ${r.rating}  ·  ${r.reviewerName}',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((r.body ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      r.body!.trim(),
                      style: TextStyle(
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

