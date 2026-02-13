import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing messages and conversations
class MessagesRepository {
  final SupabaseClient _supabase;

  MessagesRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get unread messages count for current user
  Future<int> getUnreadMessagesCount() async {
    if (_currentUserId == null) return 0;

    try {
      // Get all conversations where user is a participant
      final conversationsResponse = await _supabase
          .from('conversations')
          .select('id')
          .or('client_id.eq.$_currentUserId,provider_id.eq.$_currentUserId,other_user_id.eq.$_currentUserId');

      if (conversationsResponse.isEmpty) return 0;

      final conversationIds = (conversationsResponse as List)
          .map((c) => c['id'] as String)
          .toList();

      // Count unread messages (where read_at is null and sender is not current user)
      int totalUnread = 0;
      for (final convId in conversationIds) {
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
        
        // Determine the other participant (cocircle uses other_user_id, client-provider uses provider_id)
        final clientId = conv['client_id'] as String;
        final providerId = conv['provider_id'] as String?;
        final otherUserIdCol = conv['other_user_id'] as String?;
        final isClient = clientId == _currentUserId;
        final otherUserId = otherUserIdCol ?? (isClient ? providerId : clientId);
        if (otherUserId == null) continue;
        
        // Get other participant's profile
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, username, avatar_url, full_name')
            .eq('id', otherUserId)
            .maybeSingle();
        
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
      final Map<String, dynamic> insertData = {
        'conversation_id': conversationId,
        'sender_id': _currentUserId!,
        'content': content,
      };
      if (mediaUrl != null) {
        insertData['media_url'] = mediaUrl;
        if (mediaKind != null) insertData['media_kind'] = mediaKind;
      }
      final response = await _supabase
          .from('messages')
          .insert(insertData)
          .select()
          .single();

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

  /// Create or find a conversation between two users (for cocircle messaging)
  /// Returns the conversation ID
  /// Supports both: client-provider (trainer/nutritionist) and cocircle user-to-user
  Future<String?> createOrFindConversation(String otherUserId) async {
    if (_currentUserId == null) return null;
    if (_currentUserId == otherUserId) return null;

    try {
      // 1. Find existing cocircle conversation (client_id + other_user_id)
      var existingConv = await _supabase
          .from('conversations')
          .select('id')
          .eq('client_id', _currentUserId!)
          .eq('other_user_id', otherUserId)
          .maybeSingle();

      if (existingConv != null) {
        return existingConv['id'] as String;
      }

      // 2. Find existing cocircle conversation (other way around)
      existingConv = await _supabase
          .from('conversations')
          .select('id')
          .eq('client_id', otherUserId)
          .eq('other_user_id', _currentUserId!)
          .maybeSingle();

      if (existingConv != null) {
        return existingConv['id'] as String;
      }

      // 3. Find existing client-provider conversation
      existingConv = await _supabase
          .from('conversations')
          .select('id')
          .eq('client_id', _currentUserId!)
          .eq('provider_id', otherUserId)
          .maybeSingle();

      if (existingConv != null) {
        return existingConv['id'] as String;
      }

      existingConv = await _supabase
          .from('conversations')
          .select('id')
          .eq('client_id', otherUserId)
          .eq('provider_id', _currentUserId!)
          .maybeSingle();

      if (existingConv != null) {
        return existingConv['id'] as String;
      }

      // 4. Create new cocircle conversation (user-to-user, no provider)
      final newConv = await _supabase
          .from('conversations')
          .insert({
            'client_id': _currentUserId!,
            'other_user_id': otherUserId,
            // lead_id and provider_id are null for cocircle DMs
          })
          .select('id')
          .single();

      return newConv['id'] as String;
    } catch (e, stack) {
      print('Error creating or finding conversation: $e');
      print('Stack trace: $stack');
      return null;
    }
  }
}
