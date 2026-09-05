import 'package:flutter/foundation.dart';
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

  static Future<String?> fetchUserRole(
    SupabaseClient supabase,
    String userId,
  ) async {
    try {
      final row = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
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
  ///
  /// Both **member and provider** require a *current* accepted lead.
  /// Prefers the live RPC `can_send_message_in_conversation` (uses
  /// `conversation_has_accepted_lead`) when available; otherwise falls back to
  /// a direct accepted-lead check for both roles.
  static Future<bool> canCurrentUserSendMessage({
    required SupabaseClient supabase,
    required Map<String, dynamic> conversation,
  }) async {
    if (!isProviderClientConversation(conversation)) {
      if (kDebugMode) {
        debugPrint(
          '[MSG_POLICY_SHAPE] rejected non-provider-client conversation '
          'id=${conversation['id']} provider_id=${conversation['provider_id']} '
          'other_user_id=${conversation['other_user_id']}',
        );
      }
      return false;
    }
    final me = supabase.auth.currentUser?.id;
    if (me == null) return false;

    final clientId = conversation['client_id'] as String?;
    final providerId = conversation['provider_id'] as String?;
    if (clientId == null || providerId == null) return false;
    if (me != clientId && me != providerId) return false;

    final conversationId = conversation['id'] as String?;
    if (conversationId != null && conversationId.isNotEmpty) {
      try {
        final raw = await supabase.rpc(
          'can_send_message_in_conversation',
          params: {'p_conversation_id': conversationId, 'p_user_id': me},
        );
        final parsed = raw == true;
        if (kDebugMode) {
          debugPrint(
            '[MSG_POLICY_RPC] authUid=$me conversationId=$conversationId '
            'raw=$raw rawRuntimeType=${raw?.runtimeType} parsedBool=$parsed',
          );
        }
        return parsed;
      } on PostgrestException catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[MSG_POLICY_RPC_ERROR] authUid=$me conversationId=$conversationId '
            'code=${e.code} message=${e.message} details=${e.details} '
            'hint=${e.hint}',
          );
        }
        // Fall through for older backends without the RPC.
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[MSG_POLICY_RPC_ERROR] authUid=$me conversationId=$conversationId '
            'runtimeType=${e.runtimeType} exception=$e',
          );
        }
        print('MessagingPolicyService.canCurrentUserSendMessage rpc: $e');
        // Fall through for older backends without the RPC.
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[MSG_POLICY_FALLBACK_ENTERED] authUid=$me '
        'conversationId=$conversationId',
      );
    }

    final mayMessage = await accountMayMessage(supabase: supabase, userId: me);
    if (kDebugMode) {
      debugPrint(
        '[MSG_POLICY_FALLBACK] stage=account_may_use_messaging '
        'result=$mayMessage',
      );
    }
    if (!mayMessage) {
      return false;
    }

    final other = otherParticipantUserId(conversation, me);
    if (other != null) {
      final blocked = await usersAreBlocked(
        supabase: supabase,
        userA: me,
        userB: other,
      );
      if (kDebugMode) {
        debugPrint(
          '[MSG_POLICY_FALLBACK] stage=users_are_blocked result=$blocked',
        );
      }
      if (blocked) {
        return false;
      }
    }

    // Symmetric: providers must also have a current accepted lead.
    final accepted = await hasAcceptedLead(
      supabase: supabase,
      clientId: clientId,
      providerId: providerId,
    );
    if (kDebugMode) {
      debugPrint(
        '[MSG_POLICY_FALLBACK] stage=hasAcceptedLead result=$accepted',
      );
    }
    return accepted;
  }

  /// True when a provider–client thread should show the ended/read-only banner
  /// (conversation exists, not blocked, cannot send).
  static bool shouldShowEndedConnectionBanner({
    required bool hasConversationRow,
    required bool isProviderClient,
    required bool canSend,
    required bool eitherBlocked,
  }) {
    return hasConversationRow && isProviderClient && !canSend && !eitherBlocked;
  }

  /// Composer (input/send/attachments) is shown only when send is allowed and
  /// the pair is not blocked.
  static bool shouldShowMessageComposer({
    required bool canSend,
    required bool eitherBlocked,
  }) {
    return canSend && !eitherBlocked;
  }
}
