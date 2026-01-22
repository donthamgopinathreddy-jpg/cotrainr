import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class MealTrackerPage extends StatefulWidget {
  const MealTrackerPage({super.key});

  @override
  State<MealTrackerPage> createState() => _MealTrackerPageState();
}

class _MealTrackerPageState extends State<MealTrackerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
  final Random _r = Random();

  int goalCals = 2000;
  int calories = 1260;
  int protein = 92;
  int carbs = 140;
  int fats = 38;

  @override
  void initState() {
    super.initState();
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  // Match Quick Access green gradient exactly
  LinearGradient get _greenGrad => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.green, // Color(0xFF3ED598)
          Color(0xFF65E6B3),
        ],
      );

  Color textHi(BuildContext c) => Theme.of(c).colorScheme.onSurface;
  Color textLo(BuildContext c) =>
      Theme.of(c).colorScheme.onSurface.withOpacity(.72);
  Color surface(BuildContext c) => Theme.of(c).colorScheme.surface;

  Future<void> _openAddFood(String meal) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: _GlassSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Add Food',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textHi(c))),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    maxLength: 60,
                    decoration: InputDecoration(
                      hintText: 'Food name',
                      counterText: '',
                      filled: true,
                      fillColor: surface(c).withOpacity(.45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _NumField(label: 'Calories')),
                      const SizedBox(width: 10),
                      Expanded(child: _NumField(label: 'Protein(g)')),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _NumField(label: 'Carbs(g)')),
                      const SizedBox(width: 10),
                      Expanded(child: _NumField(label: 'Fats(g)')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: _greenGrad,
                          borderRadius: BorderRadius.circular(18)),
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            calories += 80 + _r.nextInt(200);
                            protein += 5 + _r.nextInt(15);
                            carbs += 8 + _r.nextInt(20);
                            fats += 2 + _r.nextInt(10);
                          });
                          Navigator.pop(c);
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18))),
                        child: Text('Save To $meal',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openWeekly(String type) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WeeklyInsightsPage(
              title: type,
              accent: _greenGrad,
            )));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.background;
    final p = (calories / goalCals).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fade,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _TopBar(onCalendar: () {})),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: _DailySummary(
                    accent: _greenGrad,
                    calories: calories,
                    goal: goalCals,
                    protein: protein,
                    carbs: carbs,
                    fats: fats,
                    progress: p,
                    onTap: () => _openWeekly('All'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Text('Today Meals',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textHi(context))),
                      const Spacer(),
                      _GhostPill(
                          label: 'Weekly Insights',
                          icon: Icons.show_chart_rounded,
                          onTap: () => _openWeekly('All')),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    _MealTile(
                        title: 'Breakfast',
                        subtitle: 'Quick start',
                        accent: _greenGrad,
                        onOpen: () => _openWeekly('Breakfast'),
                        onAdd: () => _openAddFood('Breakfast')),
                    _MealTile(
                        title: 'Lunch',
                        subtitle: 'Balanced',
                        accent: _greenGrad,
                        onOpen: () => _openWeekly('Lunch'),
                        onAdd: () => _openAddFood('Lunch')),
                    _MealTile(
                        title: 'Snacks',
                        subtitle: 'Smart fuel',
                        accent: _greenGrad,
                        onOpen: () => _openWeekly('Snacks'),
                        onAdd: () => _openAddFood('Snacks')),
                    _MealTile(
                        title: 'Dinner',
                        subtitle: 'Recover',
                        accent: _greenGrad,
                        onOpen: () => _openWeekly('Dinner'),
                        onAdd: () => _openAddFood('Dinner')),
                    _AddMealTile(
                        accent: _greenGrad,
                        onTap: () => _openAddFood('Custom')),
                  ]),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _CreateFab(
          accent: _greenGrad, onTap: () => _openAddFood('Quick Add')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onCalendar;
  const _TopBar({required this.onCalendar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meal Tracker',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface)),
              Text('Track nutrition goals',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(.65))),
            ],
          ),
          const Spacer(),
          IconButton(
              onPressed: onCalendar,
              icon: const Icon(Icons.calendar_month_rounded)),
        ],
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  final LinearGradient accent;
  final int calories, goal, protein, carbs, fats;
  final double progress;
  final VoidCallback onTap;
  const _DailySummary({
    required this.accent,
    required this.calories,
    required this.goal,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    final lo = on.withOpacity(.72);
    final surf = Theme.of(context).colorScheme.surface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surf.withOpacity(.55),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 18,
                offset: const Offset(0, 10))
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
                child: Opacity(
              opacity: .10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: accent, borderRadius: BorderRadius.circular(26)),
              ),
            )),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Calories',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: lo)),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$calories',
                                style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: on)),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('/$goal',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: lo)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MacroChip(
                                label: 'P',
                                value: '${protein}g',
                                accent: accent),
                            _MacroChip(
                                label: 'C', value: '${carbs}g', accent: accent),
                            _MacroChip(
                                label: 'F', value: '${fats}g', accent: accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Ring(progress: progress, accent: accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends ImplicitlyAnimatedWidget {
  final double progress;
  final LinearGradient accent;
  const _Ring({required this.progress, required this.accent})
      : super(duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic);

  @override
  ImplicitlyAnimatedWidgetState<_Ring> createState() => _RingState();
}

class _RingState extends AnimatedWidgetBaseState<_Ring> {
  Tween<double>? _t;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _t = visitor(_t, widget.progress,
            (v) => Tween<double>(begin: v as double)) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final p = _t?.evaluate(animation) ?? 0;
    return SizedBox(
      height: 82,
      width: 82,
      child: Stack(
        children: [
          CustomPaint(painter: _RingPainter(p, widget.accent)),
          Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${(p * 100).round()}%',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface)),
              Text('Goal',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(.65))),
            ],
          )),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  final LinearGradient g;
  _RingPainter(this.p, this.g);

  @override
  void paint(Canvas c, Size s) {
    final r = min(s.width, s.height) / 2 - 6;
    final center = Offset(s.width / 2, s.height / 2);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.white.withOpacity(.10)
      ..strokeCap = StrokeCap.round;
    c.drawArc(Rect.fromCircle(center: center, radius: r), -pi / 2, 2 * pi,
        false, bg);
    final rect = Rect.fromCircle(center: center, radius: r);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = g.createShader(rect);
    c.drawArc(rect, -pi / 2, 2 * pi * p, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.p != p;
}

class _MacroChip extends StatelessWidget {
  final String label, value;
  final LinearGradient accent;
  const _MacroChip(
      {required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    final on = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surf.withOpacity(.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(gradient: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900, color: on)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: on.withOpacity(.75))),
        ],
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  final String title, subtitle;
  final LinearGradient accent;
  final VoidCallback onOpen, onAdd;
  const _MealTile({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    final on = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onOpen();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: surf.withOpacity(.52),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 16,
                offset: const Offset(0, 10))
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
                child: Opacity(
              opacity: .10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: accent, borderRadius: BorderRadius.circular(22)),
              ),
            )),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            gradient: accent,
                            borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.restaurant_rounded,
                            color: Colors.black),
                      ),
                      const Spacer(),
                      IconButton(
                          onPressed: onAdd,
                          icon: Icon(Icons.add_circle_rounded,
                              color: on.withOpacity(.9))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: on)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: on.withOpacity(.65))),
                  const Spacer(),
                  Row(
                    children: [
                      Text('Tap for insights',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: on.withOpacity(.60))),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: on.withOpacity(.55)),
                    ],
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

