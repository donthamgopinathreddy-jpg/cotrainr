import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/referral_provider.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/profile/account_hub_widgets.dart';

class ReferFriendPage extends ConsumerStatefulWidget {
  const ReferFriendPage({super.key});

  @override
  ConsumerState<ReferFriendPage> createState() => _ReferFriendPageState();
}

class _ReferFriendPageState extends ConsumerState<ReferFriendPage> {
  static const _accent = AccountHubTheme.subscriptionAmber;

  void _copyText(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    showHubSnackBar(context, message);
  }

  Future<void> _shareReferral(String code, String link) async {
    HapticFeedback.mediumImpact();
    await Share.share(
      'Join me on Cotrainr! Use my referral code: $code\n\n$link',
      subject: 'Join Cotrainr with me!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = AccountHubTheme.pageBg(context);
    final codeAsync = ref.watch(referralCodeProvider);
    final referralsAsync = ref.watch(referralsCountProvider);
    final rewardsAsync = ref.watch(referralRewardsXpProvider);

    final code = codeAsync.valueOrNull ?? '';
    final totalReferrals = referralsAsync.valueOrNull ?? 0;
    final totalRewardsXp = rewardsAsync.valueOrNull ?? 0;
    final referralLink = code.isNotEmpty
        ? 'https://www.cotrainr.com/invite?code=$code'
        : 'https://www.cotrainr.com/invite';
    final isLoading =
        codeAsync.isLoading || referralsAsync.isLoading || rewardsAsync.isLoading;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Refer a Friend'),
      ),
      body: RefreshIndicator(
        color: DesignTokens.accentOrange,
        backgroundColor: DesignTokens.surfaceOf(context),
        onRefresh: () async {
          ref.invalidate(referralCodeProvider);
          ref.invalidate(referralsCountProvider);
          ref.invalidate(referralRewardsXpProvider);
          await Future.wait([
            ref.read(referralCodeProvider.future),
            ref.read(referralsCountProvider.future),
            ref.read(referralRewardsXpProvider.future),
          ]);
        },
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _HeroCard(isLight: isLight),
          const SizedBox(height: 12),
          HubSectionCard(
            animationDelayMs: 40,
            child: Row(
              children: [
                Expanded(
                  child: _ReferralStatTile(
                    label: 'Friends joined',
                    value: isLoading ? '—' : '$totalReferrals',
                    icon: Icons.people_outline_rounded,
                    isLight: isLight,
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
                  child: _ReferralStatTile(
                    label: 'XP earned',
                    value: isLoading ? '—' : '$totalRewardsXp',
                    icon: Icons.auto_awesome_outlined,
                    isLight: isLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HubSectionCard(
            title: 'Your invite',
            animationDelayMs: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Referral code',
                  style: AccountHubTheme.rowSubtitle(context),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: isLight ? 0.04 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isLoading ? '...' : (code.isEmpty ? '—' : code),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: AccountHubTheme.rowTitle(context).color,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        code.isEmpty ? null : () => _copyText(code, 'Referral code copied'),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy code'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Invite link',
                  style: AccountHubTheme.rowSubtitle(context),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: isLight ? 0.04 : 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          referralLink,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy link',
                        onPressed: () =>
                            _copyText(referralLink, 'Referral link copied'),
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: code.isEmpty
                        ? null
                        : () => _shareReferral(code, referralLink),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share invite'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HubSectionCard(
            title: 'How it works',
            animationDelayMs: 120,
            child: Column(
              children: const [
                _ReferralStep(
                  step: '1',
                  title: 'Share your invite',
                  description: 'Send your code or link to friends.',
                ),
                SizedBox(height: 12),
                _ReferralStep(
                  step: '2',
                  title: 'They sign up',
                  description: 'Your friend creates an account with your code.',
                ),
                SizedBox(height: 12),
                _ReferralStep(
                  step: '3',
                  title: 'You both earn XP',
                  description: 'Rewards unlock when they reach 500 XP.',
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

  const _HeroCard({required this.isLight});

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
            _ReferFriendPageState._accent,
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
                color: _ReferFriendPageState._accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.card_giftcard_outlined,
                color: _ReferFriendPageState._accent,
                size: 22,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Invite friends, earn rewards',
              style: AccountHubTheme.rowTitle(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Share Cotrainr with people you train with and collect XP when they get started.',
              style: AccountHubTheme.rowSubtitle(context).copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isLight;

  const _ReferralStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: _ReferFriendPageState._accent.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AccountHubTheme.rowTitle(context).copyWith(
              fontSize: 22,
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

class _ReferralStep extends StatelessWidget {
  final String step;
  final String title;
  final String description;

  const _ReferralStep({
    required this.step,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ReferFriendPageState._accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            step,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ReferFriendPageState._accent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AccountHubTheme.rowTitle(context)),
              const SizedBox(height: 3),
              Text(description, style: AccountHubTheme.rowSubtitle(context)),
            ],
          ),
        ),
      ],
    );
  }
}
