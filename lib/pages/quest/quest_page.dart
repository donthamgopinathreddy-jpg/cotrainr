import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/page_transitions.dart';
import '../../providers/quest_provider.dart';

class QuestPage extends ConsumerStatefulWidget {
  const QuestPage({super.key});

  @override
  ConsumerState<QuestPage> createState() => _QuestPageState();
}

class _QuestPageState extends ConsumerState<QuestPage>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  late final PageController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late final List<_LevelInfo> _levels;

  final LinearGradient _primaryGradient = const LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFFFC300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _tabController = PageController(viewportFraction: 1.0);
    _levels = _buildLevels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  String _getLevelTitle(int level) {
    if (level < 5) return 'Foundation';
    if (level < 10) return 'Rising';
    if (level < 15) return 'Advanced';
    if (level < 20) return 'Elite';
    return 'Master';
  }

  void _openLevelsPage(int currentXP) {
    Navigator.of(context).push(
      PageTransitions.slideRoute(
        LevelsPage(
          currentXP: currentXP,
          levels: _levels,
        ),
        beginOffset: const Offset(0, 0.05),
      ),
    );
  }
  
  Future<void> _claimQuest(String questId) async {
    try {
      final repo = ref.read(questRepositoryProvider);
      final result = await repo.claimQuestRewards(questId);
      
      // Refresh quests and XP
      ref.invalidate(dailyQuestsProvider);
      ref.invalidate(weeklyQuestsProvider);
      ref.invalidate(userXPProvider);
      ref.invalidate(userLevelProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quest claimed! +${result['xp_awarded']} XP'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming quest: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Watch providers for real data
    final dailyQuestsAsync = ref.watch(dailyQuestsProvider);
    final weeklyQuestsAsync = ref.watch(weeklyQuestsProvider);
    final challengesAsync = ref.watch(activeChallengesProvider);
    final achievementsAsync = ref.watch(achievementsProvider);
    final leaderboardAsync = ref.watch(dailyLeaderboardProvider);
    final xpAsync = ref.watch(userXPProvider);
    final levelAsync = ref.watch(userLevelProvider);
    
    final currentXP = xpAsync.value ?? 0;
    final level = levelAsync.value ?? 1;
    final levelTitle = _getLevelTitle(level);
    
    // Convert to UI models
    final dailyItems = dailyQuestsAsync.value?.map((quest) => _QuestItem(
      title: quest.title,
      subtitle: quest.description,
      icon: quest.icon,
      progress: quest.maxProgress > 0 ? (quest.progress / quest.maxProgress).clamp(0.0, 1.0) : 0.0,
      rewardXP: quest.rewardXP,
      timeLeft: quest.timeLeft,
      canClaim: quest.canClaim,
      questId: quest.id,
    )).toList() ?? [];
    
    final weeklyItems = weeklyQuestsAsync.value?.map((quest) => _QuestItem(
      title: quest.title,
      subtitle: quest.description,
      icon: quest.icon,
      progress: quest.maxProgress > 0 ? (quest.progress / quest.maxProgress).clamp(0.0, 1.0) : 0.0,
      rewardXP: quest.rewardXP,
      timeLeft: quest.timeLeft,
      canClaim: quest.canClaim,
      questId: quest.id,
    )).toList() ?? [];
    
    final challengeItems = challengesAsync.value?.map((challenge) => _ChallengeItem(
      id: challenge.id,
      title: challenge.title,
      description: challenge.description,
      progress: challenge.maxProgress > 0 ? (challenge.progress / challenge.maxProgress).clamp(0.0, 1.0) : 0.0,
      participants: challenge.participants,
      timeLeft: challenge.timeLeft,
    )).toList() ?? [];
    
    final achievementItems = achievementsAsync.value?.map((achievement) => _AchievementItem(
      title: achievement.title,
      icon: achievement.icon,
      progress: achievement.progressRatio,
      unlocked: achievement.isUnlocked,
      tier: achievement.tier,
    )).toList() ?? [];
    
    final leaderboardItems = leaderboardAsync.value?.map((entry) => _LeaderboardItem(
      entry.username,
      entry.level,
      entry.points,
      entry.rank,
      avatarUrl: entry.avatarUrl,
    )).toList() ?? [];
    
    final isLoading = dailyQuestsAsync.isLoading || 
                     weeklyQuestsAsync.isLoading || 
                     challengesAsync.isLoading ||
                     achievementsAsync.isLoading ||
                     leaderboardAsync.isLoading;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _HeaderRow(
                onHelpTap: () => HapticFeedback.selectionClick(),
                currentXP: currentXP,
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _XpHero(
                currentXP: currentXP,
                level: level,
                title: levelTitle,
                currentLevelInfo: _levels[level.clamp(1, _levels.length) - 1],
                nextLevelInfo:
                    level < _levels.length ? _levels[level] : _levels.last,
                onTapRing: () => _openLevelsPage(currentXP),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _QuestTabs(
                selectedIndex: _tabIndex,
                onChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _tabIndex = index);
                  _tabController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ),
            Expanded(
              child: PageView(
                controller: _tabController,
                pageSnapping: true,
                onPageChanged: (index) {
                  setState(() => _tabIndex = index);
                },
                children: [
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _DailySection(
                          quests: dailyItems,
                          gradient: _primaryGradient,
                          onClaim: _claimQuest,
                        ),
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _WeeklySection(
                          quests: weeklyItems,
                          onClaim: _claimQuest,
                        ),
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _ChallengesSection(challenges: challengeItems),
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _AchievementsSection(items: achievementItems),
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _LeaderboardSection(entries: leaderboardItems),
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

class _HeaderRow extends StatelessWidget {
  final VoidCallback onHelpTap;
  final int currentXP;

  const _HeaderRow({required this.onHelpTap, required this.currentXP});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final questGradient = const LinearGradient(
      colors: [Color(0xFFFFD93D), Color(0xFFFF5A5A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Row(
      children: [
        ShaderMask(
          shaderCallback: (rect) => questGradient.createShader(rect),
          child: Icon(
            Icons.emoji_events_outlined,
            size: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        ShaderMask(
          shaderCallback: (rect) => questGradient.createShader(rect),
          child: Text(
            'QUESTS',
            style: GoogleFonts.montserrat(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onHelpTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.orange,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$currentXP XP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
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

class _XpHero extends StatelessWidget {
  final int currentXP;
  final int level;
  final String title;
  final _LevelInfo currentLevelInfo;
  final _LevelInfo nextLevelInfo;
  final VoidCallback onTapRing;

  const _XpHero({
    required this.currentXP,
    required this.level,
    required this.title,
    required this.currentLevelInfo,
    required this.nextLevelInfo,
    required this.onTapRing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nextXP = nextLevelInfo.xpRequired;
    final progress = currentXP / nextXP;
    return SizedBox(
      height: 140,
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapRing,
            child: _LevelBadge(
              level: level,
              title: title,
              color: currentLevelInfo.tierColor,
              symbol: currentLevelInfo.symbol,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: currentLevelInfo.tierColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentLevelInfo.tierColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Lv $level',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: currentLevelInfo.tierColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _XpBar(progress: progress),
                const SizedBox(height: 8),
                Text(
                  '$currentXP / $nextXP to unlock LV ${level + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.75),
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

class _QuestTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _QuestTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = [
      _TabData(
        icon: Icons.today_outlined,
        activeIcon: Icons.today,
        gradient: const LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFFC300)]),
      ),
      _TabData(
        icon: Icons.calendar_view_week_outlined,
        activeIcon: Icons.calendar_view_week,
        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
      ),
      _TabData(
        icon: Icons.people_outlined,
        activeIcon: Icons.people,
        gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE91E63)]),
      ),
      _TabData(
        icon: Icons.emoji_events_outlined,
        activeIcon: Icons.emoji_events,
        gradient: const LinearGradient(colors: [Color(0xFFFF4D6D), Color(0xFFFF8A00)]),
      ),
      _TabData(
        icon: Icons.leaderboard_outlined,
        activeIcon: Icons.leaderboard,
        gradient: const LinearGradient(colors: [Color(0xFF00C2A8), Color(0xFF19C37D)]),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabs.length;
        final pillWidth = tabWidth - 8;
        
        return SizedBox(
          height: 56,
          child: Stack(
            children: [
              // Sliding pill background
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: (selectedIndex * tabWidth) + 4,
                top: 4,
                bottom: 4,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: tabs[selectedIndex].gradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: tabs[selectedIndex].gradient.colors.first.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab icons
              Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = index == selectedIndex;
                  final tab = tabs[index];
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              isSelected ? tab.activeIcon : tab.icon,
                              key: ValueKey('${tab.icon}_$isSelected'),
                              size: 24,
                              color: isSelected
                                  ? Colors.white
                                  : colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabData {
  final IconData icon;
  final IconData activeIcon;
  final LinearGradient gradient;

  const _TabData({
    required this.icon,
    required this.activeIcon,
    required this.gradient,
  });
}

class _DailySection extends StatelessWidget {
  final List<_QuestItem> quests;
  final LinearGradient gradient;
  final Function(String) onClaim;

  const _DailySection({
    required this.quests,
    required this.gradient,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          ...quests
              .map(
                (quest) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _QuestCard(
                    quest: quest,
                    gradient: gradient,
                    onClaim: () => onClaim(quest.questId),
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

class _WeeklySection extends StatelessWidget {
  final List<_QuestItem> quests;
  final Function(String) onClaim;

  const _WeeklySection({
    required this.quests,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: quests.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, index) {
          return _WeeklyCard(
            quest: quests[index],
            onClaim: () => onClaim(quests[index].questId),
          );
        },
      ),
    );
  }
}

class _ChallengesSection extends StatelessWidget {
  final List<_ChallengeItem> challenges;

  const _ChallengesSection({required this.challenges});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Challenges',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          challenges.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outlined,
                        size: 48,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No active challenges',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join weekend challenges or create one with friends!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: challenges.map((challenge) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: AppColors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    challenge.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${challenge.participants}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.people,
                                  size: 16,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              challenge.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ProgressBar(
                              progress: challenge.progress,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                              ),
                            ),
                            if (challenge.timeLeft != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                challenge.timeLeft!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  final List<_LeaderboardItem> entries;

  const _LeaderboardSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => a.rank.compareTo(b.rank));
    final top3 = sorted.where((entry) => entry.rank <= 3).toList();
    final rest = sorted.where((entry) => entry.rank > 3).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          if (top3.isNotEmpty) _LeaderboardPodium(entries: top3),
          if (top3.isNotEmpty) const SizedBox(height: 16),
          ...rest.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LeaderboardCard(entry: entry),
              )),
        ],
      ),
    );
  }
}

class _LeaderboardPodium extends StatelessWidget {
  final List<_LeaderboardItem> entries;

  const _LeaderboardPodium({required this.entries});

  @override
  Widget build(BuildContext context) {
    final first = _findRank(entries, 1);
    final second = _findRank(entries, 2);
    final third = _findRank(entries, 3);
    return Row(
      children: [
        Expanded(
          child: _LeaderboardPodiumItem(
            entry: second,
            size: 72,
            rank: 2,
          ),
        ),
        Expanded(
          child: _LeaderboardPodiumItem(
            entry: first,
            size: 88,
            rank: 1,
          ),
        ),
        Expanded(
          child: _LeaderboardPodiumItem(
            entry: third,
            size: 72,
            rank: 3,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardPodiumItem extends StatelessWidget {
  final _LeaderboardItem? entry;
  final double size;
  final int rank;

  const _LeaderboardPodiumItem({
    required this.entry,
    required this.size,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (entry == null) {
      return const SizedBox.shrink();
    }
    final tierColor = _tierColorForLevel(entry!.level);
    return Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: SvgPicture.asset(
                _getBadgePathFromLevel(entry!.level),
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry!.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry!.xp} XP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  final List<_AchievementItem> items;

  const _AchievementsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          return _AchievementCard(item: items[index]);
        },
      ),
    );
  }
}

class LevelsPage extends StatefulWidget {
  final int currentXP;
  final List<_LevelInfo> levels;

  const LevelsPage({
    super.key,
    required this.currentXP,
    required this.levels,
  });

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final Map<int, bool> _expandedTiers = {0: true}; // Bronze expanded by default

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Group levels by tier (10 levels per tier)
    final tierGroups = <List<_LevelInfo>>[];
    for (var i = 0; i < widget.levels.length; i += 10) {
      final end = (i + 10).clamp(0, widget.levels.length);
      tierGroups.add(widget.levels.sublist(i, end));
    }

    // Find current tier and level
    int currentTierIndex = 0;
    int currentLevelIndex = 0;
    for (var i = 0; i < widget.levels.length; i++) {
      if (widget.currentXP >= widget.levels[i].xpRequired) {
        currentLevelIndex = i;
        currentTierIndex = (i / 10).floor();
      } else {
        break;
      }
    }
    final currentTier = tierGroups.isNotEmpty && currentTierIndex < tierGroups.length
        ? tierGroups[currentTierIndex]
        : tierGroups.isNotEmpty ? tierGroups[0] : <_LevelInfo>[];
    final currentLevel = currentLevelIndex < widget.levels.length
        ? widget.levels[currentLevelIndex]
        : null;
    final nextLevel = currentLevelIndex + 1 < widget.levels.length
        ? widget.levels[currentLevelIndex + 1]
        : null;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Levels',
          style: TextStyle(
            color: colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: widget.levels.isEmpty || tierGroups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: colorScheme.onBackground.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No levels available',
                    style: TextStyle(
                      color: colorScheme.onBackground,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                // Tier Header (Hero Section)
                if (currentTier.isNotEmpty && currentLevel != null)
                  _TierHeader(
                    tierLevels: currentTier,
                    currentLevel: currentLevel,
                    nextLevel: nextLevel,
                    currentXP: widget.currentXP,
                    pulseAnimation: _pulseController,
                  ),
                const SizedBox(height: 24),
                // Tier Sections (Collapsible)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: tierGroups.asMap().entries.map((entry) {
                      final tierIndex = entry.key;
                      final tierLevels = entry.value;
                      if (tierLevels.isEmpty) return const SizedBox.shrink();
                      
                      final isUnlocked = tierIndex <= currentTierIndex;
                      final isExpanded = _expandedTiers[tierIndex] ?? false;
                      
                      return _TierSectionCard(
                        tierIndex: tierIndex,
                        tierLevels: tierLevels,
                        currentXP: widget.currentXP,
                        isUnlocked: isUnlocked,
                        isExpanded: isExpanded,
                        onToggle: () {
                          setState(() {
                            _expandedTiers[tierIndex] = !isExpanded;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// Tier Header (Hero Section)
class _TierHeader extends StatelessWidget {
  final List<_LevelInfo> tierLevels;
  final _LevelInfo currentLevel;
  final _LevelInfo? nextLevel;
  final int currentXP;
  final Animation<double> pulseAnimation;

  const _TierHeader({
    required this.tierLevels,
    required this.currentLevel,
    required this.nextLevel,
    required this.currentXP,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tierName = currentLevel.tierName;
    final tierColor = currentLevel.tierColor;
    
    // Calculate progress to next level
    final nextXP = nextLevel?.xpRequired ?? currentLevel.xpRequired;
    final progress = nextXP > 0 ? ((currentXP - currentLevel.xpRequired) / 
        (nextXP - currentLevel.xpRequired)).clamp(0.0, 1.0) : 1.0;
    final neededXP = (nextXP - currentXP).clamp(0, nextXP);
    // neededXP is used in the progress display below
    
    // Get motivation copy
    final motivationCopy = _getMotivationCopy(tierName);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
      ),
      child: Column(
        children: [
          // Tier badge (no glow)
          SizedBox(
            width: 100,
            height: 100,
            child: SvgPicture.asset(
              _getBadgePathFromTierName(tierName),
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          // Tier name and range
          Text(
            tierName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Levels ${tierLevels.first.level} - ${tierLevels.last.level}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          // Motivation copy
          Text(
            motivationCopy,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tierColor.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          // Current level and progress
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getTierLightColor(tierName, context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Level ${currentLevel.level}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: tierColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· ${currentLevel.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  neededXP > 0
                      ? '$neededXP XP to next level'
                      : 'Max level in tier',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMotivationCopy(String tierName) {
    switch (tierName) {
      case 'Bronze':
        return 'Build the habit.';
      case 'Silver':
        return 'Consistency wins.';
      case 'Gold':
        return "You're outperforming most users.";
      case 'Platinum':
        return 'Elite discipline.';
      case 'Diamond':
        return 'Top 1% grinders.';
      default:
        return 'Keep pushing forward.';
    }
  }

  Color _getTierLightColor(String tierName, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isDark) {
      // Dark mode: use darker, muted versions
      switch (tierName) {
        case 'Bronze':
          return const Color(0xFF3D2A1A); // Dark orange-tinted
        case 'Silver':
          return const Color(0xFF1A2332); // Dark blue-tinted
        case 'Gold':
          return const Color(0xFF3D3519); // Dark yellow-tinted
        case 'Platinum':
          return const Color(0xFF1A2332); // Dark ice-blue-tinted
        case 'Diamond':
          return const Color(0xFF2A1F3D); // Dark purple-tinted
        default:
          return const Color(0xFF3D2A1A);
      }
    } else {
      // Light mode: use light pastel colors
      switch (tierName) {
        case 'Bronze':
          return const Color(0xFFFFF4E6); // Light orange
        case 'Silver':
          return const Color(0xFFF0F8FF); // Light blue
        case 'Gold':
          return const Color(0xFFFFFBE6); // Light yellow
        case 'Platinum':
          return const Color(0xFFF0F8FF); // Light ice-blue
        case 'Diamond':
          return const Color(0xFFF5F0FF); // Light purple
        default:
          return const Color(0xFFFFF4E6);
      }
    }
  }
}

// Tier Section Card (Collapsible)
class _TierSectionCard extends StatefulWidget {
  final int tierIndex;
  final List<_LevelInfo> tierLevels;
  final int currentXP;
  final bool isUnlocked;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _TierSectionCard({
    required this.tierIndex,
    required this.tierLevels,
    required this.currentXP,
    required this.isUnlocked,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_TierSectionCard> createState() => _TierSectionCardState();
}

class _TierSectionCardState extends State<_TierSectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    if (widget.isExpanded) {
      _expandController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_TierSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  Color _getTierLightColor(String tierName, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isDark) {
      // Dark mode: use darker, muted versions
      switch (tierName) {
        case 'Bronze':
          return const Color(0xFF3D2A1A); // Dark orange-tinted
        case 'Silver':
          return const Color(0xFF1A2332); // Dark blue-tinted
        case 'Gold':
          return const Color(0xFF3D3519); // Dark yellow-tinted
        case 'Platinum':
          return const Color(0xFF1A2332); // Dark ice-blue-tinted
        case 'Diamond':
          return const Color(0xFF2A1F3D); // Dark purple-tinted
        default:
          return const Color(0xFF3D2A1A);
      }
    } else {
      // Light mode: use light pastel colors
      switch (tierName) {
        case 'Bronze':
          return const Color(0xFFFFF4E6); // Light orange
        case 'Silver':
          return const Color(0xFFF0F8FF); // Light blue
        case 'Gold':
          return const Color(0xFFFFFBE6); // Light yellow
        case 'Platinum':
          return const Color(0xFFF0F8FF); // Light ice-blue
        case 'Diamond':
          return const Color(0xFFF5F0FF); // Light purple
        default:
          return const Color(0xFFFFF4E6);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstLevel = widget.tierLevels.first;
    final tierName = firstLevel.tierName;
    final tierColor = firstLevel.tierColor;
    
    // Find current level index in this tier
    int currentLevelIndex = -1;
    for (var i = 0; i < widget.tierLevels.length; i++) {
      if (widget.currentXP >= widget.tierLevels[i].xpRequired) {
        currentLevelIndex = i;
      } else {
        break;
      }
    }

    final tierLightColor = _getTierLightColor(tierName, context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isUnlocked
            ? tierLightColor
            : (Theme.of(context).brightness == Brightness.dark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Tier header (clickable)
          InkWell(
            onTap: widget.isUnlocked ? widget.onToggle : null,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: widget.isUnlocked
                        ? SvgPicture.asset(
                            _getBadgePathFromTierName(tierName),
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                          )
                        : ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 0.3, 0,
                            ]),
                            child: SvgPicture.asset(
                              _getBadgePathFromTierName(tierName),
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$tierName Tier',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: widget.isUnlocked
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          'Levels ${widget.tierLevels.first.level} - ${widget.tierLevels.last.level}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isUnlocked)
                    Icon(
                      Icons.lock_rounded,
                      color: colorScheme.onSurface.withOpacity(0.4),
                      size: 20,
                    )
                  else
                    AnimatedRotation(
                      turns: widget.isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expandable level list
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: widget.tierLevels.asMap().entries.map((entry) {
                final index = entry.key;
                final level = entry.value;
                final isCompleted = index < currentLevelIndex;
                final isCurrent = index == currentLevelIndex;
                
                return _LevelCard(
                  level: level,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isLocked: !isCompleted && !isCurrent,
                  currentXP: widget.currentXP,
                  nextLevel: index + 1 < widget.tierLevels.length
                      ? widget.tierLevels[index + 1]
                      : null,
                  tierColor: tierColor,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Level Card Widget
class _LevelCard extends StatelessWidget {
  final _LevelInfo level;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final int currentXP;
  final _LevelInfo? nextLevel;
  final Color tierColor;

  const _LevelCard({
    required this.level,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
    required this.currentXP,
    required this.nextLevel,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Calculate progress
    double progress = 0.0;
    int neededXP = 0;
    if (isCurrent && nextLevel != null) {
      progress = ((currentXP - level.xpRequired) / 
          (nextLevel!.xpRequired - level.xpRequired)).clamp(0.0, 1.0);
      neededXP = (nextLevel!.xpRequired - currentXP).clamp(0, nextLevel!.xpRequired);
    } else if (isCompleted) {
      progress = 1.0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getTierLightColor(_getTierNameFromLevel(level.level), context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Status icon - Badge SVG
          SizedBox(
            width: 40,
            height: 40,
            child: isLocked
                ? ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 0.3, 0,
                    ]),
                    child: SvgPicture.asset(
                      _getBadgePathFromLevel(level.level),
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  )
                : SvgPicture.asset(
                    _getBadgePathFromLevel(level.level),
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(width: 12),
          // Level info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      level.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isLocked
                            ? colorScheme.onSurface.withOpacity(0.4)
                            : (isCurrent ? tierColor : colorScheme.onSurface),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: _tierGradient(tierColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (isCurrent && nextLevel != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$neededXP XP to Level ${nextLevel!.level}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  )
                else if (isLocked)
                  Text(
                    'Unlocks at Level ${level.level}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 12,
                        color: tierColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${level.xpRequired} XP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTierNameFromLevel(int level) {
    final tierIndex = ((level - 1) / 10).floor();
    final tierNames = ['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond'];
    return tierIndex < tierNames.length ? tierNames[tierIndex] : 'Bronze';
  }

  Color _getTierLightColor(String tierName, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isDark) {
      // Dark mode: use darker, muted versions
      switch (tierName) {
        case 'Bronze':
          return const Color(0xFF3D2A1A); // Dark orange-tinted
        case 'Silver':
          return const Color(0xFF1A2332); // Dark blue-tinted
        case 'Gold':
          return const Color(0xFF3D3519); // Dark yellow-tinted
        case 'Platinum':
          return const Color(0xFF1A2332); // Dark ice-blue-tinted
        case 'Diamond':
          return const Color(0xFF2A1F3D); // Dark purple-tinted
        default:
          return const Color(0xFF3D2A1A);
      }
    } else {
      // Light mode: use light pastel colors
      switch (tierName) {
        case 'Bronze':
          return const Color(0xFFFFF4E6); // Light orange
        case 'Silver':
          return const Color(0xFFF0F8FF); // Light blue
        case 'Gold':
          return const Color(0xFFFFFBE6); // Light yellow
        case 'Platinum':
          return const Color(0xFFF0F8FF); // Light ice-blue
        case 'Diamond':
          return const Color(0xFFF5F0FF); // Light purple
        default:
          return const Color(0xFFFFF4E6);
      }
    }
  }
}

class _ContinuousLevelBar extends StatefulWidget {
  final List<_LevelInfo> tierLevels;
  final int currentXP;
  final Color tierColor;
  final LinearGradient tierGradient;

  const _ContinuousLevelBar({
    required this.tierLevels,
    required this.currentXP,
    required this.tierColor,
    required this.tierGradient,
  });

  @override
  State<_ContinuousLevelBar> createState() => _ContinuousLevelBarState();
}

class _ContinuousLevelBarState extends State<_ContinuousLevelBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fillAnimation;
  int _previousLevelIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fillAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _previousLevelIndex = _getCurrentLevelIndex();
    _animationController.forward();
  }

  @override
  void didUpdateWidget(_ContinuousLevelBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLevelIndex = _getCurrentLevelIndex();
    if (newLevelIndex > _previousLevelIndex) {
      // Level up! Trigger animation
      _previousLevelIndex = newLevelIndex;
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int _getCurrentLevelIndex() {
    int currentLevelIndex = -1;
    for (var i = 0; i < widget.tierLevels.length; i++) {
      if (widget.currentXP >= widget.tierLevels[i].xpRequired) {
        currentLevelIndex = i;
      } else {
        break;
      }
    }
    return currentLevelIndex;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Find current level index
    final currentLevelIndex = _getCurrentLevelIndex();
    
    // Calculate total progress through the tier
    final lastLevelXP = widget.tierLevels.last.xpRequired;
    final nextTierFirstXP = (lastLevelXP * 1.12).round(); // Estimate
    
    // Calculate how many complete levels + progress to next
    double totalProgress = 0.0;
    if (currentLevelIndex == widget.tierLevels.length - 1) {
      // All levels in tier unlocked, calculate progress to next tier
      final progressToNext = ((widget.currentXP - lastLevelXP) / (nextTierFirstXP - lastLevelXP)).clamp(0.0, 1.0);
      totalProgress = 1.0 + (progressToNext * 0.1); // Slight overflow to show progress
    } else if (currentLevelIndex >= 0) {
      // Partially through tier
      final completedLevels = currentLevelIndex + 1;
      final currentLevel = widget.tierLevels[currentLevelIndex];
      final nextLevel = widget.tierLevels[currentLevelIndex + 1];
      final progressInCurrentLevel = ((widget.currentXP - currentLevel.xpRequired) / 
          (nextLevel.xpRequired - currentLevel.xpRequired)).clamp(0.0, 1.0);
      totalProgress = (completedLevels + progressInCurrentLevel) / widget.tierLevels.length;
    }
    
    // Bar height: each level gets equal space
    final barHeight = widget.tierLevels.length * 72.0; // 72px per level
    final filledHeight = barHeight * totalProgress.clamp(0.0, 1.0);
    final levelSpacing = 72.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thin vertical bar with level indicators
        SizedBox(
          width: 60,
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Thin background line
              Positioned(
                left: 29,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Thin filled line (fills downward with animation)
              AnimatedBuilder(
                animation: _fillAnimation,
                builder: (context, child) {
                  return Positioned(
                    left: 29,
                    top: 0,
                    width: 2,
                    height: filledHeight * _fillAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.tierGradient.colors.first,
                            widget.tierGradient.colors.last,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  );
                },
              ),
              // Level indicators (dots/badges) on the thin line
              ...widget.tierLevels.asMap().entries.map((entry) {
                final index = entry.key;
                final level = entry.value;
                final isUnlocked = index <= currentLevelIndex;
                final isCurrentLevel = index == currentLevelIndex;
                final position = index * levelSpacing + 36.0; // Center of each level section
                
                return Positioned(
                  top: position - 16,
                  left: 0,
                  child: AnimatedScale(
                    scale: isCurrentLevel ? 1.3 : (isUnlocked ? 1.0 : 0.8),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: isUnlocked ? widget.tierGradient : null,
                        color: isUnlocked ? null : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${level.level}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isUnlocked
                                ? Colors.white
                                : colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Level names and details on the right side
        Expanded(
          child: SizedBox(
            height: barHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.tierLevels.asMap().entries.map((entry) {
              final index = entry.key;
              final level = entry.value;
              final isUnlocked = index <= currentLevelIndex;
              final isCurrentLevel = index == currentLevelIndex;
              
              return Container(
                height: 72,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Level info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isCurrentLevel ? FontWeight.w900 : FontWeight.w700,
                                  color: isUnlocked
                                      ? (isCurrentLevel ? widget.tierColor : colorScheme.onSurface)
                                      : colorScheme.onSurface.withOpacity(0.4),
                                  letterSpacing: -0.3,
                                ),
                                child: Text(level.name),
                              ),
                              if (isCurrentLevel) ...[
                                const SizedBox(width: 8),
                                AnimatedBuilder(
                                  animation: _fillAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 0.8 + (_fillAnimation.value * 0.2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: widget.tierGradient,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'CURRENT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                size: 12,
                                color: isUnlocked
                                    ? widget.tierColor.withOpacity(0.8)
                                    : colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${level.xpRequired} XP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isUnlocked
                                      ? colorScheme.onSurface.withOpacity(0.7)
                                      : colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}


class _QuestCard extends StatelessWidget {
  final _QuestItem quest;
  final LinearGradient gradient;
  final VoidCallback? onClaim;

  const _QuestCard({
    required this.quest,
    required this.gradient,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: quest.icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Chip(text: '${quest.rewardXP} XP'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quest.subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          _ProgressBar(progress: quest.progress, gradient: gradient),
          const SizedBox(height: 8),
          Row(
            children: [
              if (quest.timeLeft != null) _Chip(text: quest.timeLeft!),
              const Spacer(),
              _PrimaryButton(
                label: quest.canClaim ? 'Claim' : (quest.progress >= 1.0 ? 'Claim' : 'In Progress'),
                gradient: gradient,
                enabled: quest.canClaim || quest.progress >= 1.0,
                onTap: (quest.canClaim || quest.progress >= 1.0) && onClaim != null ? onClaim! : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final _QuestItem quest;
  final VoidCallback? onClaim;

  const _WeeklyCard({
    required this.quest,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: quest.icon, size: 32, iconSize: 18),
          const SizedBox(height: 8),
          Text(
            quest.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              _MiniRing(progress: quest.progress),
              const Spacer(),
              Text(
                '${quest.rewardXP} XP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final _LeaderboardItem entry;

  const _LeaderboardCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Text(
            '#${entry.rank}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(radius: 18, backgroundColor: Colors.white24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${entry.xp} XP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final _AchievementItem item;

  const _AchievementCard({required this.item});

  String _getBadgePath(int tier) {
    switch (tier) {
      case 1:
        return 'assets/badges/badge_bronze.svg';
      case 2:
        return 'assets/badges/badge_silver.svg';
      case 3:
        return 'assets/badges/badge_gold.svg';
      case 4:
        return 'assets/badges/badge_platinum.svg';
      case 5:
        return 'assets/badges/badge_diamond.svg';
      default:
        return 'assets/badges/badge_bronze.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge SVG
        SizedBox(
          width: 32,
          height: 32,
          child: item.unlocked
              ? SvgPicture.asset(
                  _getBadgePath(item.tier),
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                )
              : ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.2126, 0.7152, 0.0722, 0, 0, // Red channel
                    0.2126, 0.7152, 0.0722, 0, 0, // Green channel
                    0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
                    0, 0, 0, 0.3, 0, // Alpha channel (30% opacity)
                  ]),
                  child: SvgPicture.asset(
                    _getBadgePath(item.tier),
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        _ProgressBar(
          progress: item.progress,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A00), Color(0xFFFFC300)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
    );
  }
}

// Helper function to get badge path from level
String _getBadgePathFromLevel(int level) {
  final tierIndex = ((level - 1) / 10).floor();
  final badgeTier = tierIndex + 1; // Convert 0-based to 1-based
  switch (badgeTier) {
    case 1:
      return 'assets/badges/badge_bronze.svg';
    case 2:
      return 'assets/badges/badge_silver.svg';
    case 3:
      return 'assets/badges/badge_gold.svg';
    case 4:
      return 'assets/badges/badge_platinum.svg';
    case 5:
      return 'assets/badges/badge_diamond.svg';
    default:
      return 'assets/badges/badge_bronze.svg';
  }
}

// Helper function to get badge path from tier name
String _getBadgePathFromTierName(String tierName) {
  switch (tierName) {
    case 'Bronze':
      return 'assets/badges/badge_bronze.svg';
    case 'Silver':
      return 'assets/badges/badge_silver.svg';
    case 'Gold':
      return 'assets/badges/badge_gold.svg';
    case 'Platinum':
      return 'assets/badges/badge_platinum.svg';
    case 'Diamond':
      return 'assets/badges/badge_diamond.svg';
    default:
      return 'assets/badges/badge_bronze.svg';
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;
  final String title;
  final Color color;
  final _SymbolType symbol;

  const _LevelBadge({
    required this.level,
    required this.title,
    required this.color,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: _tierGradient(color),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: SvgPicture.asset(
            _getBadgePathFromLevel(level),
            width: 42,
            height: 42,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final double progress;

  const _XpBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(color: colorScheme.surfaceVariant.withOpacity(0.5)),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A00), Color(0xFFFFC300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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

class _ProgressBar extends StatelessWidget {
  final double progress;
  final LinearGradient gradient;

  const _ProgressBar({required this.progress, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(color: colorScheme.outline.withOpacity(0.2)),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(gradient: gradient)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniRing extends StatelessWidget {
  final double progress;

  const _MiniRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 4,
        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        backgroundColor: colorScheme.outline.withOpacity(0.2),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const _IconBadge({
    required this.icon,
    this.size = 36,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colorScheme.onSurface, size: iconSize),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final bool enabled;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.gradient,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: enabled && onTap != null ? onTap : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled ? Colors.white : colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final double progress;
  final int rewardXP;
  final String? timeLeft;
  final bool canClaim;
  final String questId;

  _QuestItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.progress,
    required this.rewardXP,
    this.timeLeft,
    this.canClaim = false,
    required this.questId,
  });
}

class _LeaderboardItem {
  final String name;
  final int level;
  final int xp;
  final int rank;
  final String? avatarUrl;

  _LeaderboardItem(this.name, this.level, this.xp, this.rank, {this.avatarUrl});
}

class _ChallengeItem {
  final String id;
  final String title;
  final String description;
  final double progress;
  final int participants;
  final String? timeLeft;

  _ChallengeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.participants,
    this.timeLeft,
  });
}

class _AchievementItem {
  final String title;
  final IconData icon;
  final double progress;
  final bool unlocked;
  final int tier;

  _AchievementItem({
    required this.title,
    required this.icon,
    required this.progress,
    required this.unlocked,
    required this.tier,
  });
}

class _LevelInfo {
  final int level;
  final String name;
  final int xpRequired;
  final String tierName;
  final Color tierColor;
  final _SymbolType symbol;

  const _LevelInfo(
    this.level,
    this.name,
    this.xpRequired,
    this.tierName,
    this.tierColor,
    this.symbol,
  );
}

List<_LevelInfo> _buildLevels() {
  const tier1 = Color(0xFFCD7F32); // Bronze
  const tier2 = Color(0xFFC0C0C0); // Silver
  const tier3 = Color(0xFFFFD700); // Gold
  const tier4 = Color(0xFFE5E4E2); // Platinum
  const tier5 = Color(0xFF4FC3F7); // Diamond

  final names = [
    'Rookie',
    'Starter',
    'Mover',
    'Walker',
    'Tracker',
    'Habit Builder',
    'Consistent',
    'Focused',
    'Committed',
    'Foundation Complete',
    'Strider',
    'Energized',
    'Stepper',
    'Balancer',
    'Performer',
    'Driven',
    'Builder',
    'Progressor',
    'Momentum',
    'Momentum Master',
    'Athlete',
    'Fuelled',
    'Conditioned',
    'Resilient',
    'Stronger',
    'Grinder',
    'Endurance',
    'Peak Ready',
    'Relentless',
    'Performance Elite',
    'Veteran',
    'Pro',
    'Expert',
    'Champion',
    'Dominator',
    'Prime',
    'Unstoppable',
    'Elite Force',
    'Supreme',
    'Elite Legend',
    'Mythic',
    'Overdrive',
    'Ascended',
    'Immortal',
    'Titan',
    'Godmode',
    'Apex',
    'Infinity',
    'Icon',
    'Cotrainr Elite',
  ];

  final tierSymbols = [
    [
      _SymbolType.flame,
      _SymbolType.footstep,
      _SymbolType.arrow,
      _SymbolType.footprints,
      _SymbolType.check,
      _SymbolType.calendar,
      _SymbolType.bars,
      _SymbolType.target,
      _SymbolType.chain,
      _SymbolType.star,
    ],
    [
      _SymbolType.runner,
      _SymbolType.lightning,
      _SymbolType.stairs,
      _SymbolType.balance,
      _SymbolType.star,
      _SymbolType.arrowUp,
      _SymbolType.blocks,
      _SymbolType.graph,
      _SymbolType.spin,
      _SymbolType.doubleStar,
    ],
    [
      _SymbolType.runner,
      _SymbolType.flame,
      _SymbolType.heartbeat,
      _SymbolType.shield,
      _SymbolType.muscle,
      _SymbolType.gear,
      _SymbolType.infinity,
      _SymbolType.mountain,
      _SymbolType.hammer,
      _SymbolType.crown,
    ],
    [
      _SymbolType.medalStar,
      _SymbolType.checkSeal,
      _SymbolType.brain,
      _SymbolType.laurel,
      _SymbolType.claw,
      _SymbolType.diamond,
      _SymbolType.breakline,
      _SymbolType.energy,
      _SymbolType.sunburst,
      _SymbolType.crown,
    ],
    [
      _SymbolType.rune,
      _SymbolType.motion,
      _SymbolType.wings,
      _SymbolType.infinity,
      _SymbolType.helmet,
      _SymbolType.eye,
      _SymbolType.triplePeak,
      _SymbolType.mobius,
      _SymbolType.radiantStar,
      _SymbolType.mythicCrest,
    ],
  ];

  final levels = <_LevelInfo>[];
  var xp = 0.0;
  var step = 100.0;
  for (var i = 0; i < 50; i++) {
    if (i > 0) {
      xp += step;
      step = (step * 1.12).clamp(100, 1200);
    }
    final level = i + 1;
    final tierIndex = (i / 10).floor();
    final tierName = [
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
    ][tierIndex];
    final tierColor = [
      tier1,
      tier2,
      tier3,
      tier4,
      tier5,
    ][tierIndex];
    levels.add(
      _LevelInfo(
        level,
        names[i],
        xp.round(),
        tierName,
        tierColor,
        tierSymbols[tierIndex][i % 10],
      ),
    );
  }
  return levels;
}

LinearGradient _tierGradient(Color base) {
  return LinearGradient(
    colors: [
      base.withOpacity(0.95),
      Color.lerp(base, Colors.black, 0.25) ?? base,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Infinity Badge Widget (replaces MedalBadge)
class _InfinityBadge extends StatelessWidget {
  final String tierName;
  final double size;
  final bool isLocked;
  final bool isCompleted;
  final int? levelNumber;

  const _InfinityBadge({
    required this.tierName,
    required this.size,
    this.isLocked = false,
    this.isCompleted = false,
    this.levelNumber,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = _getTierGradient(tierName);
    
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _InfinityBadgePainter(
          tierName: tierName,
          gradient: gradient,
          isLocked: isLocked,
          isCompleted: isCompleted,
          levelNumber: levelNumber,
        ),
      ),
    );
  }

  LinearGradient _getTierGradient(String tierName) {
    switch (tierName) {
      case 'Bronze':
        return const LinearGradient(
          colors: [Color(0xFFFF7A00), Color(0xFFFFC300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Silver':
        return const LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFFE8E8E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Gold':
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFF44F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Platinum':
        return const LinearGradient(
          colors: [Color(0xFFE5E4E2), Color(0xFFFFF8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Diamond':
        return const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF9B7FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFFF7A00), Color(0xFFFFC300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

// Infinity Badge Painter
class _InfinityBadgePainter extends CustomPainter {
  final String tierName;
  final LinearGradient gradient;
  final bool isLocked;
  final bool isCompleted;
  final int? levelNumber;

  _InfinityBadgePainter({
    required this.tierName,
    required this.gradient,
    required this.isLocked,
    required this.isCompleted,
    this.levelNumber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 100.0;
    final loopRadius = 18 * scale;
    final spacing = 14 * scale;
    
    // Create premium 3D infinity symbol
    final leftCenter = Offset(center.dx - spacing, center.dy);
    final rightCenter = Offset(center.dx + spacing, center.dy);
    
    // Create smooth infinity path with rounded hexagonal loops
    final path = Path();
    
    // Left loop - rounded hexagon
    final leftTop = Offset(leftCenter.dx, leftCenter.dy - loopRadius);
    final leftRight = Offset(leftCenter.dx + loopRadius * 0.85, leftCenter.dy);
    
    // Right loop - rounded hexagon
    final rightTop = Offset(rightCenter.dx, rightCenter.dy - loopRadius);
    final rightLeft = Offset(rightCenter.dx - loopRadius * 0.85, rightCenter.dy);
    
    // Start from top of left loop
    path.moveTo(leftTop.dx, leftTop.dy);
    
    // Left loop - top right curve
    path.cubicTo(
      leftCenter.dx + loopRadius * 0.4,
      leftCenter.dy - loopRadius * 0.6,
      leftCenter.dx + loopRadius * 0.7,
      leftCenter.dy - loopRadius * 0.2,
      leftRight.dx,
      leftRight.dy - loopRadius * 0.3,
    );
    
    // Left loop - right side
    path.cubicTo(
      leftRight.dx + loopRadius * 0.1,
      leftRight.dy,
      leftRight.dx + loopRadius * 0.1,
      leftRight.dy,
      leftRight.dx,
      leftRight.dy + loopRadius * 0.3,
    );
    
    // Connect to right loop (bottom curve) - smooth transition
    path.cubicTo(
      center.dx - spacing * 0.3,
      center.dy + loopRadius * 0.4,
      center.dx + spacing * 0.3,
      center.dy + loopRadius * 0.4,
      rightLeft.dx,
      rightLeft.dy + loopRadius * 0.3,
    );
    
    // Right loop - left side
    path.cubicTo(
      rightLeft.dx - loopRadius * 0.1,
      rightLeft.dy,
      rightLeft.dx - loopRadius * 0.1,
      rightLeft.dy,
      rightLeft.dx,
      rightLeft.dy - loopRadius * 0.3,
    );
    
    // Right loop - top left curve
    path.cubicTo(
      rightCenter.dx - loopRadius * 0.7,
      rightCenter.dy - loopRadius * 0.2,
      rightCenter.dx - loopRadius * 0.4,
      rightCenter.dy - loopRadius * 0.6,
      rightTop.dx,
      rightTop.dy,
    );
    
    // Right loop - top
    path.cubicTo(
      rightCenter.dx + loopRadius * 0.4,
      rightCenter.dy - loopRadius * 0.6,
      rightCenter.dx + loopRadius * 0.7,
      rightCenter.dy - loopRadius * 0.2,
      rightLeft.dx,
      rightLeft.dy - loopRadius * 0.3,
    );
    
    // Connect back to left loop (top curve) - smooth transition
    path.cubicTo(
      center.dx + spacing * 0.3,
      center.dy - loopRadius * 0.4,
      center.dx - spacing * 0.3,
      center.dy - loopRadius * 0.4,
      leftRight.dx,
      leftRight.dy - loopRadius * 0.3,
    );
    
    // Left loop - left side
    path.cubicTo(
      leftCenter.dx - loopRadius * 0.7,
      leftCenter.dy - loopRadius * 0.2,
      leftCenter.dx - loopRadius * 0.4,
      leftCenter.dy - loopRadius * 0.6,
      leftTop.dx,
      leftTop.dy,
    );
    
    path.close();
    
    // Draw with gradient fill
    final fillPaint = Paint()
      ..shader = isLocked
          ? null
          : gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..color = isLocked ? const Color(0xFF555555) : Colors.transparent
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);
    
    // Add inner highlight for 3D effect
    if (!isLocked) {
      final highlightPath = Path();
      highlightPath.addOval(Rect.fromCircle(
        center: Offset(center.dx - spacing * 0.5, center.dy - loopRadius * 0.3),
        radius: loopRadius * 0.3,
      ));
      
      final highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(highlightPath, highlightPaint);
    }
    
    // Add stroke for definition
    final strokePaint = Paint()
      ..color = isLocked
          ? const Color(0xFF888888)
          : Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(path, strokePaint);
    
    // Draw level number or checkmark
    if (isCompleted) {
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round;
      
      final checkPath = Path();
      checkPath.moveTo(center.dx - 8 * scale, center.dy);
      checkPath.lineTo(center.dx - 2 * scale, center.dy + 6 * scale);
      checkPath.lineTo(center.dx + 8 * scale, center.dy - 6 * scale);
      canvas.drawPath(checkPath, checkPaint);
    } else if (levelNumber != null && !isLocked) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$levelNumber',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w900,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    } else if (isLocked) {
      // Draw lock icon
      final lockPaint = Paint()
        ..color = const Color(0xFF999999)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale;
      
      // Simple lock shape
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 2 * scale),
          width: 8 * scale,
          height: 8 * scale,
        ),
        lockPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - 2 * scale),
          width: 8 * scale,
          height: 8 * scale,
        ),
        math.pi,
        math.pi,
        false,
        lockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InfinityBadgePainter oldDelegate) {
    return oldDelegate.tierName != tierName ||
        oldDelegate.isLocked != isLocked ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.levelNumber != levelNumber;
  }
}

class _MedalBadge extends StatelessWidget {
  final int level;
  final Color color;
  final _SymbolType symbol;
  final double size;

  const _MedalBadge({
    super.key,
    required this.level,
    required this.color,
    required this.symbol,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedalBadgePainter(
          level: level,
          color: color,
          symbol: symbol,
        ),
      ),
    );
  }
}

class _MedalBadgePainter extends CustomPainter {
  final int level;
  final Color color;
  final _SymbolType symbol;

  _MedalBadgePainter({
    required this.level,
    required this.color,
    required this.symbol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final tier = ((level - 1) / 10).floor();
    _paintOuterHex(canvas, size, center, radius, tier);
    _paintInnerPlate(canvas, size, center, radius, tier);
    _paintLaurelWings(canvas, size, center, radius, tier);
    _paintRibbon(canvas, size, center, radius, tier);
    _paintChevrons(canvas, size, center, radius, tier, level);
    _paintTopStars(canvas, size, center, radius, tier, level);
  }

  void _paintOuterHex(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int tier,
  ) {
    final glow = tier >= 2 ? 0.22 : 0.08;
    final glowPaint = Paint()
      ..color = color.withOpacity(glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, size.width * 0.2);
    final outerPath = _hexPath(center, radius * 0.9);
    canvas.drawPath(outerPath, glowPaint);

    final fillPaint = Paint()
      ..shader = _tierFillShader(
        Rect.fromCircle(center: center, radius: radius),
        tier,
      )
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1;
    final ringPath = _hexPath(center, radius * 0.8);
    canvas.drawPath(ringPath, fillPaint);
    canvas.drawPath(ringPath, strokePaint);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.12);
    canvas.drawPath(
      _hexPath(center.translate(0, radius * 0.06), radius * 0.8),
      shadowPaint,
    );

    final bevelLight = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03;
    final topEdge = _hexPoints(center, radius * 0.82);
    canvas.drawLine(topEdge[4], topEdge[0], bevelLight);
    canvas.drawLine(topEdge[0], topEdge[1], bevelLight);

    final specularPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    final specPoints = _hexPoints(center, radius * 0.88);
    canvas.drawLine(specPoints[4], specPoints[0], specularPaint);

    final groovePaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    canvas.drawPath(_hexPath(center, radius * 0.74), groovePaint);

    final innerShadow = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    final shadowPoints = _hexPoints(center, radius * 0.76);
    canvas.drawLine(shadowPoints[1], shadowPoints[2], innerShadow);
    canvas.drawLine(shadowPoints[2], shadowPoints[3], innerShadow);
  }

  void _paintInnerPlate(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int tier,
  ) {
    final platePaint = Paint()
      ..color = Colors.white.withOpacity(tier >= 2 ? 0.26 : 0.18)
      ..style = PaintingStyle.fill;
    final plateStroke = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04;
    final platePath = _hexPath(center, radius * 0.55);
    canvas.drawPath(platePath, platePaint);
    canvas.drawPath(platePath, plateStroke);

    final plateInnerGlow = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    canvas.drawPath(_hexPath(center, radius * 0.5), plateInnerGlow);

    final plateShadow = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    final plateShadowPoints = _hexPoints(center, radius * 0.55);
    canvas.drawLine(plateShadowPoints[2], plateShadowPoints[3], plateShadow);

    final plateHighlight = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    final plateHighlightPoints = _hexPoints(center, radius * 0.56);
    canvas.drawLine(plateHighlightPoints[4], plateHighlightPoints[0], plateHighlight);
  }

  void _paintLaurelWings(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int tier,
  ) {
    final leafPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    final leafCount = 6 + tier;
    for (var i = 0; i < leafCount; i++) {
      final t = i / (leafCount - 1);
      final angleLeft = math.pi * (0.65 + t * 0.5);
      final angleRight = math.pi * (0.35 - t * 0.5);
      final left = Offset(
        center.dx + math.cos(angleLeft) * radius * 0.85,
        center.dy + math.sin(angleLeft) * radius * 0.85,
      );
      final right = Offset(
        center.dx + math.cos(angleRight) * radius * 0.85,
        center.dy + math.sin(angleRight) * radius * 0.85,
      );
      _drawLeaf(canvas, left, radius * 0.12, angleLeft - math.pi / 2, leafPaint);
      _drawLeaf(canvas, right, radius * 0.12, angleRight + math.pi / 2, leafPaint);
    }
  }

  void _drawLeaf(
    Canvas canvas,
    Offset center,
    double size,
    double rotation,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(
        center.dx + size * 0.8,
        center.dy,
        center.dx,
        center.dy + size,
      )
      ..quadraticBezierTo(
        center.dx - size * 0.8,
        center.dy,
        center.dx,
        center.dy - size,
      );
    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..rotateZ(rotation)
      ..translate(-center.dx, -center.dy);
    canvas.drawPath(path.transform(matrix.storage), paint);
  }

  void _paintRibbon(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int tier,
  ) {
    final ribbonPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    final left = Path()
      ..moveTo(center.dx - radius * 0.35, center.dy + radius * 0.8)
      ..lineTo(center.dx - radius * 0.65, center.dy + radius * 1.15)
      ..lineTo(center.dx - radius * 0.2, center.dy + radius * 1.05)
      ..close();
    final right = Path()
      ..moveTo(center.dx + radius * 0.35, center.dy + radius * 0.8)
      ..lineTo(center.dx + radius * 0.65, center.dy + radius * 1.15)
      ..lineTo(center.dx + radius * 0.2, center.dy + radius * 1.05)
      ..close();
    canvas.drawPath(left, ribbonPaint);
    canvas.drawPath(right, ribbonPaint);
  }

  void _paintChevrons(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int tier,
    int level,
  ) {
    final tierIndex = (level - 1) % 10;
    final chevrons = tierIndex <= 4 ? tierIndex + 1 : 5;
    final chevronPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bevelPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < chevrons; i++) {
      final y = center.dy - radius * 0.26 + i * radius * 0.12;
      canvas.drawLine(
        Offset(center.dx - radius * 0.24, y),
        Offset(center.dx, y + radius * 0.14),
        chevronPaint,
      );
      canvas.drawLine(
        Offset(center.dx, y + radius * 0.14),
        Offset(center.dx + radius * 0.24, y),
        chevronPaint,
      );
      canvas.drawLine(
        Offset(center.dx - radius * 0.22, y + radius * 0.01),
        Offset(center.dx, y + radius * 0.12),
        bevelPaint,
      );
      canvas.drawLine(
        Offset(center.dx, y + radius * 0.12),
        Offset(center.dx + radius * 0.22, y + radius * 0.01),
        bevelPaint,
      );
    }
  }

  void _paintTopStars(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int tier,
    int level,
  ) {
    final tierIndex = (level - 1) % 10;
    final filled = tierIndex <= 4 ? 0 : (tierIndex - 4).clamp(0, 5);
    for (var i = 0; i < 5; i++) {
      final offsetX = (i - 2) * radius * 0.22;
      final starCenter = Offset(center.dx + offsetX, center.dy - radius * 1.05);
      final isActive = i < filled;
      if (isActive) {
        final starGlow = Paint()
          ..color = color.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.04
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, size.width * 0.12);
        _drawStar(canvas, starCenter, radius * 0.15, starGlow);
      }
      final baseShadow = Paint()
        ..color = Colors.black.withOpacity(isActive ? 0.25 : 0.1)
        ..style = PaintingStyle.fill;
      _drawStar(
        canvas,
        starCenter.translate(0, radius * 0.03),
        radius * 0.12,
        baseShadow,
      );
      final starFill = Paint()
        ..color = (isActive
            ? color.withOpacity(0.98)
            : Colors.white.withOpacity(0.24))
        ..style = PaintingStyle.fill;
      final starStroke = Paint()
        ..color = Colors.white.withOpacity(isActive ? 0.5 : 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02;
      _drawStar(canvas, starCenter, radius * 0.13, starFill);
      _drawStar(canvas, starCenter, radius * 0.13, starStroke);
      if (isActive) {
        final highlight = Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.012;
        _drawStar(canvas, starCenter, radius * 0.09, highlight);
      }
    }
  }

  Shader _tierFillShader(Rect bounds, int tier) {
    if (tier == 2) {
      return const LinearGradient(
        colors: [
          Color(0xFFFFF2A6),
          Color(0xFFFFD24D),
          Color(0xFFFFE48A),
          Color(0xFFCFA51E),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds);
    }
    if (tier == 3) {
      return const LinearGradient(
        colors: [
          Color(0xFFE9F7FF),
          Color(0xFFA4D8FF),
          Color(0xFFE5F2FF),
          Color(0xFF7EB6FF),
        ],
        stops: [0.0, 0.4, 0.7, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds);
    }
    if (tier == 4) {
      return const LinearGradient(
        colors: [
          Color(0xFF7EF9FF),
          Color(0xFFB388FF),
          Color(0xFFE3C9FF),
          Color(0xFF6BE0FF),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds);
    }
    return LinearGradient(
      colors: [
        color.withOpacity(0.28),
        Color.lerp(color, Colors.black, 0.18) ?? color,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bounds);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (math.pi * 2 / 5) * i - math.pi / 2;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      final innerAngle = angle + math.pi / 5;
      final innerPoint = Offset(
        center.dx + math.cos(innerAngle) * radius * 0.5,
        center.dy + math.sin(innerAngle) * radius * 0.5,
      );
      path.lineTo(innerPoint.dx, innerPoint.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MedalBadgePainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.color != color ||
        oldDelegate.symbol != symbol;
  }

  List<Offset> _hexPoints(Offset center, double radius) {
    final points = <Offset>[];
    for (var i = 0; i < 6; i++) {
      final angle = (-math.pi / 2) + (2 * math.pi / 6) * i;
      points.add(
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
      );
    }
    return points;
  }

  Path _hexPath(Offset center, double radius) {
    final points = _hexPoints(center, radius);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }

}

enum _SymbolType {
  flame,
  footstep,
  arrow,
  footprints,
  check,
  calendar,
  bars,
  target,
  chain,
  star,
  runner,
  lightning,
  stairs,
  balance,
  arrowUp,
  blocks,
  graph,
  spin,
  doubleStar,
  heartbeat,
  shield,
  muscle,
  gear,
  infinity,
  mountain,
  hammer,
  crown,
  medalStar,
  checkSeal,
  brain,
  laurel,
  claw,
  diamond,
  breakline,
  energy,
  sunburst,
  rune,
  motion,
  wings,
  helmet,
  eye,
  triplePeak,
  mobius,
  radiantStar,
  mythicCrest,
}

_LeaderboardItem? _findRank(List<_LeaderboardItem> entries, int rank) {
  for (final entry in entries) {
    if (entry.rank == rank) {
      return entry;
    }
  }
  return null;
}

Color _tierColorForLevel(int level) {
  const tier1 = Color(0xFFCD7F32); // Bronze
  const tier2 = Color(0xFFC0C0C0); // Silver
  const tier3 = Color(0xFFFFD700); // Gold
  const tier4 = Color(0xFF4FC3F7); // Diamond
  const tier5 = Color(0xFFE5E4E2); // Platinum
  final index = ((level - 1) / 10).floor().clamp(0, 4);
  return [tier1, tier2, tier3, tier4, tier5][index];
}
