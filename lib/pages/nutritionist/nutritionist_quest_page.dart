import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/page_transitions.dart';

class NutritionistQuestPage extends StatefulWidget {
  const NutritionistQuestPage({super.key});

  @override
  State<NutritionistQuestPage> createState() => _NutritionistQuestPageState();
}

class _NutritionistQuestPageState extends State<NutritionistQuestPage>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  late final PageController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final int _currentXP = 250;
  final int _level = 4;
  final String _levelTitle = 'Foundation';

  late final List<_LevelInfo> _levels;
  late final List<_QuestItem> _daily;
  late final List<_QuestItem> _weekly;
  late final List<_LeaderboardItem> _leaderboard;
  late final List<_AchievementItem> _achievements;

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
    _daily = [
      _QuestItem(
        title: 'Steps Sprint',
        subtitle: 'Hit 10,000 steps by 8:00 AM',
        icon: Icons.directions_walk_outlined,
        progress: 0.6,
        rewardXP: 60,
        timeLeft: '02:14:33',
      ),
      _QuestItem(
        title: 'Hydration Boost',
        subtitle: 'Drink 2.0L water today',
        icon: Icons.water_drop_outlined,
        progress: 0.75,
        rewardXP: 40,
      ),
      _QuestItem(
        title: 'Calorie Balance',
        subtitle: 'Stay within target calories',
        icon: Icons.local_fire_department_outlined,
        progress: 0.4,
        rewardXP: 50,
      ),
    ];
    _weekly = [
      _QuestItem(
        title: 'Steps Marathon',
        subtitle: 'Total 70,000 steps this week',
        icon: Icons.directions_walk_outlined,
        progress: 0.55,
        rewardXP: 250,
      ),
      _QuestItem(
        title: 'Hydration Streak',
        subtitle: 'Meet water goal 5 days',
        icon: Icons.water_drop_outlined,
        progress: 0.6,
        rewardXP: 180,
      ),
      _QuestItem(
        title: 'Meal Consistency',
        subtitle: 'Log meals 6 days',
        icon: Icons.restaurant_outlined,
        progress: 0.3,
        rewardXP: 200,
      ),
      _QuestItem(
        title: 'Balanced Week',
        subtitle: 'Hit calories goal 4 days',
        icon: Icons.emoji_events_outlined,
        progress: 0.4,
        rewardXP: 160,
      ),
    ];
    _leaderboard = [
      _LeaderboardItem('Mia', 12, 1320, 1),
      _LeaderboardItem('Noah', 11, 1210, 2),
      _LeaderboardItem('Aria', 10, 1170, 3),
      _LeaderboardItem('You', 9, 980, 12),
    ];
    _achievements = [
      _AchievementItem('Consistency', Icons.verified_outlined, 0.8, true),
      _AchievementItem('Hydration', Icons.water_drop_outlined, 0.6, false),
      _AchievementItem('Steps', Icons.directions_walk_outlined, 0.5, false),
      _AchievementItem('Nutrition', Icons.restaurant_outlined, 0.3, false),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openLevelsPage() {
    Navigator.of(context).push(
      PageTransitions.slideRoute(
        LevelsPage(
          currentXP: _currentXP,
          levels: _levels,
        ),
        beginOffset: const Offset(0, 0.05),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                currentXP: _currentXP,
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _XpHero(
                currentXP: _currentXP,
                level: _level,
                title: _levelTitle,
                currentLevelInfo: _levels[_level - 1],
                nextLevelInfo:
                    _level < _levels.length ? _levels[_level] : _levels.last,
                onTapRing: _openLevelsPage,
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
                  _DailySection(
                    quests: _daily,
                    gradient: _primaryGradient,
                  ),
                  _WeeklySection(quests: _weekly),
                  _LeaderboardSection(entries: _leaderboard),
                  _AchievementsSection(items: _achievements),
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
    final nextXP = nextLevelInfo.xpRequired;
    final progress = currentXP / nextXP;
    final needed = (nextXP - currentXP).clamp(0, nextXP);
    final gradient = _tierGradient(currentLevelInfo.tierColor);
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadow,
      ),
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: _MedalBadge(
                        key: ValueKey(currentLevelInfo.level),
                        level: currentLevelInfo.level,
                        color: currentLevelInfo.tierColor,
                        symbol: currentLevelInfo.symbol,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _XpBar(progress: progress),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$currentXP / $nextXP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Need $needed XP',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Next: ${nextLevelInfo.name} ($nextXP XP)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
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
}

class _QuestTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _QuestTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = ['Daily', 'Weekly', 'Leaderboard', 'Achievements'];
    final colorScheme = Theme.of(context).colorScheme;
    final gradients = [
      const LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFFC300)]),
      const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)]),
      const LinearGradient(colors: [Color(0xFF00C2A8), Color(0xFF19C37D)]),
      const LinearGradient(colors: [Color(0xFFFF4D6D), Color(0xFFFF8A00)]),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outline.withOpacity(0.16)),
      ),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          gradient: gradients[selectedIndex],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: Colors.white.withOpacity(0.7),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: Text(
                tabs[selectedIndex],
                key: ValueKey(tabs[selectedIndex]),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _DailySection extends StatelessWidget {
  final List<_QuestItem> quests;
  final LinearGradient gradient;

  const _DailySection({
    required this.quests,
    required this.gradient,
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
                  child: _QuestCard(quest: quest, gradient: gradient),
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

  const _WeeklySection({required this.quests});

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
          return _WeeklyCard(quest: quests[index]);
        },
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
            Container(
              width: size + 18,
              height: size + 18,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: AppColors.cardShadow,
              ),
              child: Center(
                child: _MedalBadge(
                  level: entry!.level,
                  color: tierColor,
                  symbol: _SymbolType.star,
                  size: size,
                ),
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

class LevelsPage extends StatelessWidget {
  final int currentXP;
  final List<_LevelInfo> levels;

  const LevelsPage({
    super.key,
    required this.currentXP,
    required this.levels,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentIndex = _currentLevelIndex(levels, currentXP);
    final currentLevel = levels[currentIndex];
    final nextLevel =
        currentIndex + 1 < levels.length ? levels[currentIndex + 1] : null;
    final levelTiles = <Widget>[];
    for (var i = 0; i < levels.length; i++) {
      levelTiles.add(_LevelRowLarge(
        level: levels[i],
        currentXP: currentXP,
      ));
      if (i != levels.length - 1) {
        levelTiles.add(const SizedBox(height: 12));
      }
    }
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          'Levels',
          style: TextStyle(
            color: colorScheme.onBackground,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _LevelHeader(
            currentLevel: currentLevel,
            nextLevel: nextLevel,
            currentXP: currentXP,
          ),
          const SizedBox(height: 18),
          ...levelTiles,
        ],
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  final _LevelInfo currentLevel;
  final _LevelInfo? nextLevel;
  final int currentXP;

  const _LevelHeader({
    required this.currentLevel,
    required this.nextLevel,
    required this.currentXP,
  });

  @override
  Widget build(BuildContext context) {
    final nextXP = nextLevel?.xpRequired ?? currentLevel.xpRequired;
    final progress =
        nextXP == 0 ? 1.0 : (currentXP / nextXP).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _tierGradient(currentLevel.tierColor),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          _MedalBadge(
            level: currentLevel.level,
            color: currentLevel.tierColor,
            symbol: currentLevel.symbol,
            size: 88,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${currentLevel.level} · ${currentLevel.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentLevel.tierName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nextLevel == null
                      ? 'Max level reached'
                      : '${currentXP} / ${nextXP} XP to ${nextLevel!.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
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

class _LevelRowLarge extends StatelessWidget {
  final _LevelInfo level;
  final int currentXP;

  const _LevelRowLarge({
    required this.level,
    required this.currentXP,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unlocked = currentXP >= level.xpRequired;
    final needed = (level.xpRequired - currentXP).clamp(0, level.xpRequired);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: level.tierColor.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          _MedalBadge(
            level: level.level,
            color: level.tierColor,
            symbol: level.symbol,
            size: 64,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${level.level} · ${level.name}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  level.tierName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  unlocked ? 'Unlocked' : 'Need $needed XP to unlock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${level.xpRequired} XP',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}


class _QuestCard extends StatelessWidget {
  final _QuestItem quest;
  final LinearGradient gradient;

  const _QuestCard({required this.quest, required this.gradient});

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
              _PrimaryButton(label: 'Start', gradient: gradient),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final _QuestItem quest;

  const _WeeklyCard({required this.quest});

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
          _IconBadge(icon: item.icon, size: 32, iconSize: 18),
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
      ),
    );
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MedalBadge(
            level: level,
            color: color.withOpacity(0.95),
            symbol: symbol,
            size: 42,
          ),
          const SizedBox(height: 6),
          Text(
            'Lv $level',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final double progress;

  const _XpBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(color: Colors.white.withOpacity(0.12)),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(color: Colors.white),
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

  const _PrimaryButton({required this.label, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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

  _QuestItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.progress,
    required this.rewardXP,
    this.timeLeft,
  });
}

class _LeaderboardItem {
  final String name;
  final int level;
  final int xp;
  final int rank;

  _LeaderboardItem(this.name, this.level, this.xp, this.rank);
}

class _AchievementItem {
  final String title;
  final IconData icon;
  final double progress;
  final bool unlocked;

  _AchievementItem(this.title, this.icon, this.progress, this.unlocked);
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
  const tier4 = Color(0xFF4FC3F7); // Diamond
  const tier5 = Color(0xFFE5E4E2); // Platinum

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
      'Rookie',
      'Challenger',
      'Pro',
      'Legendary',
      'Elite',
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

int _currentLevelIndex(List<_LevelInfo> levels, int xp) {
  var index = 0;
  for (var i = 0; i < levels.length; i++) {
    if (xp >= levels[i].xpRequired) {
      index = i;
    } else {
      break;
    }
  }
  return index;
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
