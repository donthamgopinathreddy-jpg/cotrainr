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
          .or('client_id.eq.$_currentUserId,provider_id.eq.$_currentUserId');

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

  /// Get conversations for current user
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    if (_currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            profiles!conversations_client_id_fkey(id, username, avatar_url, full_name),
            providers!conversations_provider_id_fkey(user_id, provider_type)
          ''')
          .or('client_id.eq.$_currentUserId,provider_id.eq.$_currentUserId')
          .order('updated_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }
}
