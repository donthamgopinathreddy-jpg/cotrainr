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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightBlueBg = isDark
        ? Color.lerp(cs.surface, AppColors.blue, 0.15)!
        : Color.lerp(cs.surface, AppColors.blue, 0.08)!;

    return Scaffold(
      backgroundColor: lightBlueBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.blue, AppColors.cyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.blue, AppColors.cyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
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
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: AppColors.blue.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: AppColors.blue.withOpacity(0.3)),
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
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _filteredConversations.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 76,
                  color: AppColors.blue.withOpacity(0.2),
                ),
                itemBuilder: (context, index) {
                  final item = _filteredConversations[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 200 + (index * 30)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - value)),
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
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    conversationId: item.id,
                                    userName: item.name,
                                    avatarGradient: item.avatarGradient,
                                    isOnline: item.isOnline,
                                    avatarUrl: item.avatarUrl,
                                  ),
                                ),
                              );
                            },
                            onLongPress: () => _deleteConversation(index),
                          ),
                        ),
                      );
                    },
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