class _AddMealTile extends StatelessWidget {
  final LinearGradient accent;
  final VoidCallback onTap;
  const _AddMealTile({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    final on = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: surf.withOpacity(.40),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                    gradient: accent, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.add_rounded,
                    color: Colors.black, size: 30),
              ),
              const SizedBox(height: 10),
              Text('Add Meal',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900, color: on)),
              Text('Custom tile',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: on.withOpacity(.65))),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GhostPill(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    final on = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: surf.withOpacity(.35),
            borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: on.withOpacity(.75)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: on.withOpacity(.85))),
          ],
        ),
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  final LinearGradient accent;
  final VoidCallback onTap;
  const _CreateFab({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
            gradient: accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10))
            ]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.black),
            const SizedBox(width: 8),
            const Text('Quick Add',
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(.70),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.22),
              blurRadius: 26,
              offset: const Offset(0, -10))
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  const _NumField({required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withOpacity(.45),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
      ),
    );
  }
}

class WeeklyInsightsPage extends StatelessWidget {
  final String title;
  final LinearGradient accent;
  const WeeklyInsightsPage(
      {super.key, required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    final bg = Theme.of(context).colorScheme.background;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('$title Insights',
            style: TextStyle(fontWeight: FontWeight.w900, color: on)),
        iconTheme: IconThemeData(color: on),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(.55),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                      child: Opacity(
                    opacity: .10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: accent,
                          borderRadius: BorderRadius.circular(26)),
                    ),
                  )),
                  Center(
                      child: Text('Line Graph Here',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: on.withOpacity(.75)))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Stats',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: on)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatCard(k: 'Avg', v: '—'),
                _StatCard(k: 'Best', v: '—'),
                _StatCard(k: 'Streak', v: '—'),
                _StatCard(k: 'Trend', v: '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String k, v;
  const _StatCard({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    final on = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: surf.withOpacity(.50),
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: on.withOpacity(.65))),
          const SizedBox(height: 6),
          Text(v,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: on)),
        ],
      ),
    );
  }
}
