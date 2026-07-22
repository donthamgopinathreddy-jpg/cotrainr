import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/accepted_client_trainers_provider.dart';
import '../../repositories/messages_repository.dart';
import '../../services/leads_models.dart' show AcceptedTrainer;
import '../../services/messaging_policy_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/home_v3/home_premium_theme.dart';

/// Client screen listing accepted trainers from `leads` (status = accepted).
class MyTrainersPage extends ConsumerStatefulWidget {
  const MyTrainersPage({super.key});

  @override
  ConsumerState<MyTrainersPage> createState() => _MyTrainersPageState();
}

class _MyTrainersPageState extends ConsumerState<MyTrainersPage> {
  final Map<String, bool> _canMessageByTrainer = {};
  final Set<String> _messagingCheckInFlight = {};

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;
    final trainersAsync = ref.watch(acceptedClientTrainersProvider);

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
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.sports_rounded,
                    size: 22,
                    color: DesignTokens.accentOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'My Trainers',
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
              child: trainersAsync.when(
                loading: () => _SkeletonList(isLight: isLight),
                error: (e, _) => _ErrorState(
                  message: e.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref
                      .read(acceptedClientTrainersProvider.notifier)
                      .refresh(),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                data: (trainers) {
                  if (trainers.isEmpty) {
                    return _EmptyState(
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onFindTrainers: () {
                        HapticFeedback.lightImpact();
                        // Discover is home shell tab 1 for clients.
                        context.go('/home?tab=1');
                      },
                    );
                  }
                  for (final t in trainers) {
                    _ensureMessagingPermission(t.trainerId);
                  }
                  return RefreshIndicator(
                    color: DesignTokens.accentOrange,
                    onRefresh: () => ref
                        .read(acceptedClientTrainersProvider.notifier)
                        .refreshQuiet(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: trainers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final trainer = trainers[index];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 220 + (index * 40)),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) {
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, 12 * (1 - t)),
                                child: child,
                              ),
                            );
                          },
                          child: _TrainerCard(
                            trainer: trainer,
                            isLight: isLight,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            canMessage:
                                _canMessageByTrainer[trainer.trainerId] == true,
                            messagingChecked:
                                _canMessageByTrainer.containsKey(trainer.trainerId),
                            onViewProfile: () => _openProfile(trainer),
                            onMessage: () => _openMessage(trainer),
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

  Future<void> _ensureMessagingPermission(String trainerId) async {
    if (_canMessageByTrainer.containsKey(trainerId) ||
        _messagingCheckInFlight.contains(trainerId)) {
      return;
    }
    _messagingCheckInFlight.add(trainerId);
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) {
      _messagingCheckInFlight.remove(trainerId);
      return;
    }
    final ok = await MessagingPolicyService.clientMayUseMessagingWithProvider(
      supabase: Supabase.instance.client,
      clientId: me,
      providerId: trainerId,
    );
    if (!mounted) return;
    setState(() {
      _canMessageByTrainer[trainerId] = ok;
      _messagingCheckInFlight.remove(trainerId);
    });
  }

  void _openProfile(AcceptedTrainer trainer) {
    HapticFeedback.selectionClick();
    context.push(
      '/providers/${trainer.trainerId}',
      extra: {
        'titleFallback': trainer.fullName,
        'providerType': 'trainer',
      },
    );
  }

  Future<void> _openMessage(AcceptedTrainer trainer) async {
    HapticFeedback.lightImpact();
    final canMessage = _canMessageByTrainer[trainer.trainerId] == true;
    if (!canMessage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Messaging requires an active subscription with this trainer.',
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
        await MessagesRepository().createOrFindConversation(trainer.trainerId);
    if (!mounted) return;
    if (convId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open chat. Please try again.'),
        ),
      );
      return;
    }
    context.push('/messaging/chat/$convId', extra: {
      'userName': trainer.fullName,
      'isOnline': false,
      'avatarUrl': trainer.avatarUrl,
    });
  }
}

