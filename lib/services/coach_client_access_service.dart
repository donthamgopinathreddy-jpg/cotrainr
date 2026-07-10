import 'package:supabase_flutter/supabase_flutter.dart';

/// Access status for a provider viewing an accepted client's data.
class CoachClientAccessStatus {
  final bool hasAcceptedLead;
  final String? leadId;
  final String? providerType;
  final bool shareMetricsWithTrainer;
  final bool shareMealsWithTrainer;
  final bool shareNutritionWithNutritionist;

  const CoachClientAccessStatus({
    required this.hasAcceptedLead,
    this.leadId,
    this.providerType,
    this.shareMetricsWithTrainer = false,
    this.shareMealsWithTrainer = false,
    this.shareNutritionWithNutritionist = false,
  });

  bool get canViewMetrics =>
      hasAcceptedLead &&
      providerType == 'trainer' &&
      shareMetricsWithTrainer;

  bool get canViewMeals {
    if (!hasAcceptedLead) return false;
    if (providerType == 'trainer') return shareMealsWithTrainer;
    if (providerType == 'nutritionist') return shareNutritionWithNutritionist;
    return false;
  }

  bool get canUseCoachNotes => hasAcceptedLead;

  factory CoachClientAccessStatus.fromJson(Map<String, dynamic> json) {
    return CoachClientAccessStatus(
      hasAcceptedLead: json['has_accepted_lead'] as bool? ?? false,
      leadId: json['lead_id'] as String?,
      providerType: json['provider_type'] as String?,
      shareMetricsWithTrainer:
          json['share_metrics_with_trainer'] as bool? ?? false,
      shareMealsWithTrainer: json['share_meals_with_trainer'] as bool? ?? false,
      shareNutritionWithNutritionist:
          json['share_nutrition_with_nutritionist'] as bool? ?? false,
    );
  }
}

class CoachClientAccessService {
  final SupabaseClient _supabase;

  CoachClientAccessService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<CoachClientAccessStatus> getClientAccess(String clientId) async {
    try {
      final raw = await _supabase.rpc(
        'coach_client_access_status',
        params: {'p_client_id': clientId},
      );
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['error'] != null) {
        return const CoachClientAccessStatus(hasAcceptedLead: false);
      }
      return CoachClientAccessStatus.fromJson(data);
    } catch (_) {
      return const CoachClientAccessStatus(hasAcceptedLead: false);
    }
  }
}
