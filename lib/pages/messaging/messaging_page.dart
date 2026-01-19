import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import 'chat_screen.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<_ConversationItem> _allConversations = [
    _ConversationItem(
      id: '1',
      name: 'Coach Mia',
      lastMessage: 'Great progress on your workouts! Keep it up.',
      time: '2h ago',
      unreadCount: 2,
      avatarGradient: LinearGradient(
        colors: [AppColors.orange, AppColors.pink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      isOnline: true,
    ),
    _ConversationItem(
      id: '2',
      name: 'Trainer Alex',
      lastMessage: 'Here\'s your updated meal plan.',
      time: '1d ago',
      unreadCount: 0,
      avatarGradient: LinearGradient(
        colors: [AppColors.blue, AppColors.cyan],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      isOnline: false,
    ),
    _ConversationItem(
      id: '3',
      name: 'Nutritionist Sarah',
      lastMessage: 'Your weekly report is ready.',
      time: '2d ago',
      unreadCount: 1,
      avatarGradient: LinearGradient(
        colors: [AppColors.green, Color(0xFF65E6B3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      isOnline: true,
    ),
    _ConversationItem(
      id: '4',
      name: 'Support Team',
      lastMessage: 'Thank you for your feedback!',
      time: '3d ago',
      unreadCount: 0,
      avatarGradient: LinearGradient(
        colors: [AppColors.purple, Color(0xFFB38CFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      isOnline: false,
    ),
    _ConversationItem(
      id: '5',
      name: 'Fitness Group',
      lastMessage: 'John shared a new workout routine.',
      time: '1w ago',
      unreadCount: 0,
      avatarGradient: LinearGradient(
        colors: [AppColors.orange, AppColors.yellow],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      isOnline: false,
    ),
  ];

  List<_ConversationItem> _filteredConversations = [];
  _ConversationItem? _deletedConversation;
  int? _deletedIndex;

  @override
  void initState() {
    super.initState();
    _filteredConversations = _allConversations;
    _searchController.addListener(_filterConversations);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterConversations);
    _searchController.dispose();
    super.dispose();
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
        content: const Text('Conversation deleted'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
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
        backgroundColor: AppColors.surface,
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

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.blue, AppColors.cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Search bar with gradient
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.blue, AppColors.cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Colors.white.withOpacity(0.9),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _filteredConversations.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 76,
                  color: cs.surfaceContainerHighest,
                ),
                itemBuilder: (context, index) {
                  final item = _filteredConversations[index];
                  return _ConversationTile(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: item.id,
                            userName: item.name,
                            avatarGradient: item.avatarGradient,
                            isOnline: item.isOnline,
                          ),
                        ),
                      );
                    },
                    onLongPress: () => _deleteConversation(index),
                  );
                },
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
                    gradient: item.avatarGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      item.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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

  _ConversationItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.avatarGradient,
    this.isOnline = false,
  });
}
