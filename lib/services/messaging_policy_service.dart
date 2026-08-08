import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side rules for provider–client messaging (MVP).
/// True security still requires Supabase RLS (sender_id = auth.uid() + participant + blocks).
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
      final row =
          await supabase.from('profiles').select('role').eq('id', userId).maybeSingle();
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

  /// True if either user has blocked the other (server helper).
  static Future<bool> usersAreBlocked({
    required SupabaseClient supabase,
    required String userA,
    required String userB,
  }) async {
    try {
      final raw = await supabase.rpc(
        'users_are_blocked',
        params: {'p_a': userA, 'p_b': userB},
      );
      return raw == true;
    } catch (e) {
      print('MessagingPolicyService.usersAreBlocked: $e');
      return false;
    }
  }

  static Future<bool> accountMayMessage({
    required SupabaseClient supabase,
    required String userId,
  }) async {
    try {
      final raw = await supabase.rpc(
        'account_may_use_messaging',
        params: {'p_user_id': userId},
      );
      return raw == true;
    } catch (e) {
      print('MessagingPolicyService.accountMayMessage: $e');
      // Fail open for older backends without the RPC; RLS still enforces when migrated.
      return true;
    }
  }

  /// Client may use chat with this provider when an accepted lead exists.
  static Future<bool> clientMayUseMessagingWithProvider({
    required SupabaseClient supabase,
    required String clientId,
    required String providerId,
  }) async {
    if (await usersAreBlocked(
      supabase: supabase,
      userA: clientId,
      userB: providerId,
    )) {
      return false;
    }
    return hasAcceptedLead(
      supabase: supabase,
      clientId: clientId,
      providerId: providerId,
    );
  }

  /// Send allowed for conversation participants on provider–client threads.
  /// Blocks and suspended/banned accounts are rejected.
  static Future<bool> canCurrentUserSendMessage({
    required SupabaseClient supabase,
    required Map<String, dynamic> conversation,
  }) async {
    if (!isProviderClientConversation(conversation)) return false;
    final me = supabase.auth.currentUser?.id;
    if (me == null) return false;

    if (!await accountMayMessage(supabase: supabase, userId: me)) {
      return false;
    }

    final clientId = conversation['client_id'] as String?;
    final providerId = conversation['provider_id'] as String?;
    if (clientId == null || providerId == null) return false;

    final other = otherParticipantUserId(conversation, me);
    if (other != null &&
        await usersAreBlocked(supabase: supabase, userA: me, userB: other)) {
      return false;
    }

    if (me == providerId) return true;

    if (me == clientId) {
      return hasAcceptedLead(
        supabase: supabase,
        clientId: clientId,
        providerId: providerId,
      );
    }
    return false;
  }
}
