import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Outcome of evaluating whether Client↔Provider messaging may be used.
///
/// Matches server codes from [provider_client_messaging_access] /
/// [create_or_find_provider_client_conversation]. Lookup failures are
/// [MessagingAccessStatus.unavailable] — never treated as allowed or as a
/// fake "not connected".
enum MessagingAccessStatus {
  allowed,
  notAccepted,
  subscriptionRequired,
  blocked,
  messagingDisabled,
  unsupportedPairing,
  unavailable,
}

/// Result of a create/find conversation attempt.
class CreateConversationResult {
  final String? conversationId;
  final MessagingAccessStatus status;
  final String? backendCode;

  const CreateConversationResult._({
    this.conversationId,
    required this.status,
    this.backendCode,
  });

  const CreateConversationResult.ok(String id)
      : this._(conversationId: id, status: MessagingAccessStatus.allowed);

  const CreateConversationResult.denied(
    MessagingAccessStatus status, {
    String? backendCode,
  }) : this._(status: status, backendCode: backendCode);

  bool get isOk =>
      status == MessagingAccessStatus.allowed &&
      conversationId != null &&
      conversationId!.isNotEmpty;
}

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

  /// Parses server access codes from `provider_client_messaging_access`.
  static MessagingAccessStatus statusFromBackendCode(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'allowed':
        return MessagingAccessStatus.allowed;
      case 'no_accepted_lead':
        return MessagingAccessStatus.notAccepted;
      case 'subscription_required':
        return MessagingAccessStatus.subscriptionRequired;
      case 'users_blocked':
        return MessagingAccessStatus.blocked;
      case 'messaging_disabled':
        return MessagingAccessStatus.messagingDisabled;
      case 'unsupported_pairing':
      case 'invalid_participants':
        return MessagingAccessStatus.unsupportedPairing;
      default:
        return MessagingAccessStatus.unavailable;
    }
  }

  static MessagingAccessStatus statusFromPostgrestException(
    PostgrestException e,
  ) {
    final blob = '${e.message} ${e.details} ${e.hint} ${e.code}'.toLowerCase();
    if (blob.contains('subscription_required')) {
      return MessagingAccessStatus.subscriptionRequired;
    }
    if (blob.contains('no_accepted_lead')) {
      return MessagingAccessStatus.notAccepted;
    }
    if (blob.contains('users_blocked')) {
      return MessagingAccessStatus.blocked;
    }
    if (blob.contains('messaging_disabled')) {
      return MessagingAccessStatus.messagingDisabled;
    }
    if (blob.contains('unsupported_pairing') ||
        blob.contains('invalid_participants') ||
        blob.contains('provider_cannot_create')) {
      return MessagingAccessStatus.unsupportedPairing;
    }
    return MessagingAccessStatus.unavailable;
  }

  /// User-facing copy for CTA / open failures. Never includes exception text.
  static String userMessageFor(MessagingAccessStatus status) {
    switch (status) {
      case MessagingAccessStatus.allowed:
        return '';
      case MessagingAccessStatus.notAccepted:
        return 'Connect to message and work together.';
      case MessagingAccessStatus.subscriptionRequired:
        return 'An active Cotrainr membership is required to message.';
      case MessagingAccessStatus.blocked:
        return 'Messaging is unavailable with this user.';
      case MessagingAccessStatus.messagingDisabled:
        return 'Messaging is currently unavailable for this account.';
      case MessagingAccessStatus.unsupportedPairing:
        return 'Messaging is only available between members and providers.';
      case MessagingAccessStatus.unavailable:
        return "Couldn't verify messaging access. Try again.";
    }
  }

  static Future<bool> hasAcceptedLead({
    required SupabaseClient supabase,
    required String clientId,
    required String providerId,
  }) async {
    final result = await hasAcceptedLeadStrict(
      supabase: supabase,
      clientId: clientId,
      providerId: providerId,
    );
    // Legacy bool API: unknown failures stay false (deny). Prefer
    // [evaluateMessagingWithOtherUser] for tri-state CTA enablement.
    return result == true;
  }

  /// `true` accepted, `false` not accepted, `null` lookup failure.
  static Future<bool?> hasAcceptedLeadStrict({
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
      print('MessagingPolicyService.hasAcceptedLeadStrict: $e');
      return null;
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
      // Fail closed: unknown account state must not look like allowed.
      return false;
    }
  }

  /// Same predicate as server `can_send` / `client_has_active_messaging_subscription`:
  /// `subscriptions.status = active` and not past `expires_at`.
  ///
  /// Returns `null` on lookup failure (must not be treated as allowed).
  static Future<bool?> clientHasActiveMessagingSubscription({
    required SupabaseClient supabase,
    required String clientId,
  }) async {
    try {
      final row = await supabase
          .from('subscriptions')
          .select('status, expires_at')
          .eq('user_id', clientId)
          .maybeSingle();
      if (row == null) return false;
      final status = (row['status']?.toString() ?? '').toLowerCase();
      if (status != 'active') return false;
      final expRaw = row['expires_at'];
      if (expRaw is String) {
        final exp = DateTime.tryParse(expRaw);
        if (exp != null && !exp.isAfter(DateTime.now())) return false;
      }
      return true;
    } catch (e) {
      print('MessagingPolicyService.clientHasActiveMessagingSubscription: $e');
      return null;
    }
  }

  /// Authoritative CTA / open probe via SECURITY DEFINER RPC when available.
  /// Falls back to local accepted-lead + own-subscription checks for the
  /// current user only (providers cannot read another user's subscription row).
  static Future<MessagingAccessStatus> evaluateMessagingWithOtherUser({
    required SupabaseClient supabase,
    required String otherUserId,
  }) async {
    final me = supabase.auth.currentUser?.id;
    if (me == null || me == otherUserId) {
      return MessagingAccessStatus.unavailable;
    }

    try {
      final raw = await supabase.rpc(
        'provider_client_messaging_access',
        params: {'p_other_user_id': otherUserId},
      );
      if (raw is String) {
        return statusFromBackendCode(raw);
      }
      if (raw != null) {
        return statusFromBackendCode(raw.toString());
      }
      return MessagingAccessStatus.unavailable;
    } on PostgrestException catch (e) {
      // Older backends without the RPC — fall through.
      if (kDebugMode) {
        debugPrint(
          '[MSG_ACCESS_RPC_ERROR] code=${e.code} message=${e.message}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MSG_ACCESS_RPC_ERROR] $e');
      }
    }

    return _evaluateMessagingFallback(
      supabase: supabase,
      me: me,
      otherUserId: otherUserId,
    );
  }

  static Future<MessagingAccessStatus> _evaluateMessagingFallback({
    required SupabaseClient supabase,
    required String me,
    required String otherUserId,
  }) async {
    final myRole = await fetchUserRole(supabase, me);
    final otherRole = await fetchUserRole(supabase, otherUserId);
    if (myRole == null || otherRole == null) {
      return MessagingAccessStatus.unavailable;
    }

    final String clientId;
    final String providerId;
    final iAmProvider =
        myRole == 'trainer' || myRole == 'nutritionist';
    final otherIsProvider =
        otherRole == 'trainer' || otherRole == 'nutritionist';

    if (iAmProvider && !otherIsProvider) {
      providerId = me;
      clientId = otherUserId;
    } else if (!iAmProvider && otherIsProvider) {
      clientId = me;
      providerId = otherUserId;
    } else {
      return MessagingAccessStatus.unsupportedPairing;
    }

    try {
      if (await usersAreBlocked(
        supabase: supabase,
        userA: clientId,
        userB: providerId,
      )) {
        return MessagingAccessStatus.blocked;
      }
    } catch (_) {
      return MessagingAccessStatus.unavailable;
    }

    final accepted = await hasAcceptedLeadStrict(
      supabase: supabase,
      clientId: clientId,
      providerId: providerId,
    );
    if (accepted == null) return MessagingAccessStatus.unavailable;
    if (!accepted) return MessagingAccessStatus.notAccepted;

    // Providers cannot SELECT the client's subscription under RLS. Without the
    // access RPC they cannot truthfully enable Message — fail closed.
    if (me != clientId) {
      return MessagingAccessStatus.unavailable;
    }

    final sub = await clientHasActiveMessagingSubscription(
      supabase: supabase,
      clientId: clientId,
    );
    if (sub == null) return MessagingAccessStatus.unavailable;
    if (!sub) return MessagingAccessStatus.subscriptionRequired;
    return MessagingAccessStatus.allowed;
  }

  /// Client may use chat with this provider when accepted + active subscription.
  /// Failures return false (deny). Prefer [evaluateMessagingWithOtherUser].
  static Future<bool> clientMayUseMessagingWithProvider({
    required SupabaseClient supabase,
    required String clientId,
    required String providerId,
  }) async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return false;
    final other = me == clientId ? providerId : (me == providerId ? clientId : null);
    if (other == null) return false;
    final status = await evaluateMessagingWithOtherUser(
      supabase: supabase,
      otherUserId: other,
    );
    return status == MessagingAccessStatus.allowed;
  }

  /// Send allowed for conversation participants on provider–client threads.
  ///
  /// Both **member and provider** require a current accepted lead and an
  /// active client subscription (server `can_send_message_in_conversation`).
  /// Prefers the live RPC when available; otherwise falls back with fail-closed
  /// subscription checks. Providers must also have a current accepted lead.
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
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[MSG_POLICY_FALLBACK_ENTERED] authUid=$me '
        'conversationId=$conversationId',
      );
    }

    final mayMessage = await accountMayMessage(supabase: supabase, userId: me);
    if (!mayMessage) return false;

    final other = otherParticipantUserId(conversation, me);
    if (other != null) {
      final blocked = await usersAreBlocked(
        supabase: supabase,
        userA: me,
        userB: other,
      );
      if (blocked) return false;
    }

    final accepted = await hasAcceptedLeadStrict(
      supabase: supabase,
      clientId: clientId,
      providerId: providerId,
    );
    if (accepted != true) return false;

    final sub = await clientHasActiveMessagingSubscription(
      supabase: supabase,
      clientId: clientId,
    );
    // Fail closed when subscription state cannot be confirmed.
    return sub == true;
  }

  /// Classify why send is locked when [canSend] is false.
  static Future<MessagingAccessStatus> classifySendDenial({
    required SupabaseClient supabase,
    required Map<String, dynamic> conversation,
  }) async {
    if (!isProviderClientConversation(conversation)) {
      return MessagingAccessStatus.unsupportedPairing;
    }
    final clientId = conversation['client_id'] as String?;
    final providerId = conversation['provider_id'] as String?;
    if (clientId == null || providerId == null) {
      return MessagingAccessStatus.unavailable;
    }

    final other = supabase.auth.currentUser?.id == clientId
        ? providerId
        : clientId;
    return evaluateMessagingWithOtherUser(
      supabase: supabase,
      otherUserId: other,
    );
  }

  /// True when a provider–client thread should show the ended/read-only banner
  /// (conversation exists, not blocked, cannot send, relationship not accepted).
  static bool shouldShowEndedConnectionBanner({
    required bool hasConversationRow,
    required bool isProviderClient,
    required bool canSend,
    required bool eitherBlocked,
    MessagingAccessStatus? denialStatus,
  }) {
    if (!(hasConversationRow &&
        isProviderClient &&
        !canSend &&
        !eitherBlocked)) {
      return false;
    }
    if (denialStatus == MessagingAccessStatus.subscriptionRequired ||
        denialStatus == MessagingAccessStatus.unavailable ||
        denialStatus == MessagingAccessStatus.messagingDisabled ||
        denialStatus == MessagingAccessStatus.unsupportedPairing) {
      return false;
    }
    // Default: treat as ended when not accepted / unknown denial without
    // subscription signal. Callers should pass [denialStatus] when known.
    return denialStatus == null ||
        denialStatus == MessagingAccessStatus.notAccepted;
  }

  static bool shouldShowSubscriptionRequiredBanner({
    required bool hasConversationRow,
    required bool isProviderClient,
    required bool canSend,
    required bool eitherBlocked,
    required MessagingAccessStatus? denialStatus,
  }) {
    return hasConversationRow &&
        isProviderClient &&
        !canSend &&
        !eitherBlocked &&
        denialStatus == MessagingAccessStatus.subscriptionRequired;
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
