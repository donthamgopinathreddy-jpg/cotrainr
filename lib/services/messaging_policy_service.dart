import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/subscriptions_repository.dart';

/// Client-side rules for provider–client messaging (MVP).
/// True security still requires Supabase RLS / RPC hardening (not in this change set).
class MessagingPolicyService {
  MessagingPolicyService._();

  /// CoCircle / random DMs: `provider_id` null with `other_user_id` set.
  static bool isProviderClientConversation(Map<String, dynamic> conv) {
    final providerId = conv['provider_id'];
    final otherUserId = conv['other_user_id'];
    if (providerId == null) return false;
    if (otherUserId != null) return false;
    return true;
  }

  static String? otherParticipantUserId(Map<String, dynamic> conv, String me) {
    final clientId = conv['client_id'] as String?;
    final providerId = conv['provider_id'] as String?;
    if (clientId == null || providerId == null) return null;
    if (clientId == me) return providerId;
    if (providerId == me) return clientId;
    return null;
  }

  static Future<String?> fetchUserRole(SupabaseClient supabase, String userId) async {
    try {
      final row = await supabase.from('profiles').select('role').eq('id', userId).maybeSingle();
      return row?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasAcceptedLead({
    required SupabaseClient supabase,
    required String clientId,
    required String providerId,
  }) async {
    try {
      final row = await supabase
          .from('leads')
          .select('id')
          .eq('client_id', clientId)
          .eq('provider_id', providerId)
          .eq('status', 'accepted')
          .maybeSingle();
      return row != null;
    } catch (e) {
      print('MessagingPolicyService.hasAcceptedLead: $e');
      return false;
    }
  }

  /// Client may start / use chat with this provider only with accepted lead + paid active subscription.
  static Future<bool> clientMayUseMessagingWithProvider({
    required SupabaseClient supabase,
    required String clientId,
    required String providerId,
  }) async {
    final leadOk = await hasAcceptedLead(supabase: supabase, clientId: clientId, providerId: providerId);
    if (!leadOk) return false;
    final subRepo = SubscriptionsRepository(supabase: supabase);
    return subRepo.hasActiveMessagingSubscription();
  }

  static Future<bool> canCurrentUserSendMessage({
    required SupabaseClient supabase,
    required Map<String, dynamic> conversation,
  }) async {
    if (!isProviderClientConversation(conversation)) return false;
    final me = supabase.auth.currentUser?.id;
    if (me == null) return false;
    final clientId = conversation['client_id'] as String?;
    final providerId = conversation['provider_id'] as String?;
    if (clientId == null || providerId == null) return false;

    if (me == providerId) return true;

    if (me == clientId) {
      final subRepo = SubscriptionsRepository(supabase: supabase);
      return subRepo.hasActiveMessagingSubscription();
    }
    return false;
  }
}
