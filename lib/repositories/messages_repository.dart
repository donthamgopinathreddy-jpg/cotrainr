import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/messaging_policy_service.dart';

/// Repository for managing messages and conversations
class MessagesRepository {
  final SupabaseClient _supabase;

  MessagesRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// MVP: list/query only provider–client threads (excludes CoCircle `other_user_id` rows).
  static bool passesMvpConversationFilter(Map<String, dynamic> conv) {
    return MessagingPolicyService.isProviderClientConversation(conv);
  }

  Future<Map<String, dynamic>?> fetchConversationById(String conversationId) async {
    if (_currentUserId == null) return null;
    try {
      final row = await _supabase.from('conversations').select('*').eq('id', conversationId).maybeSingle();
      if (row == null) return null;
      if (!passesMvpConversationFilter(row)) return null;
      return Map<String, dynamic>.from(row);
    } catch (e) {
      print('Error fetchConversationById: $e');
      return null;
    }
  }

  /// Get unread messages count for current user
  Future<int> getUnreadMessagesCount() async {
    if (_currentUserId == null) return 0;

    try {
      final conversationsResponse = await _supabase
          .from('conversations')
          .select('*')
          .or('client_id.eq.$_currentUserId,provider_id.eq.$_currentUserId,other_user_id.eq.$_currentUserId');

      if (conversationsResponse.isEmpty) return 0;

      final filteredIds = (conversationsResponse as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .where(passesMvpConversationFilter)
          .map((c) => c['id'] as String)
          .toList();

      int totalUnread = 0;
      for (final convId in filteredIds) {
        final messagesResponse = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .isFilter('read_at', null)
            .neq('sender_id', _currentUserId!);

        totalUnread += (messagesResponse as List).length;
      }

      return totalUnread;
    } catch (e) {
      print('Error fetching unread messages count: $e');
      return 0;
    }
  }

  /// Get conversations for current user with last message and unread count
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    if (_currentUserId == null) return [];

    try {
      final conversations = await _supabase
          .from('conversations')
          .select('*')
          .or('client_id.eq.$_currentUserId,provider_id.eq.$_currentUserId,other_user_id.eq.$_currentUserId')
          .order('updated_at', ascending: false);

      final List<Map<String, dynamic>> result = [];

      for (final conv in conversations) {
        if (!passesMvpConversationFilter(Map<String, dynamic>.from(conv))) {
          continue;
        }
        final convId = conv['id'] as String;

        // Get last message
        final lastMessageResponse = await _supabase
            .from('messages')
            .select('*')
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // Get unread count
        final unreadResponse = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .isFilter('read_at', null)
            .neq('sender_id', _currentUserId!);

        final unreadCount = (unreadResponse as List).length;

        final clientId = conv['client_id'] as String;
        final providerId = conv['provider_id'] as String?;
        final otherUserIdCol = conv['other_user_id'] as String?;
        final isClient = clientId == _currentUserId;
        final otherUserId = otherUserIdCol ?? (isClient ? providerId : clientId);
        if (otherUserId == null) continue;

        // Get other participant's profile
        final profileList =
            (await _supabase.rpc('get_public_profile', params: {'p_user_id': otherUserId}) as List)
                .cast<Map<String, dynamic>>();
        final profileResponse = profileList.isNotEmpty ? profileList.first : null;

        result.add({
          'id': convId,
          'conversation': conv,
          'lastMessage': lastMessageResponse,
          'unreadCount': unreadCount,
          'otherUser': profileResponse,
          'updatedAt': conv['updated_at'],
        });
      }

      return result;
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }

  /// Get messages for a conversation
  Future<List<Map<String, dynamic>>> fetchMessages(String conversationId) async {
    if (_currentUserId == null) return [];

    try {
      final conv = await fetchConversationById(conversationId);
      if (conv == null) return [];

      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String content,
    String? mediaUrl,
    String? mediaKind,
  }) async {
    if (_currentUserId == null) return null;

    try {
      final conv = await fetchConversationById(conversationId);
      if (conv == null) return null;
      final allowed = await MessagingPolicyService.canCurrentUserSendMessage(
        supabase: _supabase,
        conversation: conv,
      );
      if (!allowed) {
        print('sendMessage blocked by MessagingPolicyService');
        return null;
      }

      final Map<String, dynamic> insertData = {
        'conversation_id': conversationId,
        'sender_id': _currentUserId!,
        'content': content,
      };
      if (mediaUrl != null) {
        insertData['media_url'] = mediaUrl;
        if (mediaKind != null) insertData['media_kind'] = mediaKind;
      }
      final response = await _supabase.from('messages').insert(insertData).select().single();

      // Update conversation updated_at
      await _supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId);

      return response;
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    if (_currentUserId == null) return;

    try {
      final conv = await fetchConversationById(conversationId);
      if (conv == null) return;

      await _supabase
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .isFilter('read_at', null)
          .neq('sender_id', _currentUserId!);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Subscribe to new messages in a conversation
  RealtimeChannel subscribeToMessages(String conversationId, Function(Map<String, dynamic>) onNewMessage) {
    final channel = _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onNewMessage(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribe to conversation updates
  RealtimeChannel subscribeToConversations(Function(Map<String, dynamic>) onConversationUpdate) {
    final channel = _supabase
        .channel('conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            onConversationUpdate(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  /// Create or find a **provider–client** conversation only (MVP).
  /// RLS: only the **client** can INSERT a new row (`auth.uid() = client_id`).
  /// Providers must use an existing row (e.g. created when a lead is accepted via `update_lead_status_tx`).
  Future<String?> createOrFindConversation(String otherUserId) async {
    if (_currentUserId == null) return null;
    if (_currentUserId == otherUserId) return null;

    try {
      // Find existing client–provider (both orientations)
      var existingConv = await _supabase
          .from('conversations')
          .select('id, provider_id, client_id, other_user_id')
          .eq('client_id', _currentUserId!)
          .eq('provider_id', otherUserId)
          .maybeSingle();

      if (existingConv != null && passesMvpConversationFilter(Map<String, dynamic>.from(existingConv))) {
        return existingConv['id'] as String;
      }

      existingConv = await _supabase
          .from('conversations')
          .select('id, provider_id, client_id, other_user_id')
          .eq('client_id', otherUserId)
          .eq('provider_id', _currentUserId!)
          .maybeSingle();

      if (existingConv != null && passesMvpConversationFilter(Map<String, dynamic>.from(existingConv))) {
        return existingConv['id'] as String;
      }

      final myRole = await MessagingPolicyService.fetchUserRole(_supabase, _currentUserId!);
      final otherRole = await MessagingPolicyService.fetchUserRole(_supabase, otherUserId);

      final iAmProvider = myRole == 'trainer' || myRole == 'nutritionist';
      final otherIsProvider = otherRole == 'trainer' || otherRole == 'nutritionist';

      // Provider cannot INSERT under current RLS — conversation should exist from lead acceptance.
      if (iAmProvider && !otherIsProvider) {
        print('createOrFindConversation: provider cannot create thread; expected existing lead conversation');
        return null;
      }

      // Client messaging a provider: INSERT allowed if RLS passes.
      if (!iAmProvider && otherIsProvider) {
        final ok = await MessagingPolicyService.clientMayUseMessagingWithProvider(
          supabase: _supabase,
          clientId: _currentUserId!,
          providerId: otherUserId,
        );
        if (!ok) {
          print('createOrFindConversation: client lacks accepted lead or active subscription');
          return null;
        }
        final newConv = await _supabase.from('conversations').insert({
          'client_id': _currentUserId!,
          'provider_id': otherUserId,
        }).select('id').single();
        return newConv['id'] as String;
      }

      print('createOrFindConversation: unsupported participant pairing');
      return null;
    } catch (e, stack) {
      print('Error creating or finding conversation: $e');
      print('Stack trace: $stack');
      return null;
    }
  }
}
