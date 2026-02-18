import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared level info model for quest levels across client, trainer, nutritionist.
class LevelInfo {
  final int level;
  final String name;
  final int xpRequired;
  final String tierName;
  final Color tierColor;
  final SymbolType symbol;

  const LevelInfo({
    required this.level,
    required this.name,
    required this.xpRequired,
    required this.tierName,
    required this.tierColor,
    required this.symbol,
  });
}

enum SymbolType {
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

/// Build the canonical 50-level progression. Used by quest, trainer, nutritionist.
List<LevelInfo> buildQuestLevels() {
  const tier1 = Color(0xFFCD7F32); // Rookie
  const tier2 = Color(0xFFC0C0C0); // Challenger
  const tier3 = Color(0xFFFFD700); // Pro
  const tier4 = Color(0xFFE5E4E2); // Elite
  const tier5 = Color(0xFF4FC3F7); // Legendary

  final names = [
    'Rookie', 'Starter', 'Mover', 'Walker', 'Tracker', 'Habit Builder',
    'Consistent', 'Focused', 'Committed', 'Foundation Complete',
    'Strider', 'Energized', 'Stepper', 'Balancer', 'Performer', 'Driven',
    'Builder', 'Progressor', 'Momentum', 'Momentum Master',
    'Athlete', 'Fuelled', 'Conditioned', 'Resilient', 'Stronger', 'Grinder',
    'Endurance', 'Peak Ready', 'Relentless', 'Performance Elite',
    'Veteran', 'Pro', 'Expert', 'Champion', 'Dominator', 'Prime',
    'Unstoppable', 'Elite Force', 'Supreme', 'Elite Legend',
    'Mythic', 'Overdrive', 'Ascended', 'Immortal', 'Titan', 'Godmode',
    'Apex', 'Infinity', 'Icon', 'Cotrainr Elite',
  ];

  final tierSymbols = [
    [SymbolType.flame, SymbolType.footstep, SymbolType.arrow, SymbolType.footprints,
     SymbolType.check, SymbolType.calendar, SymbolType.bars, SymbolType.target,
     SymbolType.chain, SymbolType.star],
    [SymbolType.runner, SymbolType.lightning, SymbolType.stairs, SymbolType.balance,
     SymbolType.star, SymbolType.arrowUp, SymbolType.blocks, SymbolType.graph,
     SymbolType.spin, SymbolType.doubleStar],
    [SymbolType.runner, SymbolType.flame, SymbolType.heartbeat, SymbolType.shield,
     SymbolType.muscle, SymbolType.gear, SymbolType.infinity, SymbolType.mountain,
     SymbolType.hammer, SymbolType.crown],
    [SymbolType.medalStar, SymbolType.checkSeal, SymbolType.brain, SymbolType.laurel,
     SymbolType.claw, SymbolType.diamond, SymbolType.breakline, SymbolType.energy,
     SymbolType.sunburst, SymbolType.crown],
    [SymbolType.rune, SymbolType.motion, SymbolType.wings, SymbolType.infinity,
     SymbolType.helmet, SymbolType.eye, SymbolType.triplePeak, SymbolType.mobius,
     SymbolType.radiantStar, SymbolType.mythicCrest],
  ];

  final levels = <LevelInfo>[];
  var xp = 0.0;
  var step = 100.0;
  for (var i = 0; i < 50; i++) {
    if (i > 0) {
      xp += step;
      step = (step * 1.12).clamp(100, 1200);
    }
    final level = i + 1;
    final tierIndex = (i / 10).floor();
    final tierName = ['Rookie', 'Challenger', 'Pro', 'Elite', 'Legendary'][tierIndex];
    final tierColor = [tier1, tier2, tier3, tier4, tier5][tierIndex];
    levels.add(LevelInfo(
      level: level,
      name: names[i],
      xpRequired: xp.round(),
      tierName: tierName,
      tierColor: tierColor,
      symbol: tierSymbols[tierIndex][i % 10],
    ));
  }
  return levels;
}

String getBadgePathFromLevel(int level) {
  final tierIndex = ((level - 1) / 10).floor();
  final badgeTier = tierIndex + 1;
  switch (badgeTier) {
    case 1: return 'assets/badges/badge_bronze.svg';
    case 2: return 'assets/badges/badge_silver.svg';
    case 3: return 'assets/badges/badge_gold.svg';
    case 4: return 'assets/badges/badge_platinum.svg';
    case 5: return 'assets/badges/badge_diamond.svg';
    default: return 'assets/badges/badge_bronze.svg';
  }
}

String _getBadgePathFromTierName(String tierName) {
  switch (tierName) {
    case 'Rookie': return 'assets/badges/badge_bronze.svg';
    case 'Challenger': return 'assets/badges/badge_silver.svg';
    case 'Pro': return 'assets/badges/badge_gold.svg';
    case 'Elite': return 'assets/badges/badge_platinum.svg';
    case 'Legendary': return 'assets/badges/badge_diamond.svg';
    default: return 'assets/badges/badge_bronze.svg';
  }
}

LinearGradient tierGradient(Color base) {
  return LinearGradient(
    colors: [base.withOpacity(0.95), Color.lerp(base, Colors.black, 0.25) ?? base],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

Color _getTierLightColor(String tierName, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    switch (tierName) {
      case 'Rookie': return const Color(0xFF3D2A1A);
      case 'Challenger': return const Color(0xFF1A2332);
      case 'Pro': return const Color(0xFF3D3519);
      case 'Elite': return const Color(0xFF1A2332);
      case 'Legendary': return const Color(0xFF2A1F3D);
      default: return const Color(0xFF3D2A1A);
    }
  } else {
    switch (tierName) {
      case 'Rookie': return const Color(0xFFFFF4E6);
      case 'Challenger': return const Color(0xFFF0F8FF);
      case 'Pro': return const Color(0xFFFFFBE6);
      case 'Elite': return const Color(0xFFF0F8FF);
      case 'Legendary': return const Color(0xFFF5F0FF);
      default: return const Color(0xFFFFF4E6);
    }
  }
}

String _getTierNameFromLevel(int level) {
  final tierIndex = ((level - 1) / 10).floor();
  final tierNames = ['Rookie', 'Challenger', 'Pro', 'Elite', 'Legendary'];
  return tierIndex < tierNames.length ? tierNames[tierIndex] : 'Rookie';
}

/// Shared Levels page - tiered collapsible UI. Used by quest, trainer, nutritionist.
class LevelsPage extends StatefulWidget {
  final int currentXP;
  final List<LevelInfo> levels;

  const LevelsPage({super.key, required this.currentXP, required this.levels});

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final Map<int, bool> _expandedTiers = {0: true};

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
    final cs = Theme.of(context).colorScheme;
    final tierGroups = <List<LevelInfo>>[];
    for (var i = 0; i < widget.levels.length; i += 10) {
      final end = (i + 10).clamp(0, widget.levels.length);
      tierGroups.add(widget.levels.sublist(i, end));
    }

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
        : tierGroups.isNotEmpty ? tierGroups[0] : <LevelInfo>[];
    final currentLevel = currentLevelIndex < widget.levels.length
        ? widget.levels[currentLevelIndex]
        : null;
    final nextLevel = currentLevelIndex + 1 < widget.levels.length
        ? widget.levels[currentLevelIndex + 1]
        : null;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onBackground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Levels', style: TextStyle(color: cs.onBackground, fontWeight: FontWeight.w700)),
      ),
      body: widget.levels.isEmpty || tierGroups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 48, color: cs.onBackground.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No levels available', style: TextStyle(color: cs.onBackground, fontSize: 16)),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                if (currentTier.isNotEmpty && currentLevel != null)
                  _TierHeader(
                    tierLevels: currentTier,
                    currentLevel: currentLevel,
                    nextLevel: nextLevel,
                    currentXP: widget.currentXP,
                    pulseAnimation: _pulseController,
                  ),
                const SizedBox(height: 24),
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
                        onToggle: () => setState(() => _expandedTiers[tierIndex] = !isExpanded),
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

class _TierHeader extends StatelessWidget {
  final List<LevelInfo> tierLevels;
  final LevelInfo currentLevel;
  final LevelInfo? nextLevel;
  final int currentXP;
  final AnimationController pulseAnimation;

  const _TierHeader({
    required this.tierLevels,
    required this.currentLevel,
    required this.nextLevel,
    required this.currentXP,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tierName = currentLevel.tierName;
    final tierColor = currentLevel.tierColor;
    final nextXP = nextLevel?.xpRequired ?? currentLevel.xpRequired;
    final progress = nextXP > 0
        ? ((currentXP - currentLevel.xpRequired) / (nextXP - currentLevel.xpRequired)).clamp(0.0, 1.0)
        : 1.0;
    final neededXP = (nextXP - currentXP).clamp(0, nextXP);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cs.surface),
      child: Column(
        children: [
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
          Text(tierName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: cs.onSurface, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('Levels ${tierLevels.first.level} - ${tierLevels.last.level}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 24),
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
                    Text('Level ${currentLevel.level}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tierColor)),
                    const SizedBox(width: 8),
                    Text('· ${currentLevel.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                  ),
                ),
                const SizedBox(height: 12),
                Text(neededXP > 0 ? '$neededXP XP to next level' : 'Max level in tier',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierSectionCard extends StatefulWidget {
  final int tierIndex;
  final List<LevelInfo> tierLevels;
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

class _TierSectionCardState extends State<_TierSectionCard> with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnimation = CurvedAnimation(parent: _expandController, curve: Curves.easeInOut);
    if (widget.isExpanded) _expandController.value = 1.0;
  }

  @override
  void didUpdateWidget(_TierSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) _expandController.forward();
      else _expandController.reverse();
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstLevel = widget.tierLevels.first;
    final tierName = firstLevel.tierName;
    final tierColor = firstLevel.tierColor;

    int currentLevelIndex = -1;
    for (var i = 0; i < widget.tierLevels.length; i++) {
      if (widget.currentXP >= widget.tierLevels[i].xpRequired) currentLevelIndex = i;
      else break;
    }

    final tierLightColor = _getTierLightColor(tierName, context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isUnlocked
            ? tierLightColor
            : (Theme.of(context).brightness == Brightness.dark ? cs.surfaceContainerHighest.withOpacity(0.3) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.isUnlocked ? widget.onToggle : null,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: widget.isUnlocked
                        ? SvgPicture.asset(_getBadgePathFromTierName(tierName), width: 40, height: 40, fit: BoxFit.contain)
                        : ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 0.3, 0,
                            ]),
                            child: SvgPicture.asset(_getBadgePathFromTierName(tierName), width: 40, height: 40, fit: BoxFit.contain),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$tierName Tier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget.isUnlocked ? cs.onSurface : cs.onSurface.withOpacity(0.5))),
                        Text('Levels ${widget.tierLevels.first.level} - ${widget.tierLevels.last.level}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  if (!widget.isUnlocked)
                    Icon(Icons.lock_rounded, color: cs.onSurface.withOpacity(0.4), size: 20)
                  else
                    AnimatedRotation(
                      turns: widget.isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(Icons.expand_more_rounded, color: cs.onSurface),
                    ),
                ],
              ),
            ),
          ),
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
                  nextLevel: index + 1 < widget.tierLevels.length ? widget.tierLevels[index + 1] : null,
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

class _LevelCard extends StatelessWidget {
  final LevelInfo level;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final int currentXP;
  final LevelInfo? nextLevel;
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
    final cs = Theme.of(context).colorScheme;
    double progress = 0.0;
    int neededXP = 0;
    if (isCurrent && nextLevel != null) {
      progress = ((currentXP - level.xpRequired) / (nextLevel!.xpRequired - level.xpRequired)).clamp(0.0, 1.0);
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
          SizedBox(
            width: 40,
            height: 40,
            child: isLocked
                ? ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 0.3, 0,
                    ]),
                    child: SvgPicture.asset(getBadgePathFromLevel(level.level), width: 40, height: 40, fit: BoxFit.contain),
                  )
                : SvgPicture.asset(getBadgePathFromLevel(level.level), width: 40, height: 40, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
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
                        color: isLocked ? cs.onSurface.withOpacity(0.4) : (isCurrent ? tierColor : cs.onSurface),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(gradient: tierGradient(tierColor), borderRadius: BorderRadius.circular(8)),
                        child: const Text('CURRENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
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
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$neededXP XP to Level ${nextLevel!.level}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.7))),
                    ],
                  )
                else if (isLocked)
                  Text('Unlocks at Level ${level.level}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.5)))
                else
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, size: 12, color: tierColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text('${level.xpRequired} XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.6))),
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
