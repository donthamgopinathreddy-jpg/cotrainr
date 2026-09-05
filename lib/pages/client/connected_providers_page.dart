import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/accepted_client_trainers_provider.dart';
import '../../providers/entitlements_provider.dart';
import '../../providers/leads_provider.dart';
import '../../repositories/provider_reviews_repository.dart';
import '../../services/leads_models.dart'
    show AcceptedProvider, EndConnectionResult;
import '../../theme/design_tokens.dart';
import '../../widgets/common/app_overlays.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/common/fade_slide_in.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/provider/connected_provider_card.dart';

/// Connected trainers and/or nutritionists for the signed-in client.
class ConnectedProvidersPage extends ConsumerStatefulWidget {
  /// `trainer` | `nutritionist` | `all`
  final String providerType;

  const ConnectedProvidersPage({
    super.key,
    required this.providerType,
  });

  @override
  ConsumerState<ConnectedProvidersPage> createState() =>
      _ConnectedProvidersPageState();
}

class _ConnectedProvidersPageState
    extends ConsumerState<ConnectedProvidersPage> {
  final Map<String, int?> _myRatings = {};
  final _reviewsRepo = ProviderReviewsRepository();
  String? _endingLeadId;

  bool get _isAll => widget.providerType == 'all';
  bool get _isNutritionist => widget.providerType == 'nutritionist';

  String get _title {
    if (_isAll) return 'Trainers & Nutritionists';
    return _isNutritionist ? 'Nutritionists' : 'Trainers';
  }

  IconData get _titleIcon {
    if (_isAll) return Icons.groups_rounded;
    return _isNutritionist
        ? Icons.restaurant_rounded
        : Icons.sports_rounded;
  }

  String get _browseLabel {
    if (_isAll) return 'Browse Discover';
    return _isNutritionist ? 'Browse Nutritionists' : 'Browse Trainers';
  }

  String get _emptyTitle {
    if (_isAll) return 'No connected coaches yet';
    return _isNutritionist
        ? 'No connected nutritionists yet'
        : 'No connected trainers yet';
  }

  AsyncValue<List<AcceptedProvider>> get _listAsync {
    if (_isAll) {
      final trainers = ref.watch(acceptedClientTrainersProvider);
      final nutritionists = ref.watch(acceptedClientNutritionistsProvider);
      if (trainers.isLoading || nutritionists.isLoading) {
        return const AsyncValue.loading();
      }
      if (trainers.hasError) {
        return AsyncValue.error(trainers.error!, StackTrace.current);
      }
      if (nutritionists.hasError) {
        return AsyncValue.error(nutritionists.error!, StackTrace.current);
      }
      final merged = <AcceptedProvider>[
        ...?trainers.value,
        ...?nutritionists.value,
      ];
      // Stable order: trainers first, then nutritionists; de-dupe by id.
      final seen = <String>{};
      final unique = <AcceptedProvider>[];
      for (final p in merged) {
        if (seen.add(p.providerId)) unique.add(p);
      }
      return AsyncValue.data(unique);
    }
    return _isNutritionist
        ? ref.watch(acceptedClientNutritionistsProvider)
        : ref.watch(acceptedClientTrainersProvider);
  }

  Future<void> _refreshQuiet() async {
    if (_isAll || !_isNutritionist) {
      await ref.read(acceptedClientTrainersProvider.notifier).refreshQuiet();
    }
    if (_isAll || _isNutritionist) {
      await ref
          .read(acceptedClientNutritionistsProvider.notifier)
          .refreshQuiet();
    }
  }

  void _refresh() {
    if (_isAll || !_isNutritionist) {
      ref.read(acceptedClientTrainersProvider.notifier).refresh();
    }
    if (_isAll || _isNutritionist) {
      ref.read(acceptedClientNutritionistsProvider.notifier).refresh();
    }
  }

  Future<void> _refreshAfterEnd() async {
    await Future.wait([
      ref.read(acceptedClientTrainersProvider.notifier).refreshQuiet(),
      ref.read(acceptedClientNutritionistsProvider.notifier).refreshQuiet(),
      ref.read(entitlementsProvider.notifier).refresh(),
    ]);
  }

  String _successMessage(EndConnectionResult result) {
    final restored = result.allowanceRestored == true ||
        result.restorationGranted == true;
    if (restored) {
      return 'Connection ended. Your connection allowance was restored.';
    }
    return 'Connection ended.';
  }

  Future<void> _showEndConnectionSheet(AcceptedProvider provider) async {
    if (_endingLeadId != null) return;
    if (provider.leadId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't end the connection. Please try again."),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return _EndConnectionSheet(
          onKeep: () => Navigator.of(ctx).pop(),
          onConfirm: (reason) async {
            if (_endingLeadId != null) return false;
            setState(() => _endingLeadId = provider.leadId);
            final trimmed = reason.trim();
            final effectiveReason =
                trimmed.isEmpty ? 'Ended by member' : trimmed;

            try {
              final result = await ref.read(leadsServiceProvider).endConnection(
                    leadId: provider.leadId,
                    reason: effectiveReason,
                  );
              if (!ctx.mounted) return true;
              Navigator.of(ctx).pop();
              if (!mounted) return true;
              await _refreshAfterEnd();
              if (!mounted) return true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_successMessage(result))),
              );
              return true;
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Couldn't end the connection. Please try again.",
                    ),
                  ),
                );
              }
              return false;
            } finally {
              if (mounted) {
                setState(() => _endingLeadId = null);
              }
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;

    final listAsync = _listAsync;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  CotrainrBackButton(fallbackRoute: '/home', color: textPrimary),
                  const SizedBox(width: 4),
                  Icon(_titleIcon, size: 22, color: DesignTokens.accentOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _title,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: listAsync.when(
                loading: () => _SkeletonList(isLight: isLight),
                error: (e, _) => _ErrorState(
                  message: e.toString().replaceFirst('Exception: ', ''),
                  onRetry: _refresh,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                data: (providers) {
                  if (providers.isEmpty) {
                    return _EmptyState(
                      title: _emptyTitle,
                      browseLabel: _browseLabel,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onBrowse: () {
                        HapticFeedback.lightImpact();
                        context.go(
                          _isNutritionist
                              ? '/home?tab=1&discover=nutritionists'
                              : '/home?tab=1&discover=trainers',
                        );
                      },
                    );
                  }
                  for (final p in providers) {
                    _ensureMyRating(p.providerId);
                  }
                  return RefreshIndicator(
                    color: DesignTokens.accentOrange,
                    onRefresh: _refreshQuiet,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: providers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final provider = providers[index];
                        return FadeSlideIn(
                          index: index,
                          child: ConnectedProviderCard(
                            data: ConnectedProviderCardData(
                              leadId: provider.leadId,
                              providerId: provider.providerId,
                              fullName: provider.fullName,
                              roleLabel: provider.roleLabel,
                              avatarUrl: provider.avatarUrl,
                              headlineOrSpecialty:
                                  provider.specializationLabel,
                              verified: provider.verified,
                              rating: provider.rating,
                              reviewCount: provider.reviewCount,
                              experienceYears: provider.experienceYears > 0
                                  ? provider.experienceYears
                                  : null,
                              myRating: _myRatings[provider.providerId],
                            ),
                            isLight: isLight,
                            onViewProfile: () => _openProfile(provider),
                            onRate: () => _openRate(provider),
                            onEndConnection: _endingLeadId != null
                                ? null
                                : () => _showEndConnectionSheet(provider),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureMyRating(String providerId) async {
    if (_myRatings.containsKey(providerId)) return;
    try {
      final mine = await _reviewsRepo.getMyReviewForProvider(providerId);
      if (!mounted) return;
      setState(() => _myRatings[providerId] = mine?.rating);
    } catch (_) {
      if (!mounted) return;
      setState(() => _myRatings[providerId] = null);
    }
  }

  void _openProfile(AcceptedProvider provider) {
    HapticFeedback.selectionClick();
    context.push(
      '/providers/${provider.providerId}',
      extra: {
        'titleFallback': provider.fullName,
        'providerType': provider.providerType,
      },
    );
  }

  Future<void> _openRate(AcceptedProvider provider) async {
    HapticFeedback.selectionClick();
    final result = await context.push<bool>(
      '/providers/${provider.providerId}/review',
      extra: {
        'titleFallback': provider.fullName,
        'providerType': provider.providerType,
        'avatarUrl': provider.avatarUrl,
      },
    );
    if (result == true && mounted) {
      _myRatings.remove(provider.providerId);
      await _ensureMyRating(provider.providerId);
      await _refreshQuiet();
    }
  }
}

/// Confirmation sheet for ending an accepted connection.
class _EndConnectionSheet extends StatefulWidget {
  final VoidCallback onKeep;
  final Future<bool> Function(String reason) onConfirm;

  const _EndConnectionSheet({
    required this.onKeep,
    required this.onConfirm,
  });

  @override
  State<_EndConnectionSheet> createState() => _EndConnectionSheetState();
}

class _EndConnectionSheetState extends State<_EndConnectionSheet> {
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onConfirm(_reasonController.text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final error = Theme.of(context).colorScheme.error;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final busy = _submitting;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'End connection?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ending this connection removes this provider from your active '
            'connections. Your previous messages will remain available.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reason (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonController,
            enabled: !busy,
            maxLines: 2,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Optional note',
              counterText: '',
              filled: true,
              fillColor: DesignTokens.surfaceOf(context).withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: textSecondary.withValues(alpha: 0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: textSecondary.withValues(alpha: 0.25),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: error,
              disabledBackgroundColor: error.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'End connection',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
          ),
          TextButton(
            onPressed: busy ? null : widget.onKeep,
            child: Text(
              'Keep connection',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyTrainersPage extends StatelessWidget {
  const MyTrainersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConnectedProvidersPage(providerType: 'all');
  }
}

class MyNutritionistsPage extends StatelessWidget {
  const MyNutritionistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConnectedProvidersPage(providerType: 'nutritionist');
  }
}

class _SkeletonList extends StatelessWidget {
  final bool isLight;
  const _SkeletonList({required this.isLight});

  @override
  Widget build(BuildContext context) {
    final card =
        isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 140,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String browseLabel;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onBrowse;

  const _EmptyState({
    required this.title,
    required this.browseLabel,
    required this.textPrimary,
    required this.textSecondary,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect from Discover to see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.accentOrange,
              ),
              child: Text(browseLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color textPrimary;
  final Color textSecondary;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
