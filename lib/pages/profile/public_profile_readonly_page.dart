import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_professional_profile.dart';
import '../../models/provider_specialty_taxonomy.dart';
import '../../providers/accepted_client_trainers_provider.dart';
import '../../providers/provider_professional_provider.dart';
import '../../repositories/messages_repository.dart';
import '../../repositories/provider_reviews_repository.dart';
import '../../services/leads_service.dart';
import '../../services/messaging_policy_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/provider/provider_avatar.dart';

/// Public provider profile — Cotrainr dark UI (hero + stats + Request + tabs).
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
  String? _coverUrl;
  int _clientCount = 0;
  bool _bioExpanded = false;
  List<ProviderReview> _reviews = [];
  bool _canRate = false;
  late ProviderProfessionalProfile _profile;
  List<ProviderCertification> _certs = [];
  String _relationship = 'none';
  String? _pendingLeadId;
  bool _canMessage = false;
  bool _actionBusy = false;

  static const _tabs = [
    'About',
    'Expertise',
    'Services',
    'Reviews',
    'Gallery',
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
      if (needsName || needsBio || needsAvatar) {
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
        final rows = await _withTimeout(
          _supabase
              .from('leads')
              .select('id')
              .eq('provider_id', widget.userId)
              .eq('status', 'accepted'),
          label: 'clientCount',
        );
        if (rows is List) {
          clientCount = (rows as List).length;
        }
      } catch (_) {}

      final canRate = await _withTimeout(
            _resolveCanRate(resolved.providerType),
            label: 'canRate',
          ) ??
          false;

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

      if (!mounted) return;
      setState(() {
        _profile = resolved;
        _certs = certs;
        _username = username;
        _coverUrl = (coverUrl != null && coverUrl.trim().isNotEmpty)
            ? coverUrl
            : resolved.avatarUrl;
        _clientCount = clientCount;
        _reviews = reviews;
        _canRate = canRate;
        _relationship = relationship;
        _pendingLeadId = pendingLeadId;
        _canMessage = canMessage;
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
    setState(() => _actionBusy = true);
    try {
      final result = await _leadsService.createLead(providerId: widget.userId);
      if (!mounted) return;
      setState(() {
        _relationship = 'pending';
        _pendingLeadId = result.leadId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openMessage() async {
    if (_relationship != 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to message and work together.'),
        ),
      );
      return;
    }
    if (!_canMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Messaging requires an active subscription with this provider.',
          ),
          action: SnackBarAction(
            label: 'Plans',
            onPressed: () => context.push('/subscription'),
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

  Future<void> _openRate() async {
    final result = await context.push<bool>(
      '/providers/${widget.userId}/review',
      extra: {
        'titleFallback': _profile.fullName ?? widget.titleFallback,
        'providerType': _profile.providerType,
        'avatarUrl': _profile.avatarUrl,
      },
    );
    if (result == true && mounted) {
      await _load();
      ref.invalidate(acceptedClientTrainersProvider);
      ref.invalidate(acceptedClientNutritionistsProvider);
    }
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
    final heroUrl = (_coverUrl != null && _coverUrl!.trim().isNotEmpty)
        ? _coverUrl
        : p.avatarUrl;

    return Scaffold(
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
            // —— Hero ——
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _HeroImage(url: heroUrl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          bg,
                        ],
                        stops: const [0, 0.4, 1],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _RoundIcon(
                            Icons.arrow_back_rounded,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                          ),
                          const Spacer(),
                          if (_refreshing)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DesignTokens.accentOrange,
                                ),
                              ),
                            ),
                          _RoundIcon(Icons.ios_share_rounded, onTap: () {}),
                          _RoundIcon(Icons.more_horiz_rounded, onTap: () {}),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // —— Identity ——
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ProviderAvatar(
                      imageUrl: p.avatarUrl,
                      name: title,
                      size: 72,
                      borderRadius: 16,
                      verified: p.verified,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (p.professionalHeadline ?? p.roleLabel).trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            if ((_username ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '@$_username',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // —— Stats (single accent) ——
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Row(
                children: [
                  _StatCell(
                    icon: Icons.star_rounded,
                    value: p.totalReviews > 0
                        ? p.rating.toStringAsFixed(1)
                        : 'New',
                    label: p.totalReviews > 0
                        ? '${p.totalReviews} reviews'
                        : 'No reviews',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _StatCell(
                    icon: Icons.work_outline_rounded,
                    value: (p.experienceYears != null &&
                            p.experienceYears! > 0)
                        ? '${p.experienceYears} yrs'
                        : '—',
                    label: 'Experience',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _StatCell(
                    icon: Icons.groups_rounded,
                    value: _clientCount > 0 ? '$_clientCount' : '—',
                    label: 'Clients',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _StatCell(
                    icon: Icons.place_outlined,
                    value: _shortLoc(p.primaryLocationLabel),
                    label: 'Location',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
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
                onRequest: _sendRequest,
                onCancel: _cancelRequest,
                onMessage: _openMessage,
                onRate: _openRate,
              ),
            ),

            const SizedBox(height: 12),

            // —— Tabs ——
            Material(
              color: bg,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
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
        return _ExpertiseBody(
          specialties: p.specialtyLabels,
          certs: _certs,
          languages: p.languages,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          chipBg: chipBg,
        );
      case 2:
        return _ServicesBody(
          sessionModes: p.sessionModes,
          providerType: p.providerType,
          location: p.primaryLocationLabel,
          accepting: p.acceptingNewClients,
          hourlyRate: p.hourlyRate,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
        );
      case 3:
        return _ReviewsBody(
          reviews: _reviews,
          rating: p.rating,
          total: p.totalReviews,
          canRate: _canRate,
          onRate: _openRate,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
        );
      case 4:
        return _GalleryBody(
          coverUrl: _coverUrl,
          avatarUrl: p.avatarUrl,
          textSecondary: textSecondary,
          cardBg: cardBg,
        );
      case 0:
      default:
        return _AboutBody(
          bio: p.bio,
          expanded: _bioExpanded,
          onToggleBio: () => setState(() => _bioExpanded = !_bioExpanded),
          experienceYears: p.experienceYears,
          sessionModes: p.sessionModes,
          providerType: p.providerType,
          clientCount: _clientCount,
          languages: p.languages,
          specialties: p.specialtyLabels,
          location: p.primaryLocationLabel,
          coverageKm: p.coverageKm,
          accepting: p.acceptingNewClients,
          hourlyRate: p.hourlyRate,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBg: cardBg,
          chipBg: chipBg,
        );
    }
  }

  String _shortLoc(String? location) {
    final loc = (location ?? '').trim();
    if (loc.isEmpty) return '—';
    return loc.length > 10 ? '${loc.substring(0, 9)}…' : loc;
  }
}

// —— Small shared pieces ——

class _HeroImage extends StatelessWidget {
  final String? url;
  const _HeroImage({this.url});

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    if (u != null && u.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1808), Color(0xFF000000), Color(0xFF111111)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fitness_center_rounded,
          size: 64,
          color: DesignTokens.accentOrange.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon(this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color textPrimary;
  final Color textSecondary;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: DesignTokens.accentOrange),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String relationship;
  final bool accepting;
  final bool busy;
  final bool canMessage;
  final bool canRate;
  final String roleLabel;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final VoidCallback onMessage;
  final VoidCallback onRate;

  const _ActionRow({
    required this.relationship,
    required this.accepting,
    required this.busy,
    required this.canMessage,
    required this.canRate,
    required this.roleLabel,
    required this.onRequest,
    required this.onCancel,
    required this.onMessage,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Metric palette: 0 steps (Request), 1 calories (Pending), 2 water (Message), 3 distance (Rate)
    final requestPal = HomePremiumTheme.metricPalette(0, isLight);
    final pendingPal = HomePremiumTheme.metricPalette(1, isLight);
    final messagePal = HomePremiumTheme.metricPalette(2, isLight);
    final ratePal = HomePremiumTheme.metricPalette(3, isLight);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    Widget primary;
    if (relationship == 'accepted') {
      primary = _MetricFilledButton(
        onPressed: busy ? null : onMessage,
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Message',
        palette: messagePal,
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
      children: [
        Row(
          children: [
            Expanded(child: primary),
            if (relationship != 'accepted') ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                height: 50,
                child: Material(
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          messagePal.accent,
                          messagePal.accentSoft,
                        ],
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onMessage,
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (relationship == 'none') ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: requestPal.accent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                'Connect to message and work together.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: requestPal.accent.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ],
        if (relationship == 'accepted' && canRate) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRate,
            child: Text(
              'Rate $roleLabel',
              style: TextStyle(
                color: ratePal.accent,
                fontWeight: FontWeight.w700,
              ),
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

// —— Tab bodies ——

class _AboutBody extends StatelessWidget {
  final String? bio;
  final bool expanded;
  final VoidCallback onToggleBio;
  final int? experienceYears;
  final List<String> sessionModes;
  final String providerType;
  final int clientCount;
  final List<String> languages;
  final List<String> specialties;
  final String? location;
  final double? coverageKm;
  final bool accepting;
  final double? hourlyRate;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBg;
  final Color chipBg;

  const _AboutBody({
    required this.bio,
    required this.expanded,
    required this.onToggleBio,
    required this.experienceYears,
    required this.sessionModes,
    required this.providerType,
    required this.clientCount,
    required this.languages,
    required this.specialties,
    required this.location,
    required this.coverageKm,
    required this.accepting,
    required this.hourlyRate,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBg,
    required this.chipBg,
  });

  @override
  Widget build(BuildContext context) {
    final bioText = (bio ?? '').trim();
    final trainingType = sessionModes.isEmpty
        ? '—'
        : sessionModes
            .map((m) => ProviderSessionModes.labelFor(m, role: providerType))
            .join(' & ');

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
        const SizedBox(height: 20),
        Text(
          'Highlights',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _HighlightTile(
              icon: Icons.work_outline_rounded,
              title: (experienceYears != null && experienceYears! > 0)
                  ? '$experienceYears years'
                  : '—',
              subtitle: 'Experience',
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _HighlightTile(
              icon: Icons.fitness_center_rounded,
              title: trainingType,
              subtitle: 'Training Type',
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _HighlightTile(
              icon: Icons.person_outline_rounded,
              title: clientCount > 0 ? '$clientCount+' : '—',
              subtitle: 'Clients Trained',
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _HighlightTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: languages.isEmpty ? '—' : languages.join(', '),
              subtitle: 'Languages',
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
        if (specialties.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Specializations',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialties
                .map(
                  (s) => Container(
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
                        Text(
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if ((location ?? '').trim().isNotEmpty ||
            (coverageKm != null && coverageKm! > 0) ||
            (hourlyRate != null && hourlyRate! > 0)) ...[
          const SizedBox(height: 20),
          Text(
            'Where We Can Meet',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if ((location ?? '').trim().isNotEmpty)
            Text(
              location!,
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            accepting ? 'Accepting new clients' : 'Not accepting new clients',
            style: TextStyle(
              color: accepting ? DesignTokens.accentGreen : textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;

  const _HighlightTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: DesignTokens.accentOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpertiseBody extends StatelessWidget {
  final List<String> specialties;
  final List<ProviderCertification> certs;
  final List<String> languages;
  final Color textPrimary;
  final Color textSecondary;
  final Color chipBg;

  const _ExpertiseBody({
    required this.specialties,
    required this.certs,
    required this.languages,
    required this.textPrimary,
    required this.textSecondary,
    required this.chipBg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  (s) => Chip(
                    avatar: const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: DesignTokens.accentOrange,
                    ),
                    label: Text(s),
                    backgroundColor: chipBg,
                    labelStyle: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
        if (languages.isNotEmpty) ...[
          const SizedBox(height: 20),
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
            languages.join(', '),
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (certs.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Certifications',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...certs.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.verified_outlined,
                color: DesignTokens.accentOrange,
              ),
              title: Text(
                c.name,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                [
                  if (c.issuingOrganization != null) c.issuingOrganization!,
                  if (c.issueYear != null) '${c.issueYear}',
                ].join(' · '),
                style: TextStyle(color: textSecondary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ServicesBody extends StatelessWidget {
  final List<String> sessionModes;
  final String providerType;
  final String? location;
  final bool accepting;
  final double? hourlyRate;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBg;

  const _ServicesBody({
    required this.sessionModes,
    required this.providerType,
    required this.location,
    required this.accepting,
    required this.hourlyRate,
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
                    Text(
                      ProviderSessionModes.labelFor(m, role: providerType),
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if ((location ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            location!,
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          accepting ? 'Accepting new clients' : 'Not accepting new clients',
          style: TextStyle(
            color: accepting ? DesignTokens.accentGreen : textSecondary,
            fontWeight: FontWeight.w800,
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
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBg;

  const _ReviewsBody({
    required this.reviews,
    required this.rating,
    required this.total,
    required this.canRate,
    required this.onRate,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ratePal = HomePremiumTheme.metricPalette(3, isLight);

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
                child: Text(
                  'Rate',
                  style: TextStyle(
                    color: ratePal.accent,
                    fontWeight: FontWeight.w800,
                  ),
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

class _GalleryBody extends StatelessWidget {
  final String? coverUrl;
  final String? avatarUrl;
  final Color textSecondary;
  final Color cardBg;

  const _GalleryBody({
    this.coverUrl,
    this.avatarUrl,
    required this.textSecondary,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    final images = <String>[
      if (coverUrl != null && coverUrl!.trim().isNotEmpty) coverUrl!,
      if (avatarUrl != null &&
          avatarUrl!.trim().isNotEmpty &&
          avatarUrl != coverUrl)
        avatarUrl!,
    ];

    if (images.isEmpty) {
      return Text(
        'No gallery photos yet.',
        style: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: images[i],
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              color: cardBg,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}
