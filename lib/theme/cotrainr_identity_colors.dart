import 'package:flutter/material.dart';

import '../core/auth/user_role.dart';
import '../models/subscription_plans.dart';

/// Locked Cotrainr identity colours for Member Pass + Subscription.
///
/// Client plans: Free / Basic / Ultimate.
/// Provider roles: Trainer / Nutritionist (never shown as subscription tiers).
abstract final class CotrainrIdentityColors {
  // —— Client Free (Graphite / Silver) ——
  static const freeStart = Color(0xFF555B63);
  static const freeEnd = Color(0xFF8A9098);
  static const freeWatermark = Color(0xFF3A3F45);

  // —— Client Basic (Cotrainr Orange) ——
  static const basicStart = Color(0xFFF65A00);
  static const basicEnd = Color(0xFFFF9D24);
  static const basicWatermark = Color(0xFFB33F00);

  // —— Client Ultimate (Premium Black + Gold) ——
  static const ultimateStart = Color(0xFF0D0D0F);
  static const ultimateEnd = Color(0xFF252529);
  static const ultimateGold = Color(0xFFD9AD4A);
  static const ultimateWatermark = Color(0xFF080809);

  // —— Trainer (Deep Burgundy) ——
  static const trainerStart = Color(0xFF54152D);
  static const trainerEnd = Color(0xFFA62C5A);
  static const trainerAccent = Color(0xFFF08AAF);
  static const trainerWatermark = Color(0xFF3A0D20);

  // —— Nutritionist (Deep Emerald) ——
  static const nutritionistStart = Color(0xFF087A55);
  static const nutritionistEnd = Color(0xFF18A875);
  static const nutritionistAccent = Color(0xFF6FE0B3);
  static const nutritionistWatermark = Color(0xFF04553A);

  /// Semantic status colours — never replaced by Pass identity.
  static const availableGreen = Color(0xFF0FA35F);
  static const availableGreenBg = Color(0xFF19C37D);
  static const errorRed = Color(0xFFC62828);
}

/// Resolved Pass / page identity for the current user.
class PassIdentity {
  final String id;
  final LinearGradient cardGradient;
  final Color accent;
  final Color watermark;
  final Color primaryText;
  final Color secondaryText;
  /// Optional gold (or similar) for selective Ultimate treatments.
  final Color? highlight;

  const PassIdentity({
    required this.id,
    required this.cardGradient,
    required this.accent,
    required this.watermark,
    this.primaryText = Colors.white,
    this.secondaryText = const Color(0xBFFFFFFF), // ~75% white
    this.highlight,
  });

  static const free = PassIdentity(
    id: 'free',
    cardGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        CotrainrIdentityColors.freeStart,
        CotrainrIdentityColors.freeEnd,
      ],
    ),
    accent: CotrainrIdentityColors.freeEnd,
    watermark: CotrainrIdentityColors.freeWatermark,
  );

  static const basic = PassIdentity(
    id: 'basic',
    cardGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        CotrainrIdentityColors.basicStart,
        CotrainrIdentityColors.basicEnd,
      ],
    ),
    accent: CotrainrIdentityColors.basicStart,
    watermark: CotrainrIdentityColors.basicWatermark,
  );

  static const ultimate = PassIdentity(
    id: 'ultimate',
    cardGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        CotrainrIdentityColors.ultimateStart,
        CotrainrIdentityColors.ultimateEnd,
      ],
    ),
    accent: CotrainrIdentityColors.ultimateGold,
    watermark: CotrainrIdentityColors.ultimateWatermark,
    highlight: CotrainrIdentityColors.ultimateGold,
  );

  static const trainer = PassIdentity(
    id: 'trainer',
    cardGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        CotrainrIdentityColors.trainerStart,
        CotrainrIdentityColors.trainerEnd,
      ],
    ),
    accent: CotrainrIdentityColors.trainerAccent,
    watermark: CotrainrIdentityColors.trainerWatermark,
  );

  static const nutritionist = PassIdentity(
    id: 'nutritionist',
    cardGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        CotrainrIdentityColors.nutritionistStart,
        CotrainrIdentityColors.nutritionistEnd,
      ],
    ),
    accent: CotrainrIdentityColors.nutritionistAccent,
    watermark: CotrainrIdentityColors.nutritionistWatermark,
  );

  /// CTA fill: strong enough for white (or dark) label contrast.
  Color get ctaBackground {
    switch (id) {
      case 'free':
        return CotrainrIdentityColors.freeStart;
      case 'basic':
        return CotrainrIdentityColors.basicStart;
      case 'ultimate':
        return CotrainrIdentityColors.ultimateGold;
      case 'trainer':
        return CotrainrIdentityColors.trainerStart;
      case 'nutritionist':
        return CotrainrIdentityColors.nutritionistStart;
      default:
        return accent;
    }
  }

  Color get ctaForeground {
    if (id == 'ultimate') return const Color(0xFF141414);
    return Colors.white;
  }

  /// Authoritative resolution: role wins for providers; clients use plan.
  static PassIdentity resolve({
    required UserRole? role,
    String? planLabel,
  }) {
    if (role == UserRole.trainer) return trainer;
    if (role == UserRole.nutritionist) return nutritionist;

    final raw = (planLabel ?? '').trim().toLowerCase();
    if (raw == SubscriptionPlans.basic || raw == 'basic') return basic;
    if (raw == SubscriptionPlans.unlimited ||
        raw == 'premium' ||
        raw == 'ultimate') {
      return ultimate;
    }
    return free;
  }
}

/// Thin aliases kept for Subscription page call sites.
abstract final class SubscriptionPlanColors {
  static const freeStart = CotrainrIdentityColors.freeStart;
  static const freeEnd = CotrainrIdentityColors.freeEnd;
  static const basicStart = CotrainrIdentityColors.basicStart;
  static const basicEnd = CotrainrIdentityColors.basicEnd;
  static const ultimateStart = CotrainrIdentityColors.ultimateStart;
  static const ultimateEnd = CotrainrIdentityColors.ultimateEnd;
  static const ultimateGold = CotrainrIdentityColors.ultimateGold;

  static LinearGradient gradientFor(String plan) {
    final p = plan.toLowerCase();
    if (p == SubscriptionPlans.basic) return PassIdentity.basic.cardGradient;
    if (p == SubscriptionPlans.unlimited) {
      return PassIdentity.ultimate.cardGradient;
    }
    return PassIdentity.free.cardGradient;
  }

  static Color accentFor(String plan) {
    final p = plan.toLowerCase();
    if (p == SubscriptionPlans.basic) return PassIdentity.basic.accent;
    if (p == SubscriptionPlans.unlimited) return PassIdentity.ultimate.accent;
    return PassIdentity.free.accent;
  }

  static Color progressFor(String plan) => accentFor(plan);
}
