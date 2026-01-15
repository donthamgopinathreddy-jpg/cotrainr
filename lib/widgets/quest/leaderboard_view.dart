import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../pages/quest/quest_page.dart' show LeaderboardEntry;

class LeaderboardView extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String currentUserId;

  const LeaderboardView({
    super.key,
    required this.entries,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // Separate top 3 and rest
    final topThree = entries.where((e) => e.rank <= 3).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final rest = entries.where((e) => e.rank > 3).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final currentUser = entries.firstWhere(
      (e) => e.userId == currentUserId,
      orElse: () => entries.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top 3 Podium
        if (topThree.length >= 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd Place
                _PodiumCard(
                  entry: topThree[1],
                  rank: 2,
                  height: 120,
                ),
                const SizedBox(width: DesignTokens.spacing8),
                // 1st Place
                _PodiumCard(
                  entry: topThree[0],
                  rank: 1,
                  height: 140,
                ),
                const SizedBox(width: DesignTokens.spacing8),
                // 3rd Place
                _PodiumCard(
                  entry: topThree[2],
                  rank: 3,
                  height: 100,
                ),
              ],
            ),
          ),

        const SizedBox(height: DesignTokens.spacing24),

        // Current User Highlight
        if (currentUser.rank > 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
            child: Container(
              padding: const EdgeInsets.all(DesignTokens.spacing12),
              decoration: BoxDecoration(
                gradient: DesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: DesignTokens.cardShadowOf(context),
              ),
              child: _LeaderboardRow(
                entry: currentUser,
                isHighlighted: true,
              ),
            ),
          ),

        const SizedBox(height: DesignTokens.spacing16),

        // Rest of Leaderboard
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
          child: Column(
            children: rest.map((entry) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(
                  milliseconds: 200 + (rest.indexOf(entry) * 50),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.spacing12),
                  child: _LeaderboardRow(
                    entry: entry,
                    isHighlighted: false,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double height;

  const _PodiumCard({
    required this.entry,
    required this.rank,
    required this.height,
  });

  Color _getRankColor() {
    switch (rank) {
      case 1:
        return DesignTokens.accentAmber; // Gold
      case 2:
        return Colors.grey.shade400; // Silver
      case 3:
        return Colors.brown.shade400; // Bronze
      default:
        return DesignTokens.accentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(DesignTokens.spacing12),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceOf(context),
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: DesignTokens.cardShadowOf(context),
          border: Border.all(
            color: _getRankColor().withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rank Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getRankColor(),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: DesignTokens.fontSizeBodySmall,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing8),
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: DesignTokens.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: entry.avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                  : null,
            ),
            const SizedBox(height: DesignTokens.spacing8),
            // Username
            Text(
              entry.username,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeMeta,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Level
            Text(
              'Level ${entry.level}',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: DesignTokens.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isHighlighted;

  const _LeaderboardRow({
    required this.entry,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing12),
      decoration: BoxDecoration(
        color: isHighlighted ? null : DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: isHighlighted ? null : DesignTokens.cardShadowOf(context),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBody,
                fontWeight: FontWeight.w800,
                color: isHighlighted ? Colors.white : DesignTokens.textPrimaryOf(context),
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spacing12),
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: DesignTokens.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: entry.avatarUrl == null
                ? Icon(
                    Icons.person,
                    color: isHighlighted ? Colors.white : Colors.white,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: DesignTokens.spacing12),
          // Name & Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBodySmall,
                    fontWeight: FontWeight.w700,
                    color: isHighlighted ? Colors.white : DesignTokens.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Level ${entry.level}',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeCaption,
                    color: isHighlighted
                        ? Colors.white.withValues(alpha: 0.9)
                        : DesignTokens.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          // XP
          Text(
            '${entry.xp} XP',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeBodySmall,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? Colors.white : DesignTokens.accentOrange,
            ),
          ),
        ],
      ),
    );
  }
}

