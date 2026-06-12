import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Legacy route — nutritionists use [HomeShellPage] at `/home` (Messages + Meals in nav).
class NutritionistDashboardPage extends StatefulWidget {
  const NutritionistDashboardPage({super.key});

  @override
  State<NutritionistDashboardPage> createState() => _NutritionistDashboardPageState();
}

class _NutritionistDashboardPageState extends State<NutritionistDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
