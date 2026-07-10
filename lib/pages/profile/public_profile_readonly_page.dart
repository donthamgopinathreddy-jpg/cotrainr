import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/subscription_plans.dart';
import '../../repositories/provider_reviews_repository.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../services/messaging_policy_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/provider/rate_provider_sheet.dart';

/// Read-only provider profile for Discover / messaging with reviews.
class PublicProfileReadonlyPage extends StatefulWidget {
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
  State<PublicProfileReadonlyPage> createState() => _PublicProfileReadonlyPageState();
}

class _PublicProfileReadonlyPageState extends State<PublicProfileReadonlyPage> {
  final _supabase = Supabase.instance.client;
  final _reviewsRepo = ProviderReviewsRepository();
  final _subsRepo = SubscriptionsRepository();

  bool _loading = true;
  String? _fullName;
  String? _username;
  String? _bio;
  String? _avatarUrl;
  String? _role;
  String? _resolvedProviderType;
  double _rating = 0;
  int _reviewCount = 0;
  List<ProviderReview> _reviews = [];
  bool _canRate = false;
  String _rateButtonLabel = 'Rate';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = (await _supabase.rpc(
        'get_public_profile',
        params: {'p_user_id': widget.userId},
      ) as List)
          .cast<Map<String, dynamic>>();
      final p = list.isNotEmpty ? list.first : null;

      String? providerType = widget.providerType;
      double rating = 0;
      int reviewCount = 0;
      if (providerType == null ||
          providerType == 'trainer' ||
          providerType == 'nutritionist') {
        final prov = await _supabase
            .from('providers')
            .select('provider_type, rating, total_reviews')
            .eq('user_id', widget.userId)
            .maybeSingle();
        if (prov != null) {
          providerType = prov['provider_type']?.toString();
          rating = (prov['rating'] as num?)?.toDouble() ?? 0;
          reviewCount = (prov['total_reviews'] as num?)?.toInt() ?? 0;
        }
      }

      final reviews = await _reviewsRepo.listForProvider(widget.userId);
      final canRate = await _resolveCanRate(providerType);

      if (!mounted) return;
      setState(() {
        _fullName = p?['full_name'] as String?;
        _username = p?['username'] as String?;
        _bio = p?['bio'] as String?;
        _avatarUrl = p?['avatar_url'] as String?;
        _role = p?['role'] as String?;
        _resolvedProviderType = providerType;
        _rating = rating;
        _reviewCount = reviewCount;
        _reviews = reviews;
        _canRate = canRate;
        _rateButtonLabel = providerType == 'nutritionist'
            ? 'Rate Nutritionist'
            : 'Rate Trainer';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _resolveCanRate(String? providerType) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null || providerType == null) return false;
    if (providerType != 'trainer' && providerType != 'nutritionist') return false;

    final sub = await _subsRepo.fetchMine();
    final plan = sub?.plan ?? SubscriptionPlans.free;
    if (!SubscriptionPlans.canWriteReviews(plan)) return false;
    if (providerType == 'nutritionist' &&
        !SubscriptionPlans.canReviewNutritionist(plan)) {
      return false;
    }

    final leadOk = await MessagingPolicyService.hasAcceptedLead(
      supabase: _supabase,
      clientId: me,
      providerId: widget.userId,
    );
    return leadOk;
  }

  String get _ratingLabel {
    if (_reviewCount <= 0) return 'New';
    return '⭐ ${_rating.toStringAsFixed(1)} ($_reviewCount)';
  }

  Future<void> _openRateSheet() async {
    final label = _resolvedProviderType == 'nutritionist' ? 'Nutritionist' : 'Trainer';
    final submitted = await showRateProviderSheet(
      context: context,
      providerLabel: _fullName ?? label,
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
    final title = _fullName ?? _username ?? widget.titleFallback ?? 'Profile';
    final isProvider =
        _resolvedProviderType == 'trainer' || _resolvedProviderType == 'nutritionist';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
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
                        backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null || _avatarUrl!.isEmpty
                            ? Text(
                                title.isNotEmpty ? title[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(title, style: AccountHubTheme.rowTitle(context)),
                      if (_username != null && _username!.isNotEmpty)
                        Text(
                          '@$_username',
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                      if (isProvider) ...[
                        const SizedBox(height: 8),
                        Text(_ratingLabel, style: AccountHubTheme.rowSubtitle(context)),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        _bio?.trim().isNotEmpty == true ? _bio! : 'No bio yet.',
                        textAlign: TextAlign.center,
                        style: AccountHubTheme.rowSubtitle(context).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (isProvider) ...[
                  if (_canRate) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openRateSheet,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: Text(_rateButtonLabel),
                    ),
                  ],
                  const SizedBox(height: 12),
                  HubSectionCard(
                    title: 'Reviews',
                    child: _reviews.isEmpty
                        ? Text(
                            'No reviews yet.',
                            style: AccountHubTheme.rowSubtitle(context),
                          )
                        : Column(
                            children: _reviews.map((r) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ...List.generate(
                                          5,
                                          (i) => Icon(
                                            i < r.rating
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            size: 16,
                                            color: AccountHubTheme.subscriptionAmber,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          r.reviewerName,
                                          style: AccountHubTheme.rowSubtitle(context),
                                        ),
                                      ],
                                    ),
                                    if (r.body != null && r.body!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        r.body!,
                                        style: AccountHubTheme.rowSubtitle(context)
                                            .copyWith(height: 1.35),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}
