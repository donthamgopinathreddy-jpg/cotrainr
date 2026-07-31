import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/app_tab_page_header.dart';
import '../../widgets/common/fade_slide_in.dart';
import '../../repositories/messages_repository.dart';
import 'chat_screen.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final TextEditingController _searchController = TextEditingController();
  final MessagesRepository _messagesRepo = MessagesRepository();
  final List<_ConversationItem> _allConversations = [];
  List<_ConversationItem> _filteredConversations = [];
  _ConversationItem? _deletedConversation;
  int? _deletedIndex;
  bool _isLoading = true;
  RealtimeChannel? _conversationsChannel;

  @override
  void initState() {
    super.initState();
    _filteredConversations = _allConversations;
    _searchController.addListener(_filterConversations);
    _loadConversations();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterConversations);
    _searchController.dispose();
    _conversationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final conversations = await _messagesRepo.fetchConversations();
      final List<_ConversationItem> items = [];

      for (final convData in conversations) {
        final conv = convData['conversation'] as Map<String, dynamic>;
        final lastMessage = convData['lastMessage'] as Map<String, dynamic>?;
        final unreadCount = convData['unreadCount'] as int? ?? 0;
        final otherUser = convData['otherUser'] as Map<String, dynamic>?;
        final updatedAt = convData['updatedAt'] as String?;

        if (otherUser == null) continue;

        final name = otherUser['full_name'] as String? ?? 
                    otherUser['username'] as String? ?? 
                    'Unknown User';
        final avatarUrl = otherUser['avatar_url'] as String?;
        final lastMessageText = lastMessage?['content'] as String? ?? 'No messages yet';
        final time = _formatTime(updatedAt ?? lastMessage?['created_at'] as String?);

        // Generate gradient based on name hash for consistency
        final gradient = _getGradientForName(name);

        items.add(_ConversationItem(
          id: conv['id'] as String,
          name: name,
          lastMessage: lastMessageText,
          time: time,
          unreadCount: unreadCount,
          avatarGradient: gradient,
          isOnline: false, // TODO: Implement online status
          avatarUrl: avatarUrl,
        ));
      }

      if (mounted) {
        setState(() {
          _allConversations.clear();
          _allConversations.addAll(items);
          _filteredConversations = _allConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    _conversationsChannel = _messagesRepo.subscribeToConversations((update) {
      if (!mounted) return;
      _loadConversations();
    });
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return '1d ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return DateFormat('MMM d').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  LinearGradient _getGradientForName(String name) {
    final hash = name.hashCode;
    final gradients = [
      LinearGradient(colors: [AppColors.orange, AppColors.pink], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [AppColors.blue, AppColors.cyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [AppColors.green, Color(0xFF65E6B3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [AppColors.purple, Color(0xFFB38CFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      LinearGradient(colors: [AppColors.orange, AppColors.yellow], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ];
    return gradients[hash.abs() % gradients.length];
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _allConversations;
      } else {
        _filteredConversations = _allConversations
            .where((conv) => conv.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _deleteConversation(int index) {
    final conversationToDelete = _filteredConversations[index];
    final originalIndex = _allConversations.indexOf(conversationToDelete);

    setState(() {
      _deletedConversation = conversationToDelete;
      _deletedIndex = originalIndex;
      _allConversations.removeAt(originalIndex);
      _filteredConversations = _allConversations
          .where((conv) {
            if (_searchController.text.isEmpty) return true;
            return conv.name.toLowerCase().contains(_searchController.text.toLowerCase());
          })
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Conversation deleted',
          style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: DesignTokens.accentOrange,
          onPressed: () {
            if (!mounted) return;
            if (_deletedConversation != null && _deletedIndex != null) {
              setState(() {
                _allConversations.insert(_deletedIndex!, _deletedConversation!);
                _filteredConversations = _allConversations
                    .where((conv) {
                      if (_searchController.text.isEmpty) return true;
                      return conv.name.toLowerCase().contains(_searchController.text.toLowerCase());
                    })
                    .toList();
                _deletedConversation = null;
                _deletedIndex = null;
              });
            }
          },
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Clear deleted conversation after snackbar duration
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _deletedConversation = null;
          _deletedIndex = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pageBg = DesignTokens.backgroundOf(context);
    final searchFill = DesignTokens.surfaceOf(context);
    final searchBorder = DesignTokens.borderColorOf(context);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppTabPageHeader(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Messages',
              gradient: AppTabPageHeader.messagesGradient,
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _searchController,
                cursorColor: AppColors.blue,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: cs.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: searchFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: searchBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: searchBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.blue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: ContentFade(
                loading: _isLoading,
                loadingChild: const Center(
                  child: CircularProgressIndicator(),
                ),
                child: RefreshIndicator(
                  color: DesignTokens.accentOrange,
                  backgroundColor: DesignTokens.surfaceOf(context),
                  onRefresh: () => _loadConversations(showLoading: false),
                  child: _filteredConversations.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.35,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 64,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No conversations yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start a conversation with your trainer or nutritionist',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: EdgeInsets.zero,
                          itemCount: _filteredConversations.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 76,
                            color: AppColors.blue.withOpacity(0.2),
                          ),
                          itemBuilder: (context, index) {
                            final item = _filteredConversations[index];
                  return FadeSlideIn(
                    index: index,
                    child: _ConversationTile(
                            item: item,
                            onTap: () async {
                              // Mark messages as read when opening chat
                              final originalIndex = _allConversations.indexOf(item);
                              if (originalIndex != -1 && _allConversations[originalIndex].unreadCount > 0) {
                                setState(() {
                                  _allConversations[originalIndex] = _ConversationItem(
                                    id: _allConversations[originalIndex].id,
                                    name: _allConversations[originalIndex].name,
                                    lastMessage: _allConversations[originalIndex].lastMessage,
                                    time: _allConversations[originalIndex].time,
                                    unreadCount: 0,
                                    avatarGradient: _allConversations[originalIndex].avatarGradient,
                                    isOnline: _allConversations[originalIndex].isOnline,
                                    avatarUrl: _allConversations[originalIndex].avatarUrl,
                                  );
                                  _filterConversations();
                                });
                              }
                              
                              await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondary) =>
                                      ChatScreen(
                                    conversationId: item.id,
                                    userName: item.name,
                                    avatarGradient: item.avatarGradient,
                                    isOnline: item.isOnline,
                                    avatarUrl: item.avatarUrl,
                                  ),
                                  transitionsBuilder:
                                      (context, animation, secondary, child) {
                                    final curved = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    );
                                    return FadeTransition(
                                      opacity: curved,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.04, 0),
                                          end: Offset.zero,
                                        ).animate(curved),
                                        child: child,
                                      ),
                                    );
                                  },
                                  transitionDuration:
                                      const Duration(milliseconds: 260),
                                  reverseTransitionDuration:
                                      const Duration(milliseconds: 220),
                                ),
                              );
                            },
                            onLongPress: () => _deleteConversation(index),
                          ),
                        );
                },
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final _ConversationItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: item.avatarUrl == null
                        ? const LinearGradient(
                            colors: [AppColors.blue, AppColors.cyan],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: item.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            item.avatarUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.blue, AppColors.cyan],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                ),
                if (item.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${item.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Text(
                          item.time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.lastMessage,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                      color: item.unreadCount > 0 ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationItem {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final LinearGradient avatarGradient;
  final bool isOnline;
  final String? avatarUrl;

  _ConversationItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.avatarGradient,
    this.isOnline = false,
    this.avatarUrl,
  });
}
