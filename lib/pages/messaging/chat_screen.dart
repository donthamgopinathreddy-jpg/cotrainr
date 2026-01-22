import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../cocircle/user_profile_page.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String userName;
  final LinearGradient avatarGradient;
  final bool isOnline;
  final String? avatarUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.userName,
    required this.avatarGradient,
    this.isOnline = false,
    this.avatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  String? _previewImagePath;
  String? _previewVideoPath;
  bool _isEmojiPickerOpen = false;

  static const List<String> _commonEmojis = [
    // Smileys & People
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
    '😘', '😗', '😙', '😚', '😋', '😛', '😜', '🤪',
    '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨',
    '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
    '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕',
    '🤢', '🤮', '🤧', '🥵', '🥶', '😯', '😲', '😳',
    '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭',
    '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱',
    // Gestures & Body Parts
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙',
    '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💪',
    '🦾', '🦿', '🦵', '🦶', '👂', '🦻', '👃', '🧠',
    '🦷', '🦴', '👀', '👁️', '👅', '👄', '💋', '💘',
    // Hearts
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
    '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉️', '☸️',
    // Hand Gestures
    '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏',
    '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆',
    '🖕', '👇', '☝️', '👍', '👎', '✊', '👊', '🤛',
    '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️',
    // Objects & Symbols
    '🔥', '💯', '⭐', '🌟', '✨', '💫', '💥', '💢',
    '💤', '💨', '👻', '👽', '🤖', '🎃', '😺', '😸',
    '😹', '😻', '😼', '😽', '🙀', '😿', '😾', '💀',
    '☠️', '👹', '👺', '👻', '👽', '👾', '🤖', '🎃',
    // Food & Drink
    '🍎', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈',
    '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆',
    '🥑', '🥦', '🥬', '🥒', '🌶️', '🌽', '🥕', '🥔',
    '🍠', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚',
    '🍳', '🥞', '🥓', '🥩', '🍗', '🍖', '🌭', '🍔',
    '🍟', '🍕', '🥪', '🥙', '🌮', '🌯', '🥗', '🥘',
    '🥫', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟',
    '🍤', '🍙', '🍚', '🍘', '🍥', '🥠', '🥡', '🍢',
    '🍡', '🍧', '🍨', '🍦', '🥧', '🍰', '🎂', '🍮',
    '🍭', '🍬', '🍫', '🍿', '🍩', '🍪', '🌰', '🥜',
    '🍯', '🥛', '🍼', '☕', '🍵', '🧃', '🥤', '🍶',
    '🍺', '🍻', '🥂', '🍷', '🥃', '🍸', '🍹', '🧉',
    '🍾', '🧊',
    // Activities & Sports
    '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉',
    '🥏', '🎱', '🏓', '🏸', '🥅', '🏒', '🏑', '🥍',
    '🏏', '⛳', '🏹', '🎣', '🥊', '🥋', '🎽', '🛹',
    '🛷', '⛸️', '🥌', '🎿', '⛷️', '🏂', '🏋️', '🤼',
    '🤸', '🤺', '🤾', '🤹', '🧘', '🏌️', '🏇', '🧗',
    '🚵', '🚴', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️',
    '🏵️', '🎗️', '🎫', '🎟️', '🎪', '🤹', '🎭', '🩰',
    '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🎷',
    '🎺', '🎸', '🪕', '🎻', '🎲', '♟️', '🎯', '🎳',
    '🎮', '🎰', '🧩',
  ];
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Hey! How can I help you with your fitness journey today?',
      isSent: false,
      time: '2h ago',
    ),
    _ChatMessage(
      text: 'Hi! I\'d like to know more about the workout plan.',
      isSent: true,
      time: '2h ago',
    ),
    _ChatMessage(
      text: 'Great progress on your workouts! Keep it up.',
      isSent: false,
      time: '2h ago',
    ),
    _ChatMessage(
      text: 'Thanks! I\'ve been following the routine consistently.',
      isSent: true,
      time: '1h ago',
    ),
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _previewImagePath == null && _previewVideoPath == null) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isSent: true,
          time: 'Just now',
          imagePath: _previewImagePath,
          videoPath: _previewVideoPath,
        ),
      );
    });

    // Haptic feedback for sent message
    HapticFeedback.selectionClick();

    _messageController.clear();
    _clearPreview();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _previewImagePath = image.path;
          _previewVideoPath = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video != null) {
        setState(() {
          _previewVideoPath = video.path;
          _previewImagePath = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  void _showAttachmentMenu() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Color.lerp(Colors.black, AppColors.blue, 0.2)!
        : Color.lerp(Colors.white, AppColors.blue, 0.15)!;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image_outlined, color: cs.onSurface),
              title: Text('Image', style: TextStyle(color: cs.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam_outlined, color: cs.onSurface),
              title: Text('Video', style: TextStyle(color: cs.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearPreview() {
    setState(() {
      _previewImagePath = null;
      _previewVideoPath = null;
    });
  }

  void _toggleEmojiPicker() {
    if (_isEmojiPickerOpen) {
      Navigator.pop(context);
      setState(() => _isEmojiPickerOpen = false);
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Color.lerp(Colors.black, AppColors.blue, 0.2)!
        : Color.lerp(Colors.white, AppColors.blue, 0.15)!;
    
    setState(() => _isEmojiPickerOpen = true);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 350,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _commonEmojis.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      _insertEmoji(_commonEmojis[index]);
                    },
                    child: Center(
                      child: Text(
                        _commonEmojis[index],
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isEmojiPickerOpen = false);
      }
    });
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }


  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report User'),
          content: const Text('Are you sure you want to report this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User reported successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                'Report',
                style: TextStyle(color: AppColors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteOptions(BuildContext context, int index) {
    // Haptic feedback when long press triggers delete options
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                setState(() {
                  _messages.removeAt(index);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message deleted for you'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.red),
              title: const Text('Delete for everyone', style: TextStyle(color: AppColors.red)),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                setState(() {
                  _messages.removeAt(index);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message deleted for everyone'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightBlueBg = isDark
        ? Color.lerp(Colors.black, AppColors.blue, 0.2)!
        : Color.lerp(cs.surface, AppColors.blue, 0.08)!;

    return Scaffold(
      backgroundColor: lightBlueBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: cs.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      isOwnProfile: false,
                      userId: widget.conversationId,
                      userName: widget.userName,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: widget.avatarUrl == null
                          ? const LinearGradient(
                              colors: [AppColors.blue, AppColors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: widget.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              widget.avatarUrl!,
                              width: 40,
                              height: 40,
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
                                      size: 22,
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
                              size: 22,
                            ),
                          ),
                  ),
                if (widget.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (widget.isOnline)
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurface),
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, color: AppColors.red, size: 20),
                    const SizedBox(width: 12),
                    const Text('Report'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(
                  message: message,
                  onLongPress: message.isSent
                      ? () => _showDeleteOptions(context, index)
                      : null,
                );
              },
            ),
          ),
          // Preview
          if (_previewImagePath != null || _previewVideoPath != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 60,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _previewImagePath != null
                        ? Image.file(
                            File(_previewImagePath!),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.blue.withOpacity(0.3),
                                  AppColors.cyan.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: _clearPreview,
                    ),
                  ),
                ],
              ),
            ),
          // Message input
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isEmojiPickerOpen
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 100),
                            child: TextField(
                              controller: _messageController,
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              cursorColor: AppColors.blue,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                prefixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _HapticIconButton(
                                      icon: Icons.emoji_emotions_outlined,
                                      color: _isEmojiPickerOpen ? AppColors.blue : cs.onSurfaceVariant,
                                      size: 20,
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        FocusScope.of(context).unfocus();
                                        _toggleEmojiPicker();
                                      },
                                    ),
                                    Transform.translate(
                                      offset: const Offset(-8, 0),
                                      child: _HapticIconButton(
                                        icon: Icons.attach_file,
                                        color: cs.onSurfaceVariant,
                                        size: 20,
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          FocusScope.of(context).unfocus();
                                          _showAttachmentMenu();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: AppColors.blue.withOpacity(0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(color: AppColors.blue.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(color: AppColors.blue, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.waterGradient,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _sendMessage();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HapticIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  const _HapticIconButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onPressed,
  });

  @override
  State<_HapticIconButton> createState() => _HapticIconButtonState();
}

class _HapticIconButtonState extends State<_HapticIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          widget.icon,
          color: widget.color,
          size: widget.size,
        ),
        onPressed: _handleTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 20,
          minHeight: 20,
        ),
        splashRadius: 18,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isSent;
  final String time;
  final String? imagePath;
  final String? videoPath;
  final String id;

  _ChatMessage({
    required this.text,
    required this.isSent,
    required this.time,
    this.imagePath,
    this.videoPath,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class _ChatBubble extends StatefulWidget {
  final _ChatMessage message;
  final VoidCallback? onLongPress;

  const _ChatBubble({required this.message, this.onLongPress});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    // Trigger haptic for received messages when they first appear
    if (!widget.message.isSent && !_hasTriggeredHaptic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          HapticFeedback.lightImpact();
          _hasTriggeredHaptic = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: widget.message.isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: widget.message.isSent ? widget.onLongPress : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: widget.message.isSent ? AppColors.waterGradient : null,
          color: widget.message.isSent
              ? null
              : AppColors.blue.withOpacity(0.15),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(widget.message.isSent ? 20 : 4),
            bottomRight: Radius.circular(widget.message.isSent ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message.imagePath != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(widget.message.imagePath!),
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (widget.message.text.isEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            if (widget.message.videoPath != null)
              Stack(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.blue.withOpacity(0.3),
                          AppColors.cyan.withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.message.text.isEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            if (widget.message.text.isNotEmpty) ...[
              if (widget.message.imagePath != null || widget.message.videoPath != null)
                const SizedBox(height: 8),
              Text(
                widget.message.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: widget.message.isSent ? Colors.white : cs.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              widget.message.time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: widget.message.isSent
                    ? Colors.white.withOpacity(0.7)
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
