import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../cocircle/image_crop_page.dart';
import 'weekly_insights_page.dart';

class MealTrackerPageV2 extends StatefulWidget {
  const MealTrackerPageV2({super.key});

  @override
  State<MealTrackerPageV2> createState() => _MealTrackerPageV2State();
}

class _MealTrackerPageV2State extends State<MealTrackerPageV2>
    with TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late AnimationController _ringController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _ringAnimation;

  int _selectedDayIndex = 6; // Today is index 6 (7 days, 0-6)

  // Daily goals
  int goalCalories = 2000;
  int goalProtein = 150; // grams
  int goalCarbs = 200; // grams
  int goalFats = 65; // grams

  // Current totals
  int calories = 1260;
  int protein = 92;
  int carbs = 140;
  int fats = 38;

  // Meal data
  final Map<String, List<FoodItem>> _meals = {
    'Breakfast': [],
    'Lunch': [],
    'Dinner': [],
    'Snacks': [],
  };

  // Recent foods for quick add
  final List<FoodItem> _recentFoods = [];
  final List<FoodItem> _commonFoods = [
    FoodItem(name: 'Chicken Breast', calories: 165, protein: 31, carbs: 0, fats: 3.6, unit: '100g'),
    FoodItem(name: 'Brown Rice', calories: 111, protein: 2.6, carbs: 23, fats: 0.9, unit: '100g'),
    FoodItem(name: 'Salmon', calories: 208, protein: 20, carbs: 0, fats: 13, unit: '100g'),
    FoodItem(name: 'Eggs', calories: 155, protein: 13, carbs: 1.1, fats: 11, unit: '100g'),
    FoodItem(name: 'Banana', calories: 89, protein: 1.1, carbs: 23, fats: 0.3, unit: '1 medium'),
    FoodItem(name: 'Greek Yogurt', calories: 100, protein: 10, carbs: 3.6, fats: 5, unit: '100g'),
    FoodItem(name: 'Oatmeal', calories: 68, protein: 2.4, carbs: 12, fats: 1.4, unit: '100g'),
    FoodItem(name: 'Almonds', calories: 579, protein: 21, carbs: 22, fats: 50, unit: '100g'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _ringController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ringController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Theme-aware colors
  Color _getPageBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF07130E) // Dark mode start
        : const Color(0xFFEAFBF0); // Light mode mint
  }

  Color _getSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF0B1510).withOpacity(0.72)
        : Colors.white.withOpacity(0.78);
  }

  Color _getTextPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFEFFFF5) : const Color(0xFF0B1B12);
  }

  Color _getTextSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFFBFE8D1).withOpacity(0.75)
        : const Color(0xFF2E5A42).withOpacity(0.75);
  }

  // Green gradients
  LinearGradient get _primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF19C37D), Color(0xFF0FA35F)],
      );


  // Get days for strip
  List<DateTime> _getDays() {
    final today = DateTime.now();
    return List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });
  }

  void _onDaySelected(int index) {
    HapticFeedback.selectionClick();
      setState(() {
        _selectedDayIndex = index;
        // Reset totals for selected day (in real app, load from storage)
        calories = 1260;
        protein = 92;
        carbs = 140;
        fats = 38;
      });
    _ringController.reset();
    _ringController.forward();
  }

  Future<void> _openAddFood({String? mealType}) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddFoodSheet(
        mealType: mealType,
        onFoodAdded: (food, meal) {
          setState(() {
            _meals[meal]!.add(food);
            calories += food.calories;
            protein += food.protein.toInt();
            carbs += food.carbs.toInt();
            fats += food.fats.toInt();
            if (!_recentFoods.contains(food)) {
              _recentFoods.insert(0, food);
              if (_recentFoods.length > 5) _recentFoods.removeLast();
            }
          });
          _ringController.reset();
          _ringController.forward();
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to $meal'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        commonFoods: _commonFoods,
        recentFoods: _recentFoods,
      ),
    );
  }

  Future<void> _openMealDetail(String mealType) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MealDetailSheet(
        mealType: mealType,
        foods: _meals[mealType]!,
        onFoodDeleted: (food) {
          setState(() {
            _meals[mealType]!.remove(food);
            calories -= food.calories;
            protein -= food.protein.toInt();
            carbs -= food.carbs.toInt();
            fats -= food.fats.toInt();
          });
          _ringController.reset();
          _ringController.forward();
          HapticFeedback.mediumImpact();
        },
        onAddFood: () => _openAddFood(mealType: mealType),
      ),
    );
  }

  Future<void> _openWeeklyInsights() async {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WeeklyInsightsPage(gradient: _primaryGradient),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = _getPageBg(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? null
          : pageBg, // Use gradient for dark mode
      body: Container(
        decoration: isDark
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF07130E),
                    const Color(0xFF05080A),
                  ],
                ),
              )
            : null,
        child: SafeArea(
          bottom: false,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverToBoxAdapter(
                  child: _MealTrackerAppBar(
                    onCalendar: () {},
                    onInsights: _openWeeklyInsights,
                    textPrimary: _getTextPrimary(context),
                  ),
                ),
                // Day Strip
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DayStripDelegate(
                    days: _getDays(),
                    selectedIndex: _selectedDayIndex,
                    onDaySelected: _onDaySelected,
                    primaryGradient: _primaryGradient,
                    surface: _getSurface(context),
                    textPrimary: _getTextPrimary(context),
                  ),
                ),
                // Daily Summary
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: _DailySummaryCard(
                      calories: calories,
                      goalCalories: goalCalories,
                      protein: protein,
                      goalProtein: goalProtein,
                      carbs: carbs,
                      goalCarbs: goalCarbs,
                      fats: fats,
                      goalFats: goalFats,
                      primaryGradient: _primaryGradient,
                      surface: _getSurface(context),
                      textPrimary: _getTextPrimary(context),
                      textSecondary: _getTextSecondary(context),
                      ringAnimation: _ringAnimation,
                      onInsightsTap: _openWeeklyInsights,
                    ),
                  ),
                ),
                // Meal Tiles Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    delegate: SliverChildListDelegate([
                      _MealTile(
                        mealType: 'Breakfast',
                        icon: Icons.breakfast_dining_rounded,
                        itemCount: _meals['Breakfast']!.length,
                        calories: _meals['Breakfast']!
                            .fold(0, (sum, f) => sum + f.calories),
                        protein: _meals['Breakfast']!
                            .fold(0.0, (sum, f) => sum + f.protein),
                        carbs: _meals['Breakfast']!
                            .fold(0.0, (sum, f) => sum + f.carbs),
                        fats: _meals['Breakfast']!
                            .fold(0.0, (sum, f) => sum + f.fats),
                        gradient: _primaryGradient,
                        surface: _getSurface(context),
                        textPrimary: _getTextPrimary(context),
                        textSecondary: _getTextSecondary(context),
                        onTap: () => _openMealDetail('Breakfast'),
                        onAddFood: () => _openAddFood(mealType: 'Breakfast'),
                        onAddPhoto: () async {
                          final image = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageCropPage(
                                  imageFile: File(image.path),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _MealTile(
                        mealType: 'Lunch',
                        icon: Icons.lunch_dining_rounded,
                        itemCount: _meals['Lunch']!.length,
                        calories: _meals['Lunch']!
                            .fold(0, (sum, f) => sum + f.calories),
                        protein: _meals['Lunch']!
                            .fold(0.0, (sum, f) => sum + f.protein),
                        carbs: _meals['Lunch']!
                            .fold(0.0, (sum, f) => sum + f.carbs),
                        fats: _meals['Lunch']!
                            .fold(0.0, (sum, f) => sum + f.fats),
                        gradient: _primaryGradient,
                        surface: _getSurface(context),
                        textPrimary: _getTextPrimary(context),
                        textSecondary: _getTextSecondary(context),
                        onTap: () => _openMealDetail('Lunch'),
                        onAddFood: () => _openAddFood(mealType: 'Lunch'),
                        onAddPhoto: () async {
                          final image = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageCropPage(
                                  imageFile: File(image.path),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _MealTile(
                        mealType: 'Dinner',
                        icon: Icons.dinner_dining_rounded,
                        itemCount: _meals['Dinner']!.length,
                        calories: _meals['Dinner']!
                            .fold(0, (sum, f) => sum + f.calories),
                        protein: _meals['Dinner']!
                            .fold(0.0, (sum, f) => sum + f.protein),
                        carbs: _meals['Dinner']!
                            .fold(0.0, (sum, f) => sum + f.carbs),
                        fats: _meals['Dinner']!
                            .fold(0.0, (sum, f) => sum + f.fats),
                        gradient: _primaryGradient,
                        surface: _getSurface(context),
                        textPrimary: _getTextPrimary(context),
                        textSecondary: _getTextSecondary(context),
                        onTap: () => _openMealDetail('Dinner'),
                        onAddFood: () => _openAddFood(mealType: 'Dinner'),
                        onAddPhoto: () async {
                          final image = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageCropPage(
                                  imageFile: File(image.path),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _MealTile(
                        mealType: 'Snacks',
                        icon: Icons.cookie_rounded,
                        itemCount: _meals['Snacks']!.length,
                        calories: _meals['Snacks']!
                            .fold(0, (sum, f) => sum + f.calories),
                        protein: _meals['Snacks']!
                            .fold(0.0, (sum, f) => sum + f.protein),
                        carbs: _meals['Snacks']!
                            .fold(0.0, (sum, f) => sum + f.carbs),
                        fats: _meals['Snacks']!
                            .fold(0.0, (sum, f) => sum + f.fats),
                        gradient: _primaryGradient,
                        surface: _getSurface(context),
                        textPrimary: _getTextPrimary(context),
                        textSecondary: _getTextSecondary(context),
                        onTap: () => _openMealDetail('Snacks'),
                        onAddFood: () => _openAddFood(mealType: 'Snacks'),
                        onAddPhoto: () async {
                          final image = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageCropPage(
                                  imageFile: File(image.path),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ]),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _QuickAddFab(
        gradient: _primaryGradient,
        onTap: () => _openAddFood(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// Food Item Model
class FoodItem {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final String unit;
  final double quantity;

  FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.unit,
    this.quantity = 1.0,
  });

  FoodItem copyWith({
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fats,
    String? unit,
    double? quantity,
  }) {
    return FoodItem(
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
    );
  }

  // Calculate totals based on quantity
  int get totalCalories => (calories * quantity).round();
  double get totalProtein => protein * quantity;
  double get totalCarbs => carbs * quantity;
  double get totalFats => fats * quantity;
}

// App Bar
class _MealTrackerAppBar extends StatelessWidget {
  final VoidCallback onCalendar;
  final VoidCallback onInsights;
  final Color textPrimary;

  const _MealTrackerAppBar({
    required this.onCalendar,
    required this.onInsights,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Meal Tracker',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onCalendar,
            icon: Icon(Icons.calendar_month_rounded, color: textPrimary),
          ),
          IconButton(
            onPressed: onInsights,
            icon: Icon(Icons.show_chart_rounded, color: textPrimary),
          ),
        ],
      ),
    );
  }
}

// Day Strip Delegate
class _DayStripDelegate extends SliverPersistentHeaderDelegate {
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;
  final LinearGradient primaryGradient;
  final Color surface;
  final Color textPrimary;

  _DayStripDelegate({
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
    required this.primaryGradient,
    required this.surface,
    required this.textPrimary,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(days.length, (index) {
            final day = days[index];
            final isSelected = index == selectedIndex;
            final isToday = day.day == DateTime.now().day &&
                day.month == DateTime.now().month &&
                day.year == DateTime.now().year;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onDaySelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? primaryGradient : null,
                    color: isSelected
                        ? null
                        : surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF19C37D).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getDayName(day.weekday),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : textPrimary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? textPrimary
                                  : textPrimary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant _DayStripDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}

// Daily Summary Card
class _DailySummaryCard extends StatelessWidget {
  final int calories;
  final int goalCalories;
  final int protein;
  final int goalProtein;
  final int carbs;
  final int goalCarbs;
  final int fats;
  final int goalFats;
  final LinearGradient primaryGradient;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Animation<double> ringAnimation;
  final VoidCallback onInsightsTap;

  const _DailySummaryCard({
    required this.calories,
    required this.goalCalories,
    required this.protein,
    required this.goalProtein,
    required this.carbs,
    required this.goalCarbs,
    required this.fats,
    required this.goalFats,
    required this.primaryGradient,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.ringAnimation,
    required this.onInsightsTap,
  });

  @override
  Widget build(BuildContext context) {
    final pProgress = (protein / goalProtein).clamp(0.0, 1.0);
    final cProgress = (carbs / goalCarbs).clamp(0.0, 1.0);
    final fProgress = (fats / goalFats).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onInsightsTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gradient overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                // Top row: Calories + Rings
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Calories',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$calories',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '/$goalCalories',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Macro chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MacroChip(
                                label: 'P',
                                value: '${protein}g',
                                goal: goalProtein,
                                gradient: primaryGradient,
                                surface: surface,
                                textPrimary: textPrimary,
                              ),
                              _MacroChip(
                                label: 'C',
                                value: '${carbs}g',
                                goal: goalCarbs,
                                gradient: primaryGradient,
                                surface: surface,
                                textPrimary: textPrimary,
                              ),
                              _MacroChip(
                                label: 'F',
                                value: '${fats}g',
                                goal: goalFats,
                                gradient: primaryGradient,
                                surface: surface,
                                textPrimary: textPrimary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Triple Ring Progress
                    _TripleRingProgress(
                      proteinProgress: pProgress,
                      carbsProgress: cProgress,
                      fatsProgress: fProgress,
                      gradient: primaryGradient,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      animation: ringAnimation,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Weekly Insights Button
                GestureDetector(
                  onTap: onInsightsTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: textPrimary.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 18,
                          color: textPrimary.withOpacity(0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Weekly Insights',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
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

// Triple Ring Progress
class _TripleRingProgress extends StatelessWidget {
  final double proteinProgress;
  final double carbsProgress;
  final double fatsProgress;
  final LinearGradient gradient;
  final Color textPrimary;
  final Color textSecondary;
  final Animation<double> animation;

  const _TripleRingProgress({
    required this.proteinProgress,
    required this.carbsProgress,
    required this.fatsProgress,
    required this.gradient,
    required this.textPrimary,
    required this.textSecondary,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        children: [
          // Outer ring (Fats)
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(90, 90),
                painter: _RingPainter(
                  progress: fatsProgress * animation.value,
                  strokeWidth: 6,
                  startAngle: -pi / 2,
                  color: const Color(0xFF38D9A9),
                ),
              );
            },
          ),
          // Middle ring (Carbs)
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(90, 90),
                painter: _RingPainter(
                  progress: carbsProgress * animation.value,
                  strokeWidth: 6,
                  startAngle: -pi / 2 + (fatsProgress * 2 * pi),
                  color: const Color(0xFF1FBF77),
                ),
              );
            },
          ),
          // Inner ring (Protein)
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(90, 90),
                painter: _RingPainter(
                  progress: proteinProgress * animation.value,
                  strokeWidth: 6,
                  startAngle: -pi / 2 + ((fatsProgress + carbsProgress) * 2 * pi),
                  color: const Color(0xFF19C37D),
                ),
              );
            },
          ),
          // Center label
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final avgProgress = (proteinProgress +
                            carbsProgress +
                            fatsProgress) /
                        3;
                    return Text(
                      '${(avgProgress * 100 * animation.value).round()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    );
                  },
                ),
                Text(
                  'Goal',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
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

// Ring Painter
class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final double startAngle;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.startAngle,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2 - 2;

    // Background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.1)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Macro Chip
class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final int goal;
  final LinearGradient gradient;
  final Color surface;
  final Color textPrimary;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.goal,
    required this.gradient,
    required this.surface,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textPrimary.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// Meal Tile
class _MealTile extends StatelessWidget {
  final String mealType;
  final IconData icon;
  final int itemCount;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final LinearGradient gradient;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onAddFood;
  final VoidCallback onAddPhoto;

  const _MealTile({
    required this.mealType,
    required this.icon,
    required this.itemCount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.gradient,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    required this.onAddFood,
    required this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gradient tint overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF19C37D).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textPrimary.withOpacity(0.4),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Title
                  Text(
                    mealType,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // Calories
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$calories',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text(
                          'kcal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mini macro row
                  Row(
                    children: [
                      _MiniMacroPill('P', protein, textPrimary, textSecondary),
                      const SizedBox(width: 6),
                      _MiniMacroPill('C', carbs, textPrimary, textSecondary),
                      const SizedBox(width: 6),
                      _MiniMacroPill('F', fats, textPrimary, textSecondary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onAddFood();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Food',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onAddPhoto();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: surface.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: textPrimary.withOpacity(0.1),
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: textPrimary.withOpacity(0.8),
                            size: 18,
                          ),
                        ),
                      ),
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

// Mini Macro Pill
class _MiniMacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color textPrimary;
  final Color textSecondary;

  const _MiniMacroPill(
    this.label,
    this.value,
    this.textPrimary,
    this.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: textPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(1)}g',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textSecondary,
        ),
      ),
    );
  }
}

// Quick Add FAB
class _QuickAddFab extends StatefulWidget {
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickAddFab({
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_QuickAddFab> createState() => _QuickAddFabState();
}

class _QuickAddFabState extends State<_QuickAddFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF19C37D).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// Add Food Sheet (simplified for now - will be expanded)
class _AddFoodSheet extends StatefulWidget {
  final String? mealType;
  final Function(FoodItem, String) onFoodAdded;
  final List<FoodItem> commonFoods;
  final List<FoodItem> recentFoods;

  const _AddFoodSheet({
    this.mealType,
    required this.onFoodAdded,
    required this.commonFoods,
    required this.recentFoods,
  });

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  int _step = 0; // 0 = search, 1 = details
  FoodItem? _selectedFood;
  double _quantity = 1.0;
  String _selectedMeal = 'Breakfast';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.mealType != null) {
      _selectedMeal = widget.mealType!;
    }
  }

  void _selectFood(FoodItem food) {
    setState(() {
      _selectedFood = food;
      _step = 1;
    });
    HapticFeedback.selectionClick();
  }

  void _addFood() {
    if (_selectedFood == null) return;
    final adjustedFood = _selectedFood!.copyWith(quantity: _quantity);
    widget.onFoodAdded(adjustedFood, _selectedMeal);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? const Color(0xFF0B1510).withOpacity(0.72)
        : Colors.white.withOpacity(0.78);
    final textPrimary = isDark
        ? const Color(0xFFEFFFF5)
        : const Color(0xFF0B1B12);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: textPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            if (_step == 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search food...',
                    filled: true,
                    fillColor: surface.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.recentFoods.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.recentFoods.length,
                    itemBuilder: (context, index) {
                      final food = widget.recentFoods[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _selectFood(food),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: surface.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              food.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Common Foods',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: widget.commonFoods.length,
                  itemBuilder: (context, index) {
                    final food = widget.commonFoods[index];
                    return GestureDetector(
                      onTap: () => _selectFood(food),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surface.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              food.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${food.calories} kcal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textPrimary.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Step 2: Food Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                          onPressed: () => setState(() => _step = 0),
                        ),
                        Expanded(
                          child: Text(
                            _selectedFood?.name ?? 'Food Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Serving Quantity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textPrimary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '1.0',
                        filled: true,
                        fillColor: surface.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _quantity = double.tryParse(value) ?? 1.0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Meal Type',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textPrimary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                          .map((meal) {
                        final isSelected = _selectedMeal == meal;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedMeal = meal);
                            HapticFeedback.selectionClick();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF19C37D),
                                        Color(0xFF0FA35F),
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : surface.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              meal,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedFood != null) ...[
                      const SizedBox(height: 16),
                      // Live Preview Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textPrimary.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _PreviewStat(
                                  'Calories',
                                  '${(_selectedFood!.calories * _quantity).round()}',
                                  textPrimary,
                                ),
                                _PreviewStat(
                                  'Protein',
                                  '${(_selectedFood!.protein * _quantity).toStringAsFixed(1)}g',
                                  textPrimary,
                                ),
                                _PreviewStat(
                                  'Carbs',
                                  '${(_selectedFood!.carbs * _quantity).toStringAsFixed(1)}g',
                                  textPrimary,
                                ),
                                _PreviewStat(
                                  'Fats',
                                  '${(_selectedFood!.fats * _quantity).toStringAsFixed(1)}g',
                                  textPrimary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Add Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _addFood();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF19C37D), Color(0xFF0FA35F)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Add to $_selectedMeal',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Preview Stat
class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;

  const _PreviewStat(this.label, this.value, this.textPrimary);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textPrimary.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

// Meal Detail Sheet
class _MealDetailSheet extends StatelessWidget {
  final String mealType;
  final List<FoodItem> foods;
  final Function(FoodItem) onFoodDeleted;
  final VoidCallback onAddFood;

  const _MealDetailSheet({
    required this.mealType,
    required this.foods,
    required this.onFoodDeleted,
    required this.onAddFood,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? const Color(0xFF0B1510).withOpacity(0.72)
        : Colors.white.withOpacity(0.78);
    final textPrimary = isDark
        ? const Color(0xFFEFFFF5)
        : const Color(0xFF0B1B12);
    final textSecondary = isDark
        ? const Color(0xFFBFE8D1).withOpacity(0.75)
        : const Color(0xFF2E5A42).withOpacity(0.75);

    final totalCalories = foods.fold(0, (sum, f) => sum + f.totalCalories);
    final totalProtein = foods.fold(0.0, (sum, f) => sum + f.totalProtein);
    final totalCarbs = foods.fold(0.0, (sum, f) => sum + f.totalCarbs);
    final totalFats = foods.fold(0.0, (sum, f) => sum + f.totalFats);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: textPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    mealType,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalCalories kcal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _MacroPill('P', '${totalProtein.toStringAsFixed(1)}g', textPrimary),
                  const SizedBox(width: 8),
                  _MacroPill('C', '${totalCarbs.toStringAsFixed(1)}g', textPrimary),
                  const SizedBox(width: 8),
                  _MacroPill('F', '${totalFats.toStringAsFixed(1)}g', textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (foods.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 48,
                      color: textPrimary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No foods added yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...foods.map((food) => _FoodListItem(
                    food: food,
                    onDelete: () => onFoodDeleted(food),
                    surface: surface,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  )),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onAddFood();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF19C37D), Color(0xFF0FA35F)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Add Food',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Add photo functionality
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: surface.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: textPrimary.withOpacity(0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: textPrimary.withOpacity(0.8),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Macro Pill
class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;

  const _MacroPill(this.label, this.value, this.textPrimary);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: textPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textPrimary.withOpacity(0.8),
        ),
      ),
    );
  }
}

// Food List Item
class _FoodListItem extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onDelete;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _FoodListItem({
    required this.food,
    required this.onDelete,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(food.name),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${food.quantity}x ${food.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniMacroPill('P', food.totalProtein, textPrimary, textSecondary),
                      const SizedBox(width: 6),
                      _MiniMacroPill('C', food.totalCarbs, textPrimary, textSecondary),
                      const SizedBox(width: 6),
                      _MiniMacroPill('F', food.totalFats, textPrimary, textSecondary),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${food.totalCalories}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'kcal',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
