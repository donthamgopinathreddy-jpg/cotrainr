import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_professional_profile.dart';
import '../../models/provider_specialty_taxonomy.dart';
import '../../models/subscription_plans.dart';
import '../../providers/provider_professional_provider.dart';
import '../../repositories/provider_reviews_repository.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../services/messaging_policy_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/provider/rate_provider_sheet.dart';

/// Read-only provider profile for Discover / messaging with reviews.
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
    extends ConsumerState<PublicProfileReadonlyPage> {
  final _supabase = Supabase.instance.client;
  final _reviewsRepo = ProviderReviewsRepository();
  final _subsRepo = SubscriptionsRepository();

  bool _loading = true;
  String? _username;
  List<ProviderReview> _reviews = [];
  bool _canRate = false;
  ProviderProfessionalProfile? _profile;
  List<ProviderCertification> _certs = [];
  bool _hasAcceptedLead = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(providerProfessionalRepositoryProvider);
      final profile = await repo.fetchByUserId(widget.userId);
      final certs = await repo.listCertifications(
        widget.userId,
        publicOnly: true,
      );

      String? username;
      try {
        final list = (await _supabase.rpc(
          'get_public_profile',
          params: {'p_user_id': widget.userId},
        ) as List)
            .cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          username = list.first['username'] as String?;
        }
      } catch (_) {}

      final reviews = await _reviewsRepo.listForProvider(widget.userId);
      final providerType =
          profile?.providerType ?? widget.providerType;
      final canRate = await _resolveCanRate(providerType);
      final me = _supabase.auth.currentUser?.id;
      var leadOk = false;
      if (me != null && providerType != null) {
        leadOk = await MessagingPolicyService.hasAcceptedLead(
          supabase: _supabase,
          clientId: me,
          providerId: widget.userId,
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _certs = certs;
        _username = username;
        _reviews = reviews;
        _canRate = canRate;
        _hasAcceptedLead = leadOk;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _resolveCanRate(String? providerType) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null || providerType == null) return false;
    if (providerType != 'trainer' && providerType != 'nutritionist') {
      return false;
    }

    final sub = await _subsRepo.fetchMine();
    final plan = sub?.plan ?? SubscriptionPlans.free;
    if (!SubscriptionPlans.canWriteReviews(plan)) return false;
    if (providerType == 'nutritionist' &&
        !SubscriptionPlans.canReviewNutritionist(plan)) {
      return false;
    }

    return MessagingPolicyService.hasAcceptedLead(
      supabase: _supabase,
      clientId: me,
      providerId: widget.userId,
    );
  }

  Future<void> _openRateSheet() async {
    final label =
        _profile?.providerType == 'nutritionist' ? 'Nutritionist' : 'Trainer';
    final submitted = await showRateProviderSheet(
      context: context,
      providerLabel: _profile?.fullName ?? label,
      onSubmit: (rating, body) => _reviewsRepo.submitReview(
        providerId: widget.userId,
        rating: rating,
        body: body,
      ),
    );
    if (submitted == true && mounted) {
      HapticFeedback.mediumImpact();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your review')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _profile;
    final title =
        p?.fullName ?? _username ?? widget.titleFallback ?? 'Profile';
    final isProvider = p != null;
    final ratingLabel = (p == null || p.totalReviews <= 0)
        ? 'New'
        : '⭐ ${p.rating.toStringAsFixed(1)} (${p.totalReviews})';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                HubSectionCard(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: cs.primary.withValues(alpha: 0.12),
                        backgroundImage: p?.avatarUrl != null &&
                                p!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(p.avatarUrl!)
                            : null,
                        child: p?.avatarUrl == null || p!.avatarUrl!.isEmpty
                            ? Text(
                                title.isNotEmpty
                                    ? title[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AccountHubTheme.rowTitle(context),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (p?.verified == true) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: DesignTokens.accentOrange,
                            ),
                          ],
                        ],
                      ),
                      if (_username != null && _username!.isNotEmpty)
                        Text(
                          '@$_username',
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                      if (isProvider) ...[
                        const SizedBox(height: 6),
                        Text(
                          p.roleLabel,
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                        if ((p.professionalHeadline ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            p.professionalHeadline!.trim(),
                            textAlign: TextAlign.center,
                            style: AccountHubTheme.rowTitle(context)
                                .copyWith(fontSize: 15),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          ratingLabel,
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isProvider) ...[
                  if ((p.bio ?? '').trim().isNotEmpty)
                    _section(
                      context,
                      title: 'About',
                      child: Text(
                        p.bio!.trim(),
                        style: AccountHubTheme.rowSubtitle(context)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  if (p.experienceLabel != null)
                    _section(
                      context,
                      title: 'Experience',
                      child: Text(
                        p.experienceLabel!,
                        style: AccountHubTheme.rowSubtitle(context),
                      ),
                    ),
                  if (p.specialtyLabels.isNotEmpty)
                    _section(
                      context,
                      title: 'Specialties',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.specialtyLabels
                            .map((l) => Chip(label: Text(l)))
                            .toList(),
                      ),
                    ),
                  if (p.languages.isNotEmpty)
                    _section(
                      context,
                      title: 'Languages',
                      child: Text(
                        p.languages.join(', '),
                        style: AccountHubTheme.rowSubtitle(context),
                      ),
                    ),
                  _section(
                    context,
                    title: 'Services',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.sessionModes.isNotEmpty)
                          Text(
                            p.sessionModes
                                .map(
                                  (m) => ProviderSessionModes.labelFor(
                                    m,
                                    role: p.providerType,
                                  ),
                                )
                                .join(' · '),
                            style: AccountHubTheme.rowSubtitle(context),
                          ),
                        if (p.primaryLocationLabel != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            p.primaryLocationLabel!,
                            style: AccountHubTheme.rowSubtitle(context),
                          ),
                        ],
                        if (p.coverageKm != null && p.coverageKm! > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Service area: ${p.coverageKm!.toStringAsFixed(0)} km',
                            style: AccountHubTheme.rowSubtitle(context),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          p.acceptingNewClients
                              ? 'Accepting new clients'
                              : 'Not currently accepting new clients',
                          style: AccountHubTheme.rowSubtitle(context).copyWith(
                                color: p.acceptingNewClients
                                    ? DesignTokens.accentOrange
                                    : null,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (p.hourlyRate != null && p.hourlyRate! > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            'From ${p.hourlyRate!.toStringAsFixed(0)} / session',
                            style: AccountHubTheme.rowSubtitle(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_certs.isNotEmpty)
                    _section(
                      context,
                      title: 'Certifications',
                      child: Column(
                        children: _certs.map((c) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.name),
                            subtitle: Text(
                              [
                                if (c.issuingOrganization != null)
                                  c.issuingOrganization!,
                                if (c.issueYear != null) '${c.issueYear}',
                                if (c.expiryYear != null)
                                  'exp ${c.expiryYear}',
                                if (c.verificationStatus == 'verified')
                                  'Verified',
                              ].join(' · '),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (!_hasAcceptedLead) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: p.acceptingNewClients
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Send a request from Discover to connect with this provider.',
                                  ),
                                ),
                              );
                              context.go('/home?tab=1');
                            }
                          : null,
                      child: Text(
                        p.acceptingNewClients
                            ? 'Request coaching'
                            : 'Not accepting clients',
                      ),
                    ),
                  ],
                  if (_canRate) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _openRateSheet,
                      child: Text(
                        p.providerType == 'nutritionist'
                            ? 'Rate Nutritionist'
                            : 'Rate Trainer',
                      ),
                    ),
                  ],
                  if (_reviews.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Reviews',
                      style: AccountHubTheme.rowTitle(context),
                    ),
                    const SizedBox(height: 8),
                    ..._reviews.map(
                      (r) => HubSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('⭐ ${r.rating}'),
                            if ((r.body ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(r.body!.trim()),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: HubSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AccountHubTheme.rowTitle(context)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
