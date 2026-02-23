import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'weekly_insights_page.dart';
import '../../theme/meal_tracker_tokens.dart';
import '../../repositories/meal_repository.dart';
import '../../repositories/food_catalog_repository.dart';

class MealTrackerPageV2 extends StatefulWidget {
  const MealTrackerPageV2({super.key});

  @override
  State<MealTrackerPageV2> createState() => _MealTrackerPageV2State();
}

class _MealTrackerPageV2State extends State<MealTrackerPageV2>
    with TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final MealRepository _mealRepo = MealRepository();
  final FoodCatalogRepository _foodCatalogRepo = FoodCatalogRepository();
  late AnimationController _fadeController;
  late AnimationController _ringController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _ringAnimation;

  late DateTime _selectedDate;
  late DateTime _weekStart; // Monday
  final Map<String, String?> _mealPhotoPath = {
    'Breakfast': null,
    'Lunch': null,
    'Dinner': null,
    'Snacks': null,
  };

  // Daily goals
  int goalCalories = 2000;
  int goalProtein = 150; // grams
  int goalCarbs = 200; // grams
  int goalFats = 65; // grams
  int goalFiber = 30; // grams

  // Current totals
  int calories = 1260;
  int protein = 92;
  int carbs = 140;
  int fats = 38;
  int fiber = 18;

  // Meal data
  final Map<String, List<FoodItem>> _meals = {
    'Breakfast': [],
    'Lunch': [],
    'Dinner': [],
    'Snacks': [],
  };
  List<String> _mealOrder = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
  ];

  // Recent foods for quick add (from catalog or manual)
  final List<FoodItem> _recentFoods = [];
  // Common foods: empty; catalog search replaces hardcoded list
  final List<FoodItem> _commonFoods = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
    _weekStart = _startOfWeek(_selectedDate);
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
    _loadGoals();
    _loadDayData();
  }

  Future<void> _loadGoals() async {
    final goals = await _mealRepo.getNutritionGoals();
    if (mounted) {
      setState(() {
        goalCalories = goals.goalCalories;
        goalProtein = goals.goalProtein;
        goalCarbs = goals.goalCarbs;
        goalFats = goals.goalFats;
        goalFiber = goals.goalFiber;
      });
    }
  }

  Future<void> _loadDayData() async {
    final data = await _mealRepo.getDayMeals(_selectedDate);
    if (!mounted) return;
    setState(() {
      const defaultOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
      final customFromData = data.mealsByType.keys
          .where((k) => !defaultOrder.contains(k))
          .toList();
      _mealOrder = [...defaultOrder, ...customFromData];
      _meals.clear();
      for (final k in _mealOrder) {
        _meals[k] = data.mealsByType[k]?.map(_foodItemFromRow).toList() ?? [];
      }
      calories = data.totalCalories;
      protein = data.totalProtein.round();
      carbs = data.totalCarbs.round();
      fats = data.totalFats.round();
      fiber = data.totalFiber.round();
    });
    _ringController.reset();
    _ringController.forward();
  }

  FoodItem _foodItemFromRow(MealItemRow row) {
    return FoodItem(
      id: row.id,
      name: row.foodName,
      calories: row.caloriesInt,
      protein: row.protein,
      carbs: row.carbs,
      fats: row.fats,
      fiber: row.fiber,
      unit: row.unit,
      amount: row.quantity,
    );
  }

  void _recomputeTotals() {
    int cals = 0;
    double p = 0, c = 0, f = 0, fi = 0;
    for (final meal in _meals.values) {
      for (final food in meal) {
        cals += food.totalCalories;
        p += food.totalProtein;
        c += food.totalCarbs;
        f += food.totalFats;
        fi += food.totalFiber;
      }
    }
    calories = cals;
    protein = p.round();
    carbs = c.round();
    fats = f.round();
    fiber = fi.round();
  }

  Future<void> _addCustomMeal() async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final textPrimary = _getTextPrimary(context);
        return AlertDialog(
          title: const Text('Add Meal'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'e.g. Pre-workout'),
            onSubmitted: (_) => Navigator.pop(context, controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textPrimary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('Add', style: TextStyle(color: textPrimary)),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;
    if (_meals.containsKey(trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal already exists')),
      );
      return;
    }
    setState(() {
      _meals[trimmed] = [];
      _mealPhotoPath[trimmed] = null;
      _mealOrder.add(trimmed);
    });
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ringController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getPageBg(BuildContext context) => MealTrackerTokens.pageBgOf(context);
  Color _getSurface(BuildContext context) => MealTrackerTokens.cardBgOf(context);
  Color _getTextPrimary(BuildContext context) =>
      MealTrackerTokens.textPrimaryOf(context);
  Color _getTextSecondary(BuildContext context) =>
      MealTrackerTokens.textSecondaryOf(context);

  LinearGradient get _primaryGradient => MealTrackerTokens.primaryGradient;

  LinearGradient _mealGradientFor(String mealType) {
    // Distinct colors per meal (still modern + consistent).
    switch (mealType) {
      case 'Breakfast':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFFDE68A)], // amber -> light amber
        );
      case 'Lunch':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14B8A6), Color(0xFF99F6E4)], // teal -> mint
        );
      case 'Dinner':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)], // violet -> lavender
        );
      case 'Snacks':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFB7185), Color(0xFFFDA4AF)], // rose -> light rose
        );
      default:
        // Custom meals: default to primary green gradient.
        return _primaryGradient;
    }
  }


  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    // DateTime.weekday: Mon=1..Sun=7
    return _dateOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));
  }

  List<DateTime> _weekDays() {
    return List.generate(7, (i) => _weekStart.add(Duration(days: i)));
  }

  void _selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = _dateOnly(date);
      _weekStart = _startOfWeek(_selectedDate);
    });
    _loadDayData();
  }

  Future<void> _openCalendar() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      builder: (context, child) {
        // Force green calendar styling for Meal Tracker.
        final base = Theme.of(context);
        final greenScheme = base.colorScheme.copyWith(
          primary: MealTrackerTokens.accent,
          secondary: MealTrackerTokens.accent2,
          surface: base.colorScheme.surface,
          onPrimary: Colors.white,
          onSurface: base.colorScheme.onSurface,
        );
        return Theme(
          data: base.copyWith(
            colorScheme: greenScheme,
            datePickerTheme: base.datePickerTheme.copyWith(
              backgroundColor: base.colorScheme.surface,
              headerBackgroundColor: MealTrackerTokens.accent,
              headerForegroundColor: Colors.white,
              dayForegroundColor:
                  WidgetStatePropertyAll(base.colorScheme.onSurface),
              // Ensure "today" stays readable when it's filled/selected (green bg).
              todayForegroundColor: const WidgetStatePropertyAll(Colors.white),
              todayBackgroundColor:
                  const WidgetStatePropertyAll(MealTrackerTokens.accent),
              todayBorder: const BorderSide(color: MealTrackerTokens.accent),
              dayOverlayColor: WidgetStatePropertyAll(
                MealTrackerTokens.accent.withValues(alpha: 0.12),
              ),
              yearOverlayColor: WidgetStatePropertyAll(
                MealTrackerTokens.accent.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!mounted || picked == null) return;
    _selectDate(picked);
  }

  Future<void> _openEditGoals() async {
    HapticFeedback.lightImpact();
    final calC = TextEditingController(text: goalCalories.toString());
    final pC = TextEditingController(text: goalProtein.toString());
    final cC = TextEditingController(text: goalCarbs.toString());
    final fC = TextEditingController(text: goalFats.toString());
    final fiC = TextEditingController(text: goalFiber.toString());

    int? parseInt(TextEditingController c) =>
        int.tryParse(c.text.trim().replaceAll(',', ''));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditGoalsSheet(
          caloriesController: calC,
          proteinController: pC,
          carbsController: cC,
          fatsController: fC,
          fiberController: fiC,
        );
      },
    );

    if (!mounted || saved != true) return;

    final nextCalories = parseInt(calC);
    final nextP = parseInt(pC);
    final nextC = parseInt(cC);
    final nextF = parseInt(fC);
    final nextFi = parseInt(fiC);

    if (nextCalories == null ||
        nextP == null ||
        nextC == null ||
        nextF == null ||
        nextFi == null ||
        nextCalories <= 0 ||
        nextP <= 0 ||
        nextC <= 0 ||
        nextF <= 0 ||
        nextFi <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid goal numbers')),
      );
      return;
    }

    try {
      await _mealRepo.upsertNutritionGoals(NutritionGoals(
        goalCalories: nextCalories,
        goalProtein: nextP,
        goalCarbs: nextC,
        goalFats: nextF,
        goalFiber: nextFi,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save goals: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      goalCalories = nextCalories;
      goalProtein = nextP;
      goalCarbs = nextC;
      goalFats = nextF;
      goalFiber = nextFi;
    });
    HapticFeedback.mediumImpact();
    _ringController
      ..reset()
      ..forward();
  }

  Future<void> _openAddFood({String? mealType}) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddFoodSheet(
        mealType: mealType,
        mealOptions: List<String>.from(_mealOrder),
        foodCatalogRepo: _foodCatalogRepo,
        onFoodAdded: (food, meal, {String? catalogFoodId}) async {
          try {
            await _mealRepo.addFoodItem(
              date: _selectedDate,
              mealType: meal,
              foodName: food.name,
              quantity: food.amount,
              unit: food.unit,
              calories: food.calories,
              protein: food.protein,
              carbs: food.carbs,
              fats: food.fats,
              fiber: food.fiber,
              foodId: catalogFoodId,
            );
            if (!mounted) return;
            final data = await _mealRepo.getDayMeals(_selectedDate);
            if (!mounted) return;
            setState(() {
              const defaultOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
              final customFromData = data.mealsByType.keys
                  .where((k) => !defaultOrder.contains(k))
                  .toList();
              _mealOrder = [...defaultOrder, ...customFromData];
              _meals.clear();
              for (final k in _mealOrder) {
                _meals[k] = data.mealsByType[k]?.map(_foodItemFromRow).toList() ?? [];
              }
              _recomputeTotals();
              if (!_recentFoods.any((f) => f.name == food.name)) {
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
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add: $e')),
              );
            }
          }
        },
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
        onFoodDeleted: (food) async {
          if (food.id == null) {
            setState(() {
              _meals[mealType]!.remove(food);
              _recomputeTotals();
            });
          } else {
            try {
              await _mealRepo.deleteFoodItem(food.id!);
              if (!mounted) return;
              setState(() {
                _meals[mealType]!.remove(food);
                _recomputeTotals();
              });
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
                );
              }
              return;
            }
          }
          _ringController.reset();
          _ringController.forward();
          HapticFeedback.mediumImpact();
        },
        onFoodUpdated: (oldFood, updated) async {
          if (oldFood.id == null) {
            setState(() {
              final idx = _meals[mealType]!.indexOf(oldFood);
              if (idx >= 0) _meals[mealType]![idx] = updated;
              _recomputeTotals();
            });
          } else {
            try {
              await _mealRepo.updateFoodItemAmount(oldFood.id!, updated.amount);
              if (!mounted) return;
              setState(() {
                final idx = _meals[mealType]!.indexOf(oldFood);
                if (idx >= 0) _meals[mealType]![idx] = updated.copyWith(id: oldFood.id);
                _recomputeTotals();
              });
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update: $e')),
                );
              }
              return;
            }
          }
          _ringController.reset();
          _ringController.forward();
          HapticFeedback.selectionClick();
        },
        onAddFood: () => _openAddFood(mealType: mealType),
      ),
    );
  }

  Future<void> _openWeeklyInsights() async {
    HapticFeedback.selectionClick();
    final weekEnd = _weekStart.add(const Duration(days: 6));
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WeeklyInsightsPage(
              gradient: _primaryGradient,
              selectedDate: _selectedDate,
              goalCalories: goalCalories,
              goalProtein: goalProtein,
              goalCarbs: goalCarbs,
              goalFats: goalFats,
              mealRepository: _mealRepo,
              weekEndDate: weekEnd,
              commonFoods: _commonFoods
                  .map(
                    (f) => WeeklyFood(
                      name: f.name,
                      calories: f.calories,
                      protein: f.protein,
                      carbs: f.carbs,
                      fats: f.fats,
                      unit: f.unit,
                    ),
                  )
                  .toList(growable: false),
              recentFoods: _recentFoods
                  .map(
                    (f) => WeeklyFood(
                      name: f.name,
                      calories: f.calories,
                      protein: f.protein,
                      carbs: f.carbs,
                      fats: f.fats,
                      unit: f.unit,
                    ),
                  )
                  .toList(growable: false),
            ),
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
      backgroundColor: pageBg,
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                color: MealTrackerTokens.darkBackground,
              )
            : null,
        child: SafeArea(
          bottom: true,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _MealTrackerHeaderDelegate(
                    onCalendar: _openCalendar,
                    title: 'Meal Tracker',
                    textPrimary: _getTextPrimary(context),
                    bgColor: pageBg,
                  ),
                ),
                // Day Strip
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DayStripDelegate(
                    days: _weekDays(),
                    selectedDate: _selectedDate,
                    onDaySelected: _selectDate,
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
                      fiber: fiber,
                      goalFiber: goalFiber,
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
                      onEditGoals: _openEditGoals,
                      selectedDate: _selectedDate,
                    ),
                  ),
                ),
                // Meals (touch-hold to reorder)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverReorderableList(
                    itemCount: _mealOrder.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _mealOrder.removeAt(oldIndex);
                        _mealOrder.insert(newIndex, item);
                      });
                      HapticFeedback.selectionClick();
                    },
                    itemBuilder: (context, index) {
                      final mealType = _mealOrder[index];
                      final foods = _meals[mealType] ?? const <FoodItem>[];
                      final mealCalories =
                          foods.fold(0, (sum, f) => sum + f.totalCalories);
                      final mealProtein =
                          foods.fold(0.0, (sum, f) => sum + f.totalProtein);
                      final mealCarbs =
                          foods.fold(0.0, (sum, f) => sum + f.totalCarbs);
                      final mealFats =
                          foods.fold(0.0, (sum, f) => sum + f.totalFats);
                      final icon = switch (mealType) {
                        'Breakfast' => Icons.breakfast_dining_rounded,
                        'Lunch' => Icons.lunch_dining_rounded,
                        'Dinner' => Icons.dinner_dining_rounded,
                        'Snacks' => Icons.cookie_rounded,
                        _ => Icons.restaurant_rounded,
                      };
                      return Padding(
                        key: ValueKey('meal-$mealType'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: _MealTile(
                            mealType: mealType,
                            icon: icon,
                            itemCount: foods.length,
                            calories: mealCalories,
                            protein: mealProtein,
                            carbs: mealCarbs,
                            fats: mealFats,
                            gradient: _mealGradientFor(mealType),
                            surface: _getSurface(context),
                            textPrimary: _getTextPrimary(context),
                            textSecondary: _getTextSecondary(context),
                            photoPath: _mealPhotoPath[mealType],
                            onTap: () => _openMealDetail(mealType),
                            onAddFood: () => _openAddFood(mealType: mealType),
                            onAddPhoto: () async {
                              final image = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (image != null && mounted) {
                                setState(() => _mealPhotoPath[mealType] = image.path);
                                HapticFeedback.mediumImpact();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                  sliver: SliverToBoxAdapter(
                    child: _AddMealTile(
                      onTap: _addCustomMeal,
                      surface: _getSurface(context),
                      textPrimary: _getTextPrimary(context),
                      textSecondary: _getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Floating add button removed (meals tiles already provide Add actions).
    );
  }
}

// Food Item Model
class FoodItem {
  /// DB meal_item id when loaded from Supabase; null for in-memory/common foods.
  final String? id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fats;
  final double fiber;
  final String unit;
  /// Amount of this food consumed.
  /// - If [unit] encodes grams (e.g. "100g"), this is **grams**.
  /// - Otherwise this is a **multiplier** of the base unit (e.g. "1 medium").
  final double amount;

  FoodItem({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.fiber = 0,
    required this.unit,
    double? amount,
  }) : amount = amount ?? _defaultAmountForUnit(unit);

  static double _defaultAmountForUnit(String unit) {
    final base = _baseGramsFromUnit(unit);
    return base?.toDouble() ?? 1.0;
  }

  /// Matches "100g", "50 g" etc. Returns base grams or null for serving units ("1 medium", "1x").
  static int? _baseGramsFromUnit(String unit) {
    final m = RegExp(r'(\d+)\s*g', caseSensitive: false).firstMatch(unit);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  int? get baseGrams => _baseGramsFromUnit(unit);

  double get factor {
    final base = baseGrams;
    if (base == null) return amount;
    return amount / base;
  }

  FoodItem copyWith({
    String? id,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? fiber,
    String? unit,
    double? amount,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      fiber: fiber ?? this.fiber,
      unit: unit ?? this.unit,
      amount: amount ?? this.amount,
    );
  }

  // Calculate totals based on factor
  int get totalCalories => (calories * factor).round();
  double get totalProtein => protein * factor;
  double get totalCarbs => carbs * factor;
  double get totalFats => fats * factor;
  double get totalFiber => fiber * factor;
}

class _MealTrackerHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onCalendar;
  final String title;
  final Color textPrimary;
  final Color bgColor;

  _MealTrackerHeaderDelegate({
    required this.onCalendar,
    required this.title,
    required this.textPrimary,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final denom = (maxExtent - minExtent);
    final t = denom == 0
        ? (overlapsContent ? 1.0 : 0.0)
        : (shrinkOffset / denom).clamp(0.0, 1.0);
    // No glass/blur: just become slightly elevated on scroll.
    final bgAlpha = _lerpDouble(1.0, 1.0, t);
    final slideUp = _lerpDouble(6.0, 0.0, t);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: bgAlpha),
              boxShadow: t > 0.05
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: textPrimary.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: maxExtent,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                  ),
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, -slideUp),
                        child: Opacity(
                          opacity: (0.45 + (1 - t) * 0.55).clamp(0.0, 1.0),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCalendar,
                    icon: const Icon(
                      Icons.calendar_month_rounded,
                      color: MealTrackerTokens.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  double get maxExtent => 72;

  @override
  double get minExtent => 72;

  @override
  bool shouldRebuild(covariant _MealTrackerHeaderDelegate oldDelegate) {
    return oldDelegate.textPrimary != textPrimary ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.title != title;
  }
}

// Day Strip Delegate
class _DayStripDelegate extends SliverPersistentHeaderDelegate {
  final List<DateTime> days;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;
  final LinearGradient primaryGradient;
  final Color surface;
  final Color textPrimary;

  _DayStripDelegate({
    required this.days,
    required this.selectedDate,
    required this.onDaySelected,
    required this.primaryGradient,
    required this.surface,
    required this.textPrimary,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // IMPORTANT: force the header child to fill the sliver extent.
    // Otherwise the child may measure slightly smaller and cause:
    // "layoutExtent exceeds paintExtent" for pinned persistent headers.
    return SizedBox.expand(
      child: Container(
        color: surface,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(days.length, (index) {
              final day = days[index];
              final isSelected = day.year == selectedDate.year &&
                  day.month == selectedDate.month &&
                  day.day == selectedDate.day;
              final now = DateTime.now();
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onDaySelected(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected ? primaryGradient : null,
                      color: isSelected ? null : surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: MealTrackerTokens.accent
                                    .withValues(alpha: 0.18),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : textPrimary.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
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
                        const SizedBox(height: 1),
                        Text(
                          _getMonthShort(day.month),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.90)
                                : textPrimary.withValues(alpha: 0.55),
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
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthShort(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return m[month - 1];
  }

  @override
  double get maxExtent => 92;

  @override
  double get minExtent => 92;

  @override
  bool shouldRebuild(covariant _DayStripDelegate oldDelegate) {
    return oldDelegate.selectedDate != selectedDate || oldDelegate.days != days;
  }
}

// Daily Summary Card
class _DailySummaryCard extends StatelessWidget {
  final int calories;
  final int goalCalories;
  final int fiber;
  final int goalFiber;
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
  final VoidCallback onEditGoals;
  final DateTime selectedDate;

  const _DailySummaryCard({
    required this.calories,
    required this.goalCalories,
    required this.fiber,
    required this.goalFiber,
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
    required this.onEditGoals,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final intakeLabel = _isToday(selectedDate) ? 'Today\'s Intake' : 'Intake';
    final pProgress = goalProtein > 0 ? (protein / goalProtein).clamp(0.0, 1.0) : 0.0;
    final cProgress = goalCarbs > 0 ? (carbs / goalCarbs).clamp(0.0, 1.0) : 0.0;
    final fProgress = goalFats > 0 ? (fats / goalFats).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onInsightsTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(MealTrackerTokens.radiusCard),
          boxShadow: MealTrackerTokens.cardShadowOf(context),
          border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Top row: Today's intake + Rings
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  intakeLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: MealTrackerTokens.accent2,
                                  ),
                                ),
                              ),
                              _PressScale(
                                onTap: onEditGoals,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: MealTrackerTokens.accent
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: MealTrackerTokens.accent
                                          .withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded,
                                          size: 14,
                                          color: MealTrackerTokens.accent2),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Goals',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: MealTrackerTokens.accent2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _AnimatedIntText(
                                value: calories,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: MealTrackerTokens.accent, // green
                                ),
                                duration: const Duration(milliseconds: 450),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '/$goalCalories',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: MealTrackerTokens.accent2,
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
                                textPrimary: MealTrackerTokens.accent2,
                                dotColor: MealTrackerTokens.macroProtein,
                              ),
                              _MacroChip(
                                label: 'C',
                                value: '${carbs}g',
                                goal: goalCarbs,
                                gradient: primaryGradient,
                                surface: surface,
                                textPrimary: MealTrackerTokens.accent2,
                                dotColor: MealTrackerTokens.macroCarbs,
                              ),
                              _MacroChip(
                                label: 'F',
                                value: '${fats}g',
                                goal: goalFats,
                                gradient: primaryGradient,
                                surface: surface,
                                textPrimary: MealTrackerTokens.accent2,
                                dotColor: MealTrackerTokens.macroFats,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _TripleRingProgress(
                      proteinProgress: pProgress,
                      carbsProgress: cProgress,
                      fatsProgress: fProgress,
                      textPrimary: MealTrackerTokens.accent2,
                      textSecondary: MealTrackerTokens.accent2.withValues(alpha: 0.70),
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
                      color: MealTrackerTokens.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: MealTrackerTokens.accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 18,
                          color: MealTrackerTokens.accent2,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Weekly Insights',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MealTrackerTokens.accent2,
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

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

class _TripleRingProgress extends StatelessWidget {
  final double proteinProgress;
  final double carbsProgress;
  final double fatsProgress;
  final Color textPrimary;
  final Color textSecondary;
  final Animation<double> animation;

  const _TripleRingProgress({
    required this.proteinProgress,
    required this.carbsProgress,
    required this.fatsProgress,
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
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(90, 90),
                painter: _RingPainter(
                  progress: fatsProgress * animation.value,
                  strokeWidth: 6,
                  startAngle: -pi / 2,
                  color: MealTrackerTokens.macroFats,
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(90, 90),
                painter: _RingPainter(
                  progress: carbsProgress * animation.value,
                  strokeWidth: 6,
                  startAngle: -pi / 2,
                  color: MealTrackerTokens.macroCarbs,
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(90, 90),
                painter: _RingPainter(
                  progress: proteinProgress * animation.value,
                  strokeWidth: 6,
                  startAngle: -pi / 2,
                  color: MealTrackerTokens.macroProtein,
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final avgProgress =
                        (proteinProgress + carbsProgress + fatsProgress) / 3;
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

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFE5E7EB) // light gray
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.color != color;
  }
}

// calories/fiber ring removed (reverted to macro triple ring)

// Macro Chip
class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final int goal;
  final LinearGradient gradient;
  final Color surface;
  final Color textPrimary;
  final Color? dotColor;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.goal,
    required this.gradient,
    required this.surface,
    required this.textPrimary,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor ?? Colors.white,
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

class _AnimatedIntText extends StatefulWidget {
  final int value;
  final TextStyle style;
  final Duration duration;

  const _AnimatedIntText({
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 350),
  });

  @override
  State<_AnimatedIntText> createState() => _AnimatedIntTextState();
}

class _AnimatedIntTextState extends State<_AnimatedIntText> {
  late int _from;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AnimatedIntText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from.toDouble(), end: widget.value.toDouble()),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(v.round().toString(), style: widget.style);
      },
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
  final String? photoPath;

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
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(MealTrackerTokens.radiusCard),
          boxShadow: MealTrackerTokens.cardShadowOf(context),
          border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MealTrackerTokens.radiusCard),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top accent strip (same green gradient)
              Container(height: 6, decoration: BoxDecoration(gradient: gradient)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(icon, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      mealType,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: MealTrackerTokens.accent
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: MealTrackerTokens.accent
                                            .withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Text(
                                      '$calories kcal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: MealTrackerTokens.accent2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MiniMacroPill(
                                    'P',
                                    protein,
                                    MealTrackerTokens.macroProtein,
                                    textSecondary,
                                  ),
                                  _MiniMacroPill(
                                    'C',
                                    carbs,
                                    MealTrackerTokens.macroCarbs,
                                    textSecondary,
                                  ),
                                  _MiniMacroPill(
                                    'F',
                                    fats,
                                    MealTrackerTokens.macroFats,
                                    textSecondary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (photoPath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(photoPath!),
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: textPrimary.withOpacity(0.08),
                              ),
                            ),
                            child: Icon(
                              Icons.photo_outlined,
                              color: textPrimary.withOpacity(0.45),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _PressScale(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onAddFood();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: gradient,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: MealTrackerTokens.accent
                                        .withValues(alpha: 0.18),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add Food',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _PressScale(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onAddPhoto();
                          },
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white),
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
      ),
    );
  }
}

class _AddMealTile extends StatelessWidget {
  final VoidCallback onTap;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _AddMealTile({
    required this.onTap,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(MealTrackerTokens.radiusCard),
          border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: MealTrackerTokens.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Meal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Custom tile • Long-press meals to reorder',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: textPrimary.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}

class _EditGoalsSheet extends StatelessWidget {
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatsController;
  final TextEditingController fiberController;

  const _EditGoalsSheet({
    required this.caloriesController,
    required this.proteinController,
    required this.carbsController,
    required this.fatsController,
    required this.fiberController,
  });

  @override
  Widget build(BuildContext context) {
    final surface = MealTrackerTokens.cardBgOf(context);
    final textPrimary = MealTrackerTokens.textPrimaryOf(context);
    final textSecondary = MealTrackerTokens.textSecondaryOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MealTrackerTokens.radiusSheet),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, -12),
            ),
          ],
          border: Border.all(color: MealTrackerTokens.accent.withOpacity(0.10)),
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
                  color: textPrimary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: MealTrackerTokens.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Goals',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Set your daily targets',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: Icon(Icons.close_rounded, color: textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      _GreenGoalField(
                        label: 'Calories',
                        suffix: 'kcal',
                        icon: Icons.local_fire_department_rounded,
                        controller: caloriesController,
                      ),
                      const SizedBox(height: 12),
                      _GreenGoalField(
                        label: 'Protein',
                        suffix: 'g',
                        icon: Icons.fitness_center_rounded,
                        controller: proteinController,
                      ),
                      const SizedBox(height: 12),
                      _GreenGoalField(
                        label: 'Carbs',
                        suffix: 'g',
                        icon: Icons.grain_rounded,
                        controller: carbsController,
                      ),
                      const SizedBox(height: 12),
                      _GreenGoalField(
                        label: 'Fat',
                        suffix: 'g',
                        icon: Icons.water_drop_rounded,
                        controller: fatsController,
                      ),
                      const SizedBox(height: 12),
                      _GreenGoalField(
                        label: 'Fiber',
                        suffix: 'g',
                        icon: Icons.eco_rounded,
                        controller: fiberController,
                      ),
                      const SizedBox(height: 16),
                      _PressScale(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: MealTrackerTokens.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: MealTrackerTokens.accent
                                    .withValues(alpha: 0.28),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Save Goals',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tip: long‑press a food in a meal to edit its amount.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreenGoalField extends StatelessWidget {
  final String label;
  final String suffix;
  final IconData icon;
  final TextEditingController controller;

  const _GreenGoalField({
    required this.label,
    required this.suffix,
    required this.icon,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final surface = MealTrackerTokens.cardBgOf(context);
    final textPrimary = MealTrackerTokens.textPrimaryOf(context);
    final textSecondary = MealTrackerTokens.textSecondaryOf(context);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(icon, color: MealTrackerTokens.accent2),
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: MealTrackerTokens.accent.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: MealTrackerTokens.accent,
            width: 2,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: TextStyle(
          color: MealTrackerTokens.accent2,
          fontWeight: FontWeight.w900,
        ),
      ),
      style: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

// Mini Macro Pill
class _MiniMacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color chipColor;
  final Color textSecondary;

  const _MiniMacroPill(
    this.label,
    this.value,
    this.chipColor,
    this.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
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

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  double _scale = 1.0;

  void _down() => setState(() => _scale = 0.97);
  void _up() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// (Quick Add FAB removed)

// Add Food Sheet (catalog-backed)
class _AddFoodSheet extends StatefulWidget {
  final String? mealType;
  final List<String> mealOptions;
  final Future<void> Function(FoodItem food, String meal, {String? catalogFoodId}) onFoodAdded;
  final FoodCatalogRepository foodCatalogRepo;
  final List<FoodItem> recentFoods;

  const _AddFoodSheet({
    this.mealType,
    required this.mealOptions,
    required this.onFoodAdded,
    required this.foodCatalogRepo,
    required this.recentFoods,
  });

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  int _step = 0; // 0 = search, 1 = details (grams + portions + macro preview)
  CatalogFood? _selectedCatalogFood;
  double _grams = 100;
  String _selectedMeal = 'Breakfast';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController(text: '100');
  List<CatalogFood> _searchResults = [];
  List<FoodPortion> _portions = [];
  bool _searching = false;
  bool _saving = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.mealType ?? (widget.mealOptions.isNotEmpty ? widget.mealOptions.first : 'Breakfast');
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final q = _searchController.text.trim();
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await widget.foodCatalogRepo.searchFoods(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  void _selectFood(CatalogFood food) async {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCatalogFood = food;
      _grams = 100;
      _gramsController.text = '100';
      _step = 1;
      _portions = [];
    });
    final portions = await widget.foodCatalogRepo.getFoodPortions(food.id);
    if (!mounted) return;
    setState(() {
      _portions = portions;
      final defaultPortion = portions.where((p) => p.isDefault).firstOrNull;
      if (defaultPortion != null) {
        _grams = defaultPortion.grams;
        _gramsController.text = _grams == _grams.roundToDouble()
            ? _grams.round().toString()
            : _grams.toStringAsFixed(1);
      }
    });
  }

  Future<void> _addFood() async {
    final food = _selectedCatalogFood;
    if (food == null || _saving) return;
    if (_grams <= 0) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final foodItem = FoodItem(
      id: null,
      name: food.name,
      calories: food.kcal100g.round(),
      protein: food.protein100g,
      carbs: food.carbs100g,
      fats: food.fat100g,
      fiber: food.fiber100g,
      unit: '100g',
      amount: _grams,
    );
    try {
      await widget.onFoodAdded(foodItem, _selectedMeal, catalogFoodId: food.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = MealTrackerTokens.cardBgOf(context);
    final textPrimary = MealTrackerTokens.textPrimaryOf(context);
    final textSecondary = MealTrackerTokens.textSecondaryOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MealTrackerTokens.radiusSheet),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(MealTrackerTokens.radiusSheet),
                ),
                border: Border.all(
                  color: textPrimary.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      height: 4,
                      width: 44,
                      decoration: BoxDecoration(
                        color: textPrimary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _step == 0
                          ? _AddFoodHeader(
                              key: const ValueKey('list'),
                              title: 'Add Food',
                              onClose: () => Navigator.pop(context),
                              textPrimary: textPrimary,
                            )
                          : _AddFoodHeader(
                              key: const ValueKey('details'),
                              title: _selectedCatalogFood?.name ?? 'Food Details',
                              onClose: () => setState(() => _step = 0),
                              textPrimary: textPrimary,
                              leadingIcon: Icons.arrow_back_rounded,
                            ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _step == 0
                          ? _CatalogSearchStep(
                              controller: scrollController,
                              searchController: _searchController,
                              searchResults: _searchResults,
                              searching: _searching,
                              recentFoods: widget.recentFoods,
                              onSelectCatalog: _selectFood,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              surface: surface,
                            )
                          : _CatalogDetailsStep(
                              controller: scrollController,
                              food: _selectedCatalogFood!,
                              grams: _grams,
                              gramsController: _gramsController,
                              portions: _portions,
                              onGramsChanged: (v) {
                                setState(() => _grams = v);
                                _gramsController.text = v == v.roundToDouble()
                                    ? v.round().toString()
                                    : v.toStringAsFixed(1);
                              },
                              mealOptions: widget.mealOptions,
                              selectedMeal: _selectedMeal,
                              onMealChanged: (m) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedMeal = m);
                              },
                              onAdd: _addFood,
                              saving: _saving,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              surface: surface,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddFoodHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Color textPrimary;
  final IconData leadingIcon;

  const _AddFoodHeader({
    super.key,
    required this.title,
    required this.onClose,
    required this.textPrimary,
    this.leadingIcon = Icons.close_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(leadingIcon, color: textPrimary),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _CatalogSearchStep extends StatelessWidget {
  final ScrollController controller;
  final TextEditingController searchController;
  final List<CatalogFood> searchResults;
  final bool searching;
  final List<FoodItem> recentFoods;
  final ValueChanged<CatalogFood> onSelectCatalog;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;

  const _CatalogSearchStep({
    required this.controller,
    required this.searchController,
    required this.searchResults,
    required this.searching,
    required this.recentFoods,
    required this.onSelectCatalog,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search foods',
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
          ),
        ),
        const SizedBox(height: 14),
        if (recentFoods.isNotEmpty) ...[
          Text(
            'Recent',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentFoods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final food = recentFoods[i];
                return _PressScale(
                  onTap: () {
                    searchController.text = food.name;
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
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
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Results',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (searching)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Center(
              child: Text(
                searchController.text.trim().isEmpty
                    ? 'Search to find foods'
                    : 'No results',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ),
          )
        else
          ...searchResults.map((food) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PressScale(
                onTap: () => onSelectCatalog(food),
                child: _CatalogFoodCard(
                  food: food,
                  surface: surface,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _CatalogFoodCard extends StatelessWidget {
  final CatalogFood food;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _CatalogFoodCard({
    required this.food,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: MealTrackerTokens.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                food.name.isNotEmpty ? food.name[0].toUpperCase() : 'F',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        food.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (food.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MealTrackerTokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: MealTrackerTokens.accent.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${food.kcal100g.round()} kcal / 100g',
                  style: TextStyle(
                    fontSize: 12,
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

class _CatalogDetailsStep extends StatelessWidget {
  final ScrollController controller;
  final CatalogFood food;
  final double grams;
  final TextEditingController gramsController;
  final List<FoodPortion> portions;
  final ValueChanged<double> onGramsChanged;
  final List<String> mealOptions;
  final String selectedMeal;
  final ValueChanged<String> onMealChanged;
  final VoidCallback onAdd;
  final bool saving;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;

  const _CatalogDetailsStep({
    required this.controller,
    required this.food,
    required this.grams,
    required this.gramsController,
    required this.portions,
    required this.onGramsChanged,
    required this.mealOptions,
    required this.selectedMeal,
    required this.onMealChanged,
    required this.onAdd,
    required this.saving,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final m = food.macrosForGrams(grams);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      children: [
        Text(
          'Amount (grams)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Grams',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${grams.round()} g',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PressScale(
                    onTap: () => onGramsChanged((grams - 5).clamp(5.0, 2000.0)),
                    child: _CircleIcon(
                      icon: Icons.remove_rounded,
                      surface: surface,
                      textPrimary: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: gramsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'e.g. 175',
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixText: 'g',
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v.replaceAll(',', '.'));
                        if (parsed != null && parsed > 0) onGramsChanged(parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PressScale(
                    onTap: () => onGramsChanged((grams + 5).clamp(5.0, 2000.0)),
                    child: _CircleIcon(
                      icon: Icons.add_rounded,
                      surface: surface,
                      textPrimary: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickServingChip(
                    label: '50g',
                    onTap: () => onGramsChanged(50),
                    surface: surface,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(width: 8),
                  _QuickServingChip(
                    label: '100g',
                    onTap: () => onGramsChanged(100),
                    surface: surface,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(width: 8),
                  _QuickServingChip(
                    label: '150g',
                    onTap: () => onGramsChanged(150),
                    surface: surface,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(width: 8),
                  _QuickServingChip(
                    label: '200g',
                    onTap: () => onGramsChanged(200),
                    surface: surface,
                    textPrimary: textPrimary,
                  ),
                ],
              ),
              if (portions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: portions.map((p) => _QuickServingChip(
                    label: p.label,
                    onTap: () => onGramsChanged(p.grams),
                    surface: surface,
                    textPrimary: textPrimary,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Macros (preview)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: textPrimary.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroStat(label: 'Calories', value: '${m.calories}', color: textPrimary),
              _MacroStat(
                label: 'P',
                value: '${m.protein.toStringAsFixed(1)}g',
                color: MealTrackerTokens.macroProtein,
              ),
              _MacroStat(
                label: 'C',
                value: '${m.carbs.toStringAsFixed(1)}g',
                color: MealTrackerTokens.macroCarbs,
              ),
              _MacroStat(
                label: 'F',
                value: '${m.fats.toStringAsFixed(1)}g',
                color: MealTrackerTokens.macroFats,
              ),
              _MacroStat(
                label: 'Fi',
                value: '${m.fiber.toStringAsFixed(1)}g',
                color: MealTrackerTokens.accent2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Meal',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: mealOptions.map((meal) {
            final selected = meal == selectedMeal;
            return _PressScale(
              onTap: () => onMealChanged(meal),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? MealTrackerTokens.primaryGradient : null,
                  color: selected ? null : surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: textPrimary.withOpacity(0.08)),
                ),
                child: Text(
                  meal,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: saving,
          child: _PressScale(
            onTap: onAdd,
            child: Opacity(
              opacity: saving ? 0.6 : 1,
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: MealTrackerTokens.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: MealTrackerTokens.accent.withValues(alpha: 0.30),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: saving
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      'Add to $selectedMeal',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color surface;
  final Color textPrimary;

  const _CircleIcon({
    required this.icon,
    required this.surface,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: surface,
        shape: BoxShape.circle,
        border: Border.all(color: textPrimary.withOpacity(0.08)),
      ),
      child: Icon(icon, color: textPrimary.withOpacity(0.9)),
    );
  }
}

class _QuickServingChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color surface;
  final Color textPrimary;

  const _QuickServingChip({
    required this.label,
    required this.onTap,
    required this.surface,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: textPrimary.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color.withOpacity(0.7),
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
  final void Function(FoodItem oldFood, FoodItem updatedFood) onFoodUpdated;
  final VoidCallback onAddFood;

  const _MealDetailSheet({
    required this.mealType,
    required this.foods,
    required this.onFoodDeleted,
    required this.onFoodUpdated,
    required this.onAddFood,
  });

  @override
  Widget build(BuildContext context) {
    final surface = MealTrackerTokens.cardBgOf(context);
    final textPrimary = MealTrackerTokens.textPrimaryOf(context);
    final textSecondary = MealTrackerTokens.textSecondaryOf(context);

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
                    onUpdate: (updated) => onFoodUpdated(food, updated),
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
                        color: surface,
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
  final ValueChanged<FoodItem> onUpdate;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _FoodListItem({
    required this.food,
    required this.onDelete,
    required this.onUpdate,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  Future<void> _editAmount(BuildContext context) async {
    HapticFeedback.lightImpact();
    final isGramBased = food.baseGrams != null;
    final controller = TextEditingController(
      text: isGramBased ? food.amount.round().toString() : food.amount.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isGramBased ? 'Edit grams' : 'Edit quantity'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: isGramBased ? 'e.g. 175' : 'e.g. 1.5',
              suffixText: isGramBased ? 'g' : '×',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
                if (v == null) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context, v);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    final clamped = result < 0 ? 0.0 : result;
    HapticFeedback.selectionClick();
    onUpdate(food.copyWith(amount: clamped));
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(food.id ?? '${food.name}_${food.amount}_${food.totalCalories}'),
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
      child: GestureDetector(
        onLongPress: () => _editAmount(context),
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
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
                      food.baseGrams != null
                          ? '${food.amount.round()} g • ${food.unit}'
                          : '${food.amount.toStringAsFixed(2)}× ${food.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MiniMacroPill(
                          'P',
                          food.totalProtein,
                          MealTrackerTokens.macroProtein,
                          textSecondary,
                        ),
                        const SizedBox(width: 6),
                        _MiniMacroPill(
                          'C',
                          food.totalCarbs,
                          MealTrackerTokens.macroCarbs,
                          textSecondary,
                        ),
                        const SizedBox(width: 6),
                        _MiniMacroPill(
                          'F',
                          food.totalFats,
                          MealTrackerTokens.macroFats,
                          textSecondary,
                        ),
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
      ),
    );
  }
}
