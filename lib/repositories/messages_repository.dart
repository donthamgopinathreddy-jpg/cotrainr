import 'package:flutter/foundation.dart';
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
      if (kDebugMode) debugPrint('Error fetchConversationById: $e');
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
      if (kDebugMode) debugPrint('Error fetching unread messages count: $e');
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
      if (kDebugMode) debugPrint('Error fetching conversations: $e');
      rethrow;
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
      if (kDebugMode) debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String content,
    String? mediaUrl,
    String? mediaKind,
    String? mediaFileName,
    String? mediaMimeType,
    int? mediaSizeBytes,
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
        if (kDebugMode) {
          debugPrint('sendMessage blocked by MessagingPolicyService');
        }
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
        if (mediaFileName != null) {
          insertData['media_file_name'] = mediaFileName;
        }
        if (mediaMimeType != null) {
          insertData['media_mime_type'] = mediaMimeType;
        }
        if (mediaSizeBytes != null) {
          insertData['media_size_bytes'] = mediaSizeBytes;
        }
      }

      try {
        final response = await _supabase
            .from('messages')
            .insert(insertData)
            .select()
            .single();

        await _supabase
            .from('conversations')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', conversationId);

        return response;
      } catch (e) {
        // Fallback when document enum/metadata columns are not migrated yet.
        if (mediaKind == 'document' && mediaUrl != null) {
          final fallback = <String, dynamic>{
            'conversation_id': conversationId,
            'sender_id': _currentUserId!,
            'content': content.isNotEmpty ? content : (mediaFileName ?? 'Document'),
            'media_url': mediaUrl,
          };
          try {
            final response = await _supabase
                .from('messages')
                .insert(fallback)
                .select()
                .single();
            await _supabase
                .from('conversations')
                .update({'updated_at': DateTime.now().toIso8601String()})
                .eq('id', conversationId);
            return {
              ...response,
              'media_kind': 'document',
              'media_file_name': mediaFileName,
              'media_mime_type': mediaMimeType,
              'media_size_bytes': mediaSizeBytes,
            };
          } catch (e2) {
            if (kDebugMode) debugPrint('Error sending document fallback: $e2');
            rethrow;
          }
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending message: $e');
      // Attachments need the real error in the UI; text keeps soft-fail.
      if (mediaUrl != null) rethrow;
      return null;
    }
  }

  /// Mark messages from the other participant as read via RPC.
  /// Returns how many rows were updated (0 if none / RPC missing).
  Future<int> markMessagesAsRead(String conversationId) async {
    if (_currentUserId == null) return 0;

    try {
      final result = await _supabase.rpc(
        'mark_conversation_messages_read',
        params: {'p_conversation_id': conversationId},
      );
      if (result is int) return result;
      if (result is num) return result.toInt();
      return 0;
    } catch (e) {
      if (_isMissingRpc(e)) {
        if (kDebugMode) {
          debugPrint('markMessagesAsRead: RPC missing, returning 0');
        }
        return 0;
      }
      if (kDebugMode) debugPrint('Error marking messages as read: $e');
      return 0;
    }
  }

  bool _isMissingRpc(Object e) {
    if (e is PostgrestException) {
      final code = e.code ?? '';
      if (code.startsWith('PGRST')) return true;
      final msg = (e.message).toLowerCase();
      if (msg.contains('could not find the function') ||
          msg.contains('mark_conversation_messages_read')) {
        return true;
      }
    }
    final s = e.toString().toLowerCase();
    return s.contains('pgrst') ||
        s.contains('could not find the function') ||
        s.contains('mark_conversation_messages_read');
  }

  /// Subscribe to new messages in a conversation
  RealtimeChannel subscribeToMessages(
    String conversationId,
    Function(Map<String, dynamic>) onNewMessage,
  ) {
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

  /// Subscribe to message UPDATE events (e.g. `read_at` for Seen indicators).
  RealtimeChannel subscribeToMessageUpdates(
    String conversationId,
    Function(Map<String, dynamic>) onMessageUpdate,
  ) {
    final channel = _supabase
        .channel('messages-updates:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onMessageUpdate(payload.newRecord);
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
  /// Prefers RPC `create_or_find_provider_client_conversation`.
  Future<String?> createOrFindConversation(String otherUserId) async {
    if (_currentUserId == null) return null;
    if (_currentUserId == otherUserId) return null;

    try {
      final result = await _supabase.rpc(
        'create_or_find_provider_client_conversation',
        params: {'p_other_user_id': otherUserId},
      );
      if (result is String && result.isNotEmpty) return result;
      if (result != null) {
        final asString = result.toString();
        if (asString.isNotEmpty && asString != 'null') return asString;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'createOrFindConversation: failed (need accepted lead): $e',
        );
      }
      return null;
    }
  }
}
