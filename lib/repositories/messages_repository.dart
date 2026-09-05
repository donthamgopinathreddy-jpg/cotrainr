import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/messaging_policy_service.dart';
import '../utils/chat_message_reconciler.dart' show kDeletedMessageText;
import '../utils/message_insert_payload.dart';

/// Whether a mark-read attempt actually reached the database.
///
/// [unsupported] means `mark_conversation_messages_read` is not deployed, so
/// read state cannot be persisted at all and the UI must not present the
/// conversation as permanently read.
enum MarkReadOutcome { success, unsupported, failed }

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

  Future<Map<String, dynamic>?> fetchConversationById(
    String conversationId,
  ) async {
    if (_currentUserId == null) return null;
    try {
      final row = await _supabase
          .from('conversations')
          .select('*')
          .eq('id', conversationId)
          .maybeSingle();
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
          .or(
            'client_id.eq.$_currentUserId,provider_id.eq.$_currentUserId,other_user_id.eq.$_currentUserId',
          );

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
            .isFilter('deleted_for_everyone_at', null)
            .neq('sender_id', _currentUserId!);

        totalUnread += (messagesResponse as List).length;
      }

      return totalUnread;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching unread messages count: $e');
      return 0;
    }
  }

  /// Tombstone text shown in place of a message deleted for everyone.
  static const String deletedMessagePlaceholder = kDeletedMessageText;

  /// True when the server marked this message row as deleted for everyone.
  static bool isDeletedForEveryone(Map<String, dynamic>? message) {
    if (message == null) return false;
    final raw = message['deleted_for_everyone_at'];
    if (raw == null) return false;
    if (raw is String) return raw.isNotEmpty;
    return true;
  }

  /// Activity timestamp a conversation should be sorted by: newest message
  /// first, never `created_at`.
  static DateTime? conversationActivityAt(Map<String, dynamic> convData) {
    final conv = convData['conversation'];
    final lastMessage = convData['lastMessage'];
    final candidates = <dynamic>[
      convData['lastMessageAt'],
      if (lastMessage is Map) lastMessage['created_at'],
      if (conv is Map) conv['last_message_at'],
      convData['updatedAt'],
      if (conv is Map) conv['updated_at'],
    ];

    DateTime? newest;
    for (final candidate in candidates) {
      final parsed = candidate is DateTime
          ? candidate
          : (candidate is String && candidate.isNotEmpty
                ? DateTime.tryParse(candidate)
                : null);
      if (parsed == null) continue;
      if (newest == null || parsed.isAfter(newest)) newest = parsed;
    }
    return newest;
  }

  /// Sort newest-activity-first and drop duplicate conversation rows, which
  /// realtime refetch races can otherwise introduce.
  static List<Map<String, dynamic>> sortConversationsByActivity(
    List<Map<String, dynamic>> conversations,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final conv in conversations) {
      final id = conv['id'];
      if (id is! String || id.isEmpty) continue;
      byId[id] = conv;
    }

    final sorted = byId.values.toList()
      ..sort((a, b) {
        final aAt = conversationActivityAt(a);
        final bAt = conversationActivityAt(b);
        if (aAt != null && bAt != null) {
          final byTime = bAt.compareTo(aAt);
          if (byTime != 0) return byTime;
        } else if (aAt == null && bAt != null) {
          return 1;
        } else if (aAt != null && bAt == null) {
          return -1;
        }
        // Matches the server tiebreaker so both orderings agree exactly.
        return (b['id'] as String).compareTo(a['id'] as String);
      });
    return sorted;
  }

  /// Get conversations for current user with last message and unread count
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    if (_currentUserId == null) return [];

    try {
      final conversations = await _fetchConversationRowsOrdered();

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
        // A message deleted for everyone can never be read, so counting it
        // would leave a badge the user has no way to clear.
        final unreadResponse = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .isFilter('read_at', null)
            .isFilter('deleted_for_everyone_at', null)
            .neq('sender_id', _currentUserId!);

        final unreadCount = (unreadResponse as List).length;

        final clientId = conv['client_id'] as String;
        final providerId = conv['provider_id'] as String?;
        final otherUserIdCol = conv['other_user_id'] as String?;
        final isClient = clientId == _currentUserId;
        final otherUserId =
            otherUserIdCol ?? (isClient ? providerId : clientId);
        if (otherUserId == null) continue;

        // Get other participant's profile
        final profileList =
            (await _supabase.rpc(
                      'get_public_profile',
                      params: {'p_user_id': otherUserId},
                    )
                    as List)
                .cast<Map<String, dynamic>>();
        final profileResponse = profileList.isNotEmpty
            ? profileList.first
            : null;

        result.add({
          'id': convId,
          'conversation': conv,
          'lastMessage': lastMessageResponse,
          'unreadCount': unreadCount,
          'otherUser': profileResponse,
          'updatedAt': conv['updated_at'],
          'lastMessageAt':
              conv['last_message_at'] ?? lastMessageResponse?['created_at'],
        });
      }

      // Server ordering is authoritative, but re-sort locally so a lagging or
      // not-yet-migrated `last_message_at` can never leave a fresh chat buried.
      return sortConversationsByActivity(result);
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching conversations: $e');
      rethrow;
    }
  }

  /// Order by `conversations.last_message_at DESC, id DESC`, falling back to
  /// `updated_at` on deployments where the ordering migration has not been
  /// applied yet. Both the initial fetch and every realtime refetch go through
  /// here, so their ordering semantics are identical.
  Future<List<dynamic>> _fetchConversationRowsOrdered() async {
    final filter =
        'client_id.eq.$_currentUserId,provider_id.eq.$_currentUserId,other_user_id.eq.$_currentUserId';
    try {
      return await _supabase
          .from('conversations')
          .select('*')
          .or(filter)
          .order('last_message_at', ascending: false, nullsFirst: false)
          .order('id', ascending: false);
    } catch (e) {
      if (!_isMissingColumn(e, 'last_message_at')) rethrow;
      if (kDebugMode) {
        debugPrint(
          'fetchConversations: last_message_at missing, falling back to updated_at',
        );
      }
      return await _supabase
          .from('conversations')
          .select('*')
          .or(filter)
          .order('updated_at', ascending: false)
          .order('id', ascending: false);
    }
  }

  bool _isMissingColumn(Object e, String column) {
    if (e is PostgrestException && e.code == '42703') return true;
    final s = e.toString().toLowerCase();
    return s.contains('42703') ||
        (s.contains(column) &&
            (s.contains('does not exist') || s.contains('could not find')));
  }

  /// Get messages for a conversation
  Future<List<Map<String, dynamic>>> fetchMessages(
    String conversationId,
  ) async {
    if (_currentUserId == null) return [];

    try {
      final conv = await fetchConversationById(conversationId);
      if (conv == null) return [];

      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      final hidden = await fetchHiddenMessageIds();
      if (hidden.isEmpty) return rows;
      return rows
          .where((m) => !hidden.contains(m['id'] as String? ?? ''))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  /// Ids the current user hid via "Delete for me". Server-persisted and
  /// private: RLS restricts `message_hidden` to the owning user.
  Future<Set<String>> fetchHiddenMessageIds() async {
    if (_currentUserId == null) return <String>{};
    try {
      final rows = await _supabase
          .from('message_hidden')
          .select('message_id')
          .eq('user_id', _currentUserId!);
      return (rows as List)
          .map((r) => (r as Map)['message_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      // Table absent (pre-migration) or unreadable: show everything.
      if (kDebugMode) debugPrint('fetchHiddenMessageIds failed: $e');
      return <String>{};
    }
  }

  /// Delete for everyone. Server-authoritative: the RPC verifies the caller is
  /// the sender, archives the original and redacts the row so neither
  /// participant can read the content afterwards.
  ///
  /// Throws [PostgrestException] when the caller is not authorised.
  Future<bool> deleteMessageForEveryone(String messageId) async {
    if (_currentUserId == null || messageId.isEmpty) return false;
    final result = await _supabase.rpc(
      'delete_message_for_everyone',
      params: {'p_message_id': messageId},
    );
    return result == true;
  }

  /// Delete for me. Private hide; the other participant is unaffected.
  Future<bool> hideMessageForMe(String messageId) async {
    if (_currentUserId == null || messageId.isEmpty) return false;
    final result = await _supabase.rpc(
      'hide_message_for_me',
      params: {'p_message_id': messageId},
    );
    return result == true;
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
    // TEMP DEBUG — messaging-reconnect-debug-20260905 (no UI / control-flow change)
    if (kDebugMode) {
      debugPrint(
        '[MSG_SEND_START] authUid=${_currentUserId} '
        'conversationId=$conversationId '
        'contentNonEmpty=${content.trim().isNotEmpty} '
        'hasMedia=${mediaUrl != null}',
      );
    }

    if (_currentUserId == null) return null;

    try {
      final conv = await fetchConversationById(conversationId);
      if (kDebugMode) {
        debugPrint(
          '[MSG_SEND_CONVERSATION] found=${conv != null} '
          'conversationId=${conv?['id'] ?? conversationId} '
          'client_id=${conv?['client_id']} '
          'provider_id=${conv?['provider_id']} '
          'lead_id=${conv?['lead_id']} '
          'other_user_id=${conv?['other_user_id']}',
        );
      }
      if (conv == null) return null;

      if (kDebugMode) {
        debugPrint(
          '[MSG_SEND_POLICY] before authUid=$_currentUserId '
          'conversationId=${conv['id']}',
        );
      }
      final allowed = await MessagingPolicyService.canCurrentUserSendMessage(
        supabase: _supabase,
        conversation: conv,
      );
      if (kDebugMode) {
        debugPrint(
          '[MSG_SEND_POLICY] after authUid=$_currentUserId '
          'conversationId=${conv['id']} allowed=$allowed',
        );
      }
      if (!allowed) {
        if (kDebugMode) {
          debugPrint('sendMessage blocked by MessagingPolicyService');
        }
        return null;
      }

      final Map<String, dynamic> insertData = buildMessageInsertPayload(
        conversationId: conversationId,
        senderId: _currentUserId!,
        content: content,
        mediaUrl: mediaUrl,
        mediaKind: mediaKind,
        mediaFileName: mediaFileName,
        mediaMimeType: mediaMimeType,
        mediaSizeBytes: mediaSizeBytes,
      );

      try {
        if (kDebugMode) {
          debugPrint(
            '[MSG_SEND_INSERT_START] conversation_id=$conversationId '
            'sender_id=$_currentUserId '
            'messageType=${mediaKind ?? (mediaUrl != null ? 'media' : 'text')} '
            'payloadKeys=${insertData.keys.toList()} '
            'hasMediaKind=${insertData.containsKey('media_kind')} '
            'mediaKindValue=${insertData['media_kind']}',
          );
        }
        final response = await _supabase
            .from('messages')
            .insert(insertData)
            .select()
            .single();

        if (kDebugMode) {
          debugPrint('[MSG_SEND_INSERT_SUCCESS] messageId=${response['id']}');
        }

        // Ordering is bumped by trg_messages_touch_conversation. A client
        // UPDATE here silently affected zero rows: conversations has RLS on
        // and no UPDATE policy.
        return response;
      } catch (e) {
        // Fallback when document enum/metadata columns are not migrated yet.
        if (mediaKind == 'document' && mediaUrl != null) {
          final fallback = buildMessageInsertPayload(
            conversationId: conversationId,
            senderId: _currentUserId!,
            content: content.isNotEmpty
                ? content
                : (mediaFileName ?? 'Document'),
            mediaUrl: mediaUrl,
          );
          try {
            final response = await _supabase
                .from('messages')
                .insert(fallback)
                .select()
                .single();
            if (kDebugMode) {
              debugPrint(
                '[MSG_SEND_INSERT_SUCCESS] messageId=${response['id']} '
                '(documentFallback)',
              );
            }
            return {
              ...response,
              'media_kind': 'document',
              'media_file_name': mediaFileName,
              'media_mime_type': mediaMimeType,
              'media_size_bytes': mediaSizeBytes,
            };
          } catch (e2, s2) {
            if (kDebugMode) {
              if (e2 is PostgrestException) {
                debugPrint(
                  '[MSG_SEND_POSTGREST_ERROR] stage=documentFallback '
                  'code=${e2.code} message=${e2.message} '
                  'details=${e2.details} hint=${e2.hint}',
                );
              } else {
                debugPrint(
                  '[MSG_SEND_ERROR] stage=documentFallback '
                  'runtimeType=${e2.runtimeType} exception=$e2\n$s2',
                );
              }
              debugPrint('Error sending document fallback: $e2');
            }
            rethrow;
          }
        }
        rethrow;
      }
    } on PostgrestException catch (e, s) {
      if (kDebugMode) {
        debugPrint(
          '[MSG_SEND_POSTGREST_ERROR] code=${e.code} message=${e.message} '
          'details=${e.details} hint=${e.hint}\n$s',
        );
      }
      // Attachments need the real error in the UI; text keeps soft-fail.
      if (mediaUrl != null) rethrow;
      return null;
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint(
          '[MSG_SEND_ERROR] runtimeType=${e.runtimeType} exception=$e\n$s',
        );
        debugPrint('Error sending message: $e');
      }
      // Attachments need the real error in the UI; text keeps soft-fail.
      if (mediaUrl != null) rethrow;
      return null;
    }
  }

  /// Marks the other participant's messages read on the server.
  ///
  /// The caller must be able to tell a real write apart from a silent no-op:
  /// `read_at` can only be set by `mark_conversation_messages_read`, because
  /// the broad UPDATE policy on `public.messages` was dropped. If that RPC is
  /// absent or fails, the badge must NOT be presented as permanently cleared.
  Future<MarkReadOutcome> markConversationRead(String conversationId) async {
    if (_currentUserId == null) return MarkReadOutcome.failed;

    try {
      await _supabase.rpc(
        'mark_conversation_messages_read',
        params: {'p_conversation_id': conversationId},
      );
      return MarkReadOutcome.success;
    } catch (e) {
      if (_isMissingRpc(e)) {
        if (kDebugMode) {
          debugPrint('markConversationRead: RPC not deployed');
        }
        return MarkReadOutcome.unsupported;
      }
      if (kDebugMode) debugPrint('markConversationRead failed: $e');
      return MarkReadOutcome.failed;
    }
  }

  /// Narrow detection of "the function is not deployed".
  ///
  /// Deliberately does not treat every `PGRST*` code as missing: PGRST301 is an
  /// expired JWT and PGRST116 is an empty result, and swallowing those as
  /// "nothing to mark" is what let read state silently never persist.
  bool _isMissingRpc(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST202') return true;
      final msg = e.message.toLowerCase();
      return msg.contains('could not find the function') ||
          msg.contains('does not exist');
    }
    return false;
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
  RealtimeChannel subscribeToConversations(
    Function(Map<String, dynamic>) onConversationUpdate,
  ) {
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
    if (kDebugMode) {
      debugPrint(
        '[MSG_OPEN_START] authUid=$_currentUserId '
        'p_other_user_id=$otherUserId',
      );
    }
    if (_currentUserId == null) return null;
    if (_currentUserId == otherUserId) return null;

    try {
      final result = await _supabase.rpc(
        'create_or_find_provider_client_conversation',
        params: {'p_other_user_id': otherUserId},
      );
      String? parsed;
      if (result is String && result.isNotEmpty) {
        parsed = result;
      } else if (result != null) {
        final asString = result.toString();
        if (asString.isNotEmpty && asString != 'null') parsed = asString;
      }
      if (kDebugMode) {
        debugPrint(
          '[MSG_OPEN_RPC_RESULT] raw=$result '
          'rawRuntimeType=${result?.runtimeType} '
          'parsedConversationId=$parsed',
        );
      }
      return parsed;
    } on PostgrestException catch (e, s) {
      if (kDebugMode) {
        debugPrint(
          '[MSG_OPEN_POSTGREST_ERROR] code=${e.code} message=${e.message} '
          'details=${e.details} hint=${e.hint}\n$s',
        );
      }
      return null;
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint(
          '[MSG_OPEN_ERROR] runtimeType=${e.runtimeType} exception=$e\n$s',
        );
        debugPrint('createOrFindConversation: failed (need accepted lead): $e');
      }
      return null;
    }
  }
}