class _TrainerCard extends StatelessWidget {
  final AcceptedTrainer trainer;
  final bool isLight;
  final Color textPrimary;
  final Color textSecondary;
  final bool canMessage;
  final bool messagingChecked;
  final VoidCallback onViewProfile;
  final VoidCallback onMessage;

  const _TrainerCard({
    required this.trainer,
    required this.isLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.canMessage,
    required this.messagingChecked,
    required this.onViewProfile,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isLight ? HomePremiumTheme.lightCreamCard : HomePremiumTheme.darkCard;
    final messageEnabled = canMessage;

    return PressableCard(
      onTap: onViewProfile,
      borderRadius: 20,
      pressScale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: DesignTokens.accentOrange.withValues(alpha: 0.18),
          ),
          boxShadow: HomePremiumTheme.softCardShadow(isLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(url: trainer.avatarUrl, name: trainer.fullName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trainer.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (trainer.verified)
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: DesignTokens.accentOrange,
                            ),
                        ],
                      ),
                      if (trainer.specializationLabel != null &&
                          trainer.specializationLabel!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          trainer.specializationLabel!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (trainer.experienceYears > 0)
                            _MetaChip(
                              icon: Icons.timeline_rounded,
                              label: '${trainer.experienceYears} yrs exp',
                              isLight: isLight,
                            ),
                          if (trainer.rating > 0)
                            _MetaChip(
                              icon: Icons.star_rounded,
                              label: trainer.reviewCount > 0
                                  ? '${trainer.rating.toStringAsFixed(1)} (${trainer.reviewCount})'
                                  : trainer.rating.toStringAsFixed(1),
                              isLight: isLight,
                            ),
                          if (trainer.locationLabel != null &&
                              trainer.locationLabel!.isNotEmpty)
                            _MetaChip(
                              icon: Icons.location_on_rounded,
                              label: trainer.locationLabel!,
                              isLight: isLight,
                            ),
                          _MetaChip(
                            icon: Icons.link_rounded,
                            label: 'Connected',
                            isLight: isLight,
                            accent: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'View Profile',
                    icon: Icons.person_outline_rounded,
                    filled: false,
                    enabled: true,
                    onTap: onViewProfile,
                    isLight: isLight,
                    textPrimary: textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Message',
                    icon: Icons.chat_bubble_outline_rounded,
                    filled: true,
                    enabled: !messagingChecked || messageEnabled,
                    onTap: onMessage,
                    isLight: isLight,
                    textPrimary: textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;

  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: DesignTokens.primaryGradient,
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLight;
  final bool accent;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isLight,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? DesignTokens.accentOrange
        : (isLight ? const Color(0xFF6B7280) : DesignTokens.darkTextSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? DesignTokens.accentOrange.withValues(alpha: 0.12)
            : (isLight
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;
  final bool isLight;
  final Color textPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onTap,
    required this.isLight,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? (enabled
            ? DesignTokens.accentOrange
            : DesignTokens.accentOrange.withValues(alpha: 0.35))
        : (isLight
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.06));
    final fg = filled
        ? Colors.white
        : textPrimary.withValues(alpha: enabled ? 1 : 0.45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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

class _EmptyState extends StatelessWidget {
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onFindTrainers;

  const _EmptyState({
    required this.textPrimary,
    required this.textSecondary,
    required this.onFindTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignTokens.accentOrange.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.sports_rounded,
                size: 34,
                color: DesignTokens.accentOrange,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No trainers connected yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Once a trainer accepts your request, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            PressableCard(
              onTap: onFindTrainers,
              borderRadius: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  gradient: DesignTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Find Trainers',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Couldn’t load trainers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  final bool isLight;

  const _SkeletonList({required this.isLight});

  @override
  Widget build(BuildContext context) {
    final base = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.06);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          height: 148,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }
}
