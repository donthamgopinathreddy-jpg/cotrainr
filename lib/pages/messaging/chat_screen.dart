import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../models/user_safety_models.dart';
import '../../repositories/messages_repository.dart';
import '../../services/storage_service.dart';
import '../../services/messaging_policy_service.dart';
import '../../services/user_safety_service.dart';
import '../../providers/unread_messages_count_provider.dart';
import '../../utils/chat_attachment_rules.dart';
import '../../utils/chat_message_reconciler.dart';
import '../../services/chat_media_storage.dart';
import '../../widgets/common/app_overlays.dart';
import '../../widgets/messaging/report_user_sheet.dart';
import '../../widgets/provider/provider_avatar.dart';
import '../profile/public_profile_readonly_page.dart';
import 'chat_image_viewer_page.dart';

class ChatScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final MessagesRepository _messagesRepo = MessagesRepository();
  final StorageService _storageService = StorageService();
  final UserSafetyService _safetyService = UserSafetyService();
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _previewImagePath;
  String? _previewVideoPath;
  String? _previewDocumentPath;
  String? _previewDocumentName;
  String? _previewDocumentMime;
  int? _previewDocumentSize;
  bool _attachmentBusy = false;
  bool _isLoading = true;
  RealtimeChannel? _messagesChannel;
  String? _otherUserId;
  bool _canSend = true;
  BlockState _blockState = BlockState.none;
  bool _safetyBusy = false;
  Map<String, dynamic>? _conversationRow;

  final List<_ChatMessage> _messages = [];
  final ChatMessageReconciler _reconciler = ChatMessageReconciler();

  void _syncMessagesFromReconciler() {
    _messages
      ..clear()
      ..addAll(
        _reconciler.messages.map(
          (m) => _ChatMessage(
            text: m.text,
            isSent: m.isSent,
            time: m.time,
            messageId: m.messageId,
            localId: m.localId,
            imagePath: m.imagePath,
            videoPath: m.videoPath,
            imageUrl: m.imageUrl,
            videoUrl: m.videoUrl,
            documentPath: m.documentPath,
            documentUrl: m.documentUrl,
            documentName: m.documentName,
            documentMime: m.documentMime,
            documentSizeBytes: m.documentSizeBytes,
            uploadStatus: m.uploadStatus,
            uploadProgress: m.uploadProgress,
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadConversationAccess();
    if (!mounted) return;
    await _loadMessages();
    _setupRealtimeSubscription();
    _markMessagesAsRead();
  }

  Future<void> _loadConversationAccess() async {
    final row = await _messagesRepo.fetchConversationById(widget.conversationId);
    if (!mounted) return;
    if (row == null) {
      setState(() {
        _conversationRow = null;
        _otherUserId = null;
        _canSend = false;
        _blockState = BlockState.none;
      });
      return;
    }
    final me = _supabase.auth.currentUser?.id;
    final other = me != null ? MessagingPolicyService.otherParticipantUserId(row, me) : null;
    final canSend = me != null
        ? await MessagingPolicyService.canCurrentUserSendMessage(
            supabase: _supabase,
            conversation: row,
          )
        : false;
    BlockState block = BlockState.none;
    if (other != null) {
      block = await _safetyService.getBlockState(other);
    }
    if (!mounted) return;
    setState(() {
      _conversationRow = row;
      _otherUserId = other;
      _blockState = block;
      _canSend = canSend && !block.eitherBlocked;
    });
  }

  _ParsedMedia _parseMediaFields(Map<String, dynamic> msg) {
    final mediaUrl = msg['media_url'] as String?;
    final mediaKind = (msg['media_kind'] as String?)?.toLowerCase();
    final mediaFileName = msg['media_file_name'] as String?;
    final mediaMime = msg['media_mime_type'] as String?;
    final mediaSizeRaw = msg['media_size_bytes'];
    final mediaSizeBytes = mediaSizeRaw is int
        ? mediaSizeRaw
        : (mediaSizeRaw is num ? mediaSizeRaw.toInt() : null);

    if (mediaUrl == null || mediaUrl.isEmpty) {
      return const _ParsedMedia();
    }

    final nameHint = mediaFileName ?? mediaUrl;
    final looksLikeDoc = ChatAttachmentRules.isAllowedDocument(
      nameHint,
      mimeType: mediaMime,
    );
    final looksLikeImage = ChatAttachmentRules.isAllowedImage(
      nameHint,
      mimeType: mediaMime,
    );

    if (mediaKind == 'document' ||
        (mediaKind != 'image' &&
            mediaKind != 'video' &&
            looksLikeDoc &&
            !looksLikeImage)) {
      return _ParsedMedia(
        documentUrl: mediaUrl,
        documentName: mediaFileName ?? path.basename(Uri.tryParse(mediaUrl)?.path ?? mediaUrl),
        documentMime: mediaMime ?? ChatAttachmentRules.mimeForPath(nameHint),
        documentSizeBytes: mediaSizeBytes,
      );
    }

    // Legacy rows: URL extension looks like a document (fallback insert without media_kind).
    if ((mediaKind == null || mediaKind.isEmpty) && looksLikeDoc) {
      return _ParsedMedia(
        documentUrl: mediaUrl,
        documentName: mediaFileName ?? path.basename(Uri.tryParse(mediaUrl)?.path ?? mediaUrl),
        documentMime: mediaMime ?? ChatAttachmentRules.mimeForPath(nameHint),
        documentSizeBytes: mediaSizeBytes,
      );
    }

    if (mediaKind == 'video') {
      return _ParsedMedia(videoUrl: mediaUrl);
    }

    if (mediaKind == 'image' ||
        looksLikeImage ||
        (mediaMime != null && mediaMime.toLowerCase().startsWith('image/'))) {
      return _ParsedMedia(imageUrl: mediaUrl);
    }

    if (mediaKind == null &&
        mediaUrl.toLowerCase().contains('.mp4')) {
      return _ParsedMedia(videoUrl: mediaUrl);
    }

    // Default unknown media with URL to image (legacy behavior), unless doc mime/name won above.
    return _ParsedMedia(imageUrl: mediaUrl);
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final messages = await _messagesRepo.fetchMessages(widget.conversationId);
      final currentUserId = _supabase.auth.currentUser?.id;

      final loaded = <ReconciledChatMessage>[];
      for (final msg in messages) {
        final senderId = msg['sender_id'] as String;
        final isSent = senderId == currentUserId;
        final content = msg['content'] as String? ?? '';
        final createdAt = msg['created_at'] as String?;
        final time = _formatTime(createdAt);
        final resolved = await ChatMediaStorage.resolveMessageMedia(
          _supabase,
          msg,
        );
        final media = _parseMediaFields(resolved);

        loaded.add(
          ReconciledChatMessage(
            text: content,
            isSent: isSent,
            time: time,
            messageId: msg['id'] as String?,
            imageUrl: media.imageUrl,
            videoUrl: media.videoUrl,
            documentUrl: media.documentUrl,
            documentName: media.documentName,
            documentMime: media.documentMime,
            documentSizeBytes: media.documentSizeBytes,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _reconciler.replaceAll(loaded);
          _syncMessagesFromReconciler();
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    _messagesChannel =
        _messagesRepo.subscribeToMessages(widget.conversationId, (newMessage) {
      () async {
        final currentUserId = _supabase.auth.currentUser?.id;
        final senderId = newMessage['sender_id'] as String;
        final isSent = senderId == currentUserId;
        final content = newMessage['content'] as String? ?? '';
        final createdAt = newMessage['created_at'] as String?;
        final time = _formatTime(createdAt);
        final messageId = newMessage['id'] as String?;

        if (!mounted || messageId == null || messageId.isEmpty) return;

        final resolved = await ChatMediaStorage.resolveMessageMedia(
          _supabase,
          newMessage,
        );
        if (!mounted) return;
        final media = _parseMediaFields(resolved);
        final added = _reconciler.upsertCanonical(
          messageId: messageId,
          text: content,
          isSent: isSent,
          time: time,
          imageUrl: media.imageUrl,
          videoUrl: media.videoUrl,
          documentUrl: media.documentUrl,
          documentName: media.documentName,
          documentMime: media.documentMime,
          documentSizeBytes: media.documentSizeBytes,
        );
        if (!added) return;

        setState(_syncMessagesFromReconciler);
        _scrollToBottom();
        if (!isSent) {
          _markMessagesAsRead();
        }
      }();
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _messagesRepo.markMessagesAsRead(widget.conversationId);
    } catch (e) {
      print('ChatScreen markMessagesAsRead failed: $e');
    } finally {
      if (mounted) {
        ref.invalidate(unreadMessagesCountProvider);
      }
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Just now';

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
      } else {
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (e) {
      return 'Just now';
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (!_canSend) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sending is disabled. Connect with this provider first, or reopen the chat.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_attachmentBusy) return;

    final text = _messageController.text.trim();
    final hasDocument = _previewDocumentPath != null;
    final hasImage = _previewImagePath != null;
    final hasVideo = _previewVideoPath != null;
    final hasAttachment = hasDocument || hasImage || hasVideo;

    if (text.isEmpty && !hasAttachment) return;

    if (hasAttachment) {
      await _sendAttachmentMessage(
        text: text,
        imagePath: _previewImagePath,
        videoPath: _previewVideoPath,
        documentPath: _previewDocumentPath,
        documentName: _previewDocumentName,
        documentMime: _previewDocumentMime,
        documentSizeBytes: _previewDocumentSize,
      );
      return;
    }

    // Text-only path
    final localId = _reconciler.addOptimistic(
      text: text,
      isSent: true,
      time: 'Just now',
    );
    setState(_syncMessagesFromReconciler);

    HapticFeedback.selectionClick();

    _messageController.clear();
    _clearPreview();
    _scrollToBottom();

    try {
      final sent = await _messagesRepo.sendMessage(
        conversationId: widget.conversationId,
        content: text,
      );
      if (!mounted) return;
      if (sent == null) {
        setState(() {
          _reconciler.removeOptimistic(localId);
          _syncMessagesFromReconciler();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send message. Check your connection or try again.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final sentId = sent['id'] as String?;
      final createdAt = sent['created_at'] as String?;
      if (sentId != null && sentId.isNotEmpty) {
        setState(() {
          _reconciler.confirmOptimistic(
            localId: localId,
            messageId: sentId,
            text: text,
            isSent: true,
            time: _formatTime(createdAt),
          );
          _syncMessagesFromReconciler();
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        setState(() {
          _reconciler.removeOptimistic(localId);
          _syncMessagesFromReconciler();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendAttachmentMessage({
    required String text,
    String? imagePath,
    String? videoPath,
    String? documentPath,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
    String? existingLocalId,
  }) async {
    if (_attachmentBusy) return;

    final isDocument = documentPath != null;
    final isImage = imagePath != null;
    final isVideo = videoPath != null;
    if (!isDocument && !isImage && !isVideo) return;

    final mediaKind = isDocument ? 'document' : (isImage ? 'image' : 'video');
    final filePath = documentPath ?? imagePath ?? videoPath!;
    final displayName = documentPath != null
        ? (documentName ?? path.basename(documentPath))
        : path.basename(filePath);
    final content = isDocument
        ? displayName
        : (text.isNotEmpty ? text : '');
    final mime = documentMime ??
        ChatAttachmentRules.mimeForPath(displayName) ??
        ChatAttachmentRules.mimeForPath(filePath);

    setState(() => _attachmentBusy = true);

    String localId;
    if (existingLocalId != null) {
      localId = existingLocalId;
      _reconciler.updateOptimistic(
        localId,
        uploadStatus: ChatUploadStatus.uploading,
        uploadProgress: 0,
      );
      setState(_syncMessagesFromReconciler);
    } else {
      localId = _reconciler.addOptimistic(
        text: content,
        isSent: true,
        time: 'Just now',
        imagePath: imagePath,
        videoPath: videoPath,
        documentPath: documentPath,
        documentName: isDocument ? displayName : null,
        documentMime: isDocument ? mime : null,
        documentSizeBytes: documentSizeBytes,
        uploadStatus: ChatUploadStatus.uploading,
      );
      setState(_syncMessagesFromReconciler);
      HapticFeedback.selectionClick();
      _messageController.clear();
      _clearPreview();
      _scrollToBottom();
    }

    try {
      final file = File(filePath);
      final sizeBytes = documentSizeBytes ?? await file.length();

      final mediaUrl = await _storageService.uploadChatMedia(
        file,
        mediaKind: mediaKind,
        conversationId: widget.conversationId,
        originalFileName: displayName,
        contentType: mime,
        onProgress: (p) {
          if (!mounted) return;
          _reconciler.updateOptimistic(localId, uploadProgress: p);
          setState(_syncMessagesFromReconciler);
        },
      );

      if (mediaUrl == null) {
        throw Exception('Upload returned null URL');
      }

      final sent = await _messagesRepo.sendMessage(
        conversationId: widget.conversationId,
        content: content,
        mediaUrl: mediaUrl,
        mediaKind: mediaKind,
        mediaFileName: displayName,
        mediaMimeType: mime,
        mediaSizeBytes: sizeBytes,
      );

      if (!mounted) return;

      if (sent == null) {
        setState(() {
          _reconciler.updateOptimistic(
            localId,
            uploadStatus: ChatUploadStatus.failed,
          );
          _syncMessagesFromReconciler();
          _attachmentBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send message. Check your connection or try again.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final sentId = sent['id'] as String?;
      final createdAt = sent['created_at'] as String?;
      final sentMediaUrl = sent['media_url'] as String? ?? mediaUrl;
      final resolvedSent = await ChatMediaStorage.resolveMessageMedia(
        _supabase,
        {
          ...sent,
          'media_url': sentMediaUrl,
          'media_kind': sent['media_kind'] ?? mediaKind,
          'media_file_name': sent['media_file_name'] ?? displayName,
          'media_mime_type': sent['media_mime_type'] ?? mime,
          'media_size_bytes': sent['media_size_bytes'] ?? sizeBytes,
        },
      );
      final parsed = _parseMediaFields(resolvedSent);

      if (sentId != null && sentId.isNotEmpty) {
        setState(() {
          _reconciler.confirmOptimistic(
            localId: localId,
            messageId: sentId,
            text: content,
            isSent: true,
            time: _formatTime(createdAt),
            imageUrl: parsed.imageUrl,
            videoUrl: parsed.videoUrl,
            documentUrl: parsed.documentUrl,
            documentName: parsed.documentName,
            documentMime: parsed.documentMime,
            documentSizeBytes: parsed.documentSizeBytes,
          );
          _syncMessagesFromReconciler();
          _attachmentBusy = false;
        });
      } else {
        setState(() => _attachmentBusy = false);
      }
    } catch (e) {
      print('Error sending attachment: $e');
      if (mounted) {
        setState(() {
          _reconciler.updateOptimistic(
            localId,
            uploadStatus: ChatUploadStatus.failed,
          );
          _syncMessagesFromReconciler();
          _attachmentBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        _attachmentBusy = false;
      }
    }
  }

  Future<void> _retryUpload(_ChatMessage msg) async {
    final localId = msg.localId;
    if (localId == null || _attachmentBusy) return;

    final imagePath = msg.imagePath;
    final videoPath = msg.videoPath;
    final documentPath = msg.documentPath;
    if (imagePath == null && videoPath == null && documentPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot retry: original file is unavailable.')),
        );
      }
      return;
    }

    await _sendAttachmentMessage(
      text: msg.text,
      imagePath: imagePath,
      videoPath: videoPath,
      documentPath: documentPath,
      documentName: msg.documentName,
      documentMime: msg.documentMime,
      documentSizeBytes: msg.documentSizeBytes,
      existingLocalId: localId,
    );
  }

  Future<void> _pickGallery() async {
    try {
      // Direct system photo/video gallery (not the file-manager media picker).
      final XFile? media = await _imagePicker.pickMedia(
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (media == null) return;

      final filePath = media.path;
      final mime = (media.mimeType ?? '').toLowerCase();
      final ext = path.extension(filePath).toLowerCase();
      final isVideo = mime.startsWith('video/') ||
          {'.mp4', '.mov', '.m4v', '.webm', '.avi'}.contains(ext);

      if (isVideo) {
        final length = await File(filePath).length();
        if (length > ChatAttachmentRules.maxDocumentBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File is too large. Maximum video size is 20 MB.'),
              ),
            );
          }
          return;
        }
        setState(() {
          _previewVideoPath = filePath;
          _previewImagePath = null;
          _previewDocumentPath = null;
          _previewDocumentName = null;
          _previewDocumentMime = null;
          _previewDocumentSize = null;
        });
        return;
      }

      if (!ChatAttachmentRules.isAllowedImage(filePath, mimeType: media.mimeType)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported media type.')),
          );
        }
        return;
      }

      final length = await File(filePath).length();
      if (length > ChatAttachmentRules.maxImageBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File is too large. Maximum image size is 10 MB.'),
            ),
          );
        }
        return;
      }

      setState(() {
        _previewImagePath = filePath;
        _previewVideoPath = null;
        _previewDocumentPath = null;
        _previewDocumentName = null;
        _previewDocumentMime = null;
        _previewDocumentSize = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening gallery: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'csv',
        ],
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final name = picked.name.isNotEmpty ? picked.name : 'document';
      var filePath = picked.path;

      // Some Android providers return no path — write bytes to a temp file.
      if ((filePath == null || filePath.isEmpty) && picked.bytes != null) {
        final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final tmp = File(
          '${Directory.systemTemp.path}/cotrainr_chat_${DateTime.now().millisecondsSinceEpoch}_$safe',
        );
        await tmp.writeAsBytes(picked.bytes!, flush: true);
        filePath = tmp.path;
      }

      if (filePath == null || filePath.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access the selected file.')),
          );
        }
        return;
      }

      final mime = ChatAttachmentRules.mimeForPath(name) ??
          ChatAttachmentRules.mimeForPath(filePath);

      if (ChatAttachmentRules.isBlockedExtension(name) ||
          ChatAttachmentRules.isBlockedExtension(filePath)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That file type is not allowed.')),
          );
        }
        return;
      }

      if (!ChatAttachmentRules.isAllowedDocument(name, mimeType: mime) &&
          !ChatAttachmentRules.isAllowedDocument(filePath, mimeType: mime)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unsupported document type. Try PDF, Word, Excel, PowerPoint, TXT, or CSV.',
              ),
            ),
          );
        }
        return;
      }

      final size = picked.size > 0
          ? picked.size
          : await File(filePath).length();
      if (size > ChatAttachmentRules.maxDocumentBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File is too large. Maximum document size is 20 MB.'),
            ),
          );
        }
        return;
      }

      setState(() {
        _previewDocumentPath = filePath;
        _previewDocumentName = name;
        _previewDocumentMime = mime ?? ChatAttachmentRules.mimeForPath(name);
        _previewDocumentSize = size;
        _previewImagePath = null;
        _previewVideoPath = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking document: $e')),
        );
      }
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
              leading: Icon(Icons.photo_library_outlined, color: cs.onSurface),
              title: Text('Gallery', style: TextStyle(color: cs.onSurface)),
              subtitle: Text(
                'Photos and videos',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.folder_outlined, color: cs.onSurface),
              title: Text('Files', style: TextStyle(color: cs.onSurface)),
              subtitle: Text(
                'PDF, Word, Excel, and more',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
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
      _previewDocumentPath = null;
      _previewDocumentName = null;
      _previewDocumentMime = null;
      _previewDocumentSize = null;
    });
  }

  void _openPeerProfile() {
    if (_otherUserId == null) return;
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileReadonlyPage(
          userId: _otherUserId!,
          titleFallback: widget.userName,
        ),
      ),
    );
  }

  Future<void> _refreshBlockState() async {
    await _loadConversationAccess();
  }

  Future<void> _showReportDialog() async {
    final other = _otherUserId;
    if (other == null || _safetyBusy) return;
    setState(() => _safetyBusy = true);
    try {
      final submitted = await showReportUserFlow(
        context,
        reportedUserId: other,
        reportedName: widget.userName,
        conversationId: widget.conversationId,
        safetyService: _safetyService,
      );
      if (submitted && mounted) {
        await _refreshBlockState();
      }
    } finally {
      if (mounted) setState(() => _safetyBusy = false);
    }
  }

  Future<void> _confirmBlock() async {
    final other = _otherUserId;
    if (other == null || _safetyBusy) return;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${widget.userName}?'),
        content: const Text(
          'They will no longer be able to directly message you while blocked.\n\n'
          'You can unblock them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _safetyBusy = true);
    try {
      await _safetyService.blockUser(other);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked')),
      );
      await _refreshBlockState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _safetyBusy = false);
    }
  }

  Future<void> _confirmUnblock() async {
    final other = _otherUserId;
    if (other == null || _safetyBusy) return;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unblock ${widget.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _safetyBusy = true);
    try {
      await _safetyService.unblockUser(other);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unblocked')),
      );
      await _refreshBlockState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _safetyBusy = false);
    }
  }

  void _showDeleteOptions(BuildContext context, int index) {
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
    _messagesChannel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark
        ? Color.lerp(Colors.black, AppColors.blue, 0.2)!
        : DesignTokens.lightPageBackground;

    final hasPreview = _previewImagePath != null ||
        _previewVideoPath != null ||
        _previewDocumentPath != null;

    return Scaffold(
      backgroundColor: pageBg,
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
              onTap: _openPeerProfile,
              child: Stack(
                children: [
                  ProviderAvatar(
                    imageUrl: widget.avatarUrl,
                    name: widget.userName,
                    size: 40,
                    borderRadius: 18,
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
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
              switch (value) {
                case 'view_profile':
                  _openPeerProfile();
                case 'report':
                  _showReportDialog();
                case 'block':
                  _confirmBlock();
                case 'unblock':
                  _confirmUnblock();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'view_profile',
                enabled: _otherUserId != null,
                child: const Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 12),
                    Text('View Profile'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'report',
                enabled: _otherUserId != null && !_safetyBusy,
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, color: AppColors.red, size: 20),
                    const SizedBox(width: 12),
                    const Text('Report'),
                  ],
                ),
              ),
              if (_blockState.iBlocked)
                PopupMenuItem<String>(
                  value: 'unblock',
                  enabled: _otherUserId != null && !_safetyBusy,
                  child: const Row(
                    children: [
                      Icon(Icons.lock_open_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Unblock'),
                    ],
                  ),
                )
              else
                PopupMenuItem<String>(
                  value: 'block',
                  enabled: _otherUserId != null && !_safetyBusy,
                  child: const Row(
                    children: [
                      Icon(Icons.block, size: 20),
                      SizedBox(width: 12),
                      Text('Block'),
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : RefreshIndicator(
                    color: DesignTokens.accentOrange,
                    backgroundColor: DesignTokens.surfaceOf(context),
                    onRefresh: () => _loadMessages(showLoading: false),
                    child: _messages.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.4,
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
                                      'No messages yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start the conversation!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return _ChatBubble(
                                message: message,
                                onLongPress: message.isSent
                                    ? () => _showDeleteOptions(context, index)
                                    : null,
                                onRetry: message.uploadStatus == ChatUploadStatus.failed
                                    ? () => _retryUpload(message)
                                    : null,
                              );
                            },
                          ),
                  ),
          ),
          // Preview
          if (hasPreview)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: _previewDocumentPath != null
                  ? Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _documentMaterialIcon(
                              ChatAttachmentRules.iconKind(
                                _previewDocumentName ?? _previewDocumentPath!,
                                mimeType: _previewDocumentMime,
                              ),
                            ),
                            color: cs.onSurface,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _previewDocumentName ??
                                      path.basename(_previewDocumentPath!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(
                                  [
                                    ChatAttachmentRules.documentTypeLabel(
                                      _previewDocumentName ??
                                          _previewDocumentPath!,
                                      mimeType: _previewDocumentMime,
                                    ),
                                    if (_previewDocumentSize != null)
                                      ChatAttachmentRules.formatBytes(
                                        _previewDocumentSize!,
                                      ),
                                  ].join(' • '),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _clearPreview,
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
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
            ),
          if (_conversationRow != null && !_canSend && !_blockState.eitherBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, color: cs.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Viewing only: messaging is available after this provider accepts your connection.',
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Message input / blocked banner
          if (_blockState.eitherBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: cs.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _blockState.iBlocked
                              ? 'You blocked this user.'
                              : 'Messaging is unavailable for this conversation.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (_blockState.iBlocked)
                        TextButton(
                          onPressed: _safetyBusy ? null : _confirmUnblock,
                          child: const Text('Unblock'),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: TextField(
                        controller: _messageController,
                        readOnly: !_canSend,
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
                          hintText: _canSend ? 'Type a message...' : 'Sending is disabled',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          prefixIcon: _HapticIconButton(
                            icon: Icons.attach_file,
                            color: cs.onSurfaceVariant,
                            size: 20,
                            onPressed: () {
                              if (!_canSend || _attachmentBusy) return;
                              HapticFeedback.lightImpact();
                              FocusScope.of(context).unfocus();
                              _showAttachmentMenu();
                            },
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          isDense: true,
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
                      onPressed: (!_canSend || _attachmentBusy)
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _sendMessage();
                            },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

IconData _documentMaterialIcon(IconDataForDoc kind) {
  return switch (kind) {
    IconDataForDoc.pdf => Icons.picture_as_pdf_outlined,
    IconDataForDoc.word => Icons.description_outlined,
    IconDataForDoc.sheet => Icons.table_chart_outlined,
    IconDataForDoc.slides => Icons.slideshow_outlined,
    IconDataForDoc.generic => Icons.insert_drive_file_outlined,
  };
}

class _ParsedMedia {
  final String? imageUrl;
  final String? videoUrl;
  final String? documentUrl;
  final String? documentName;
  final String? documentMime;
  final int? documentSizeBytes;

  const _ParsedMedia({
    this.imageUrl,
    this.videoUrl,
    this.documentUrl,
    this.documentName,
    this.documentMime,
    this.documentSizeBytes,
  });
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
  final String? imageUrl;
  final String? videoUrl;
  final String? documentPath;
  final String? documentUrl;
  final String? documentName;
  final String? documentMime;
  final int? documentSizeBytes;
  final ChatUploadStatus uploadStatus;
  final double uploadProgress;
  final String? messageId;
  final String? localId;

  _ChatMessage({
    required this.text,
    required this.isSent,
    required this.time,
    this.imagePath,
    this.videoPath,
    this.imageUrl,
    this.videoUrl,
    this.documentPath,
    this.documentUrl,
    this.documentName,
    this.documentMime,
    this.documentSizeBytes,
    this.uploadStatus = ChatUploadStatus.none,
    this.uploadProgress = 0,
    this.messageId,
    this.localId,
  });

  bool get isDocument =>
      (documentUrl != null && documentUrl!.isNotEmpty) ||
      (documentPath != null && documentPath!.isNotEmpty) ||
      (documentName != null &&
          documentName!.isNotEmpty &&
          imageUrl == null &&
          imagePath == null &&
          videoUrl == null &&
          videoPath == null);
}

class _ChatBubble extends StatefulWidget {
  final _ChatMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  const _ChatBubble({
    required this.message,
    this.onLongPress,
    this.onRetry,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    if (!widget.message.isSent && !_hasTriggeredHaptic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          HapticFeedback.lightImpact();
          _hasTriggeredHaptic = true;
        }
      });
    }
  }

  Future<void> _openDocument() async {
    final msg = widget.message;
    if (msg.uploadStatus == ChatUploadStatus.uploading ||
        msg.uploadStatus == ChatUploadStatus.failed) {
      return;
    }
    final url = msg.documentUrl;
    if (url == null || url.isEmpty) {
      if (msg.documentPath != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document link is unavailable.')),
      );
      return;
    }
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document.')),
        );
      }
    }
  }

  Widget _buildDocumentCard(ColorScheme cs) {
    final msg = widget.message;
    final name = msg.documentName ??
        (msg.documentPath != null ? path.basename(msg.documentPath!) : 'Document');
    final typeLabel = ChatAttachmentRules.documentTypeLabel(
      name,
      mimeType: msg.documentMime,
    );
    final sizeLabel = msg.documentSizeBytes != null
        ? ChatAttachmentRules.formatBytes(msg.documentSizeBytes!)
        : null;
    final meta = [typeLabel, if (sizeLabel != null) sizeLabel].join(' • ');
    final fg = msg.isSent ? Colors.white : cs.onSurface;
    final fgMuted = msg.isSent ? Colors.white.withOpacity(0.75) : cs.onSurfaceVariant;

    return InkWell(
      onTap: _openDocument,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _documentMaterialIcon(
                ChatAttachmentRules.iconKind(name, mimeType: msg.documentMime),
              ),
              color: fg,
              size: 28,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 11, color: fgMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: fgMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadStatus(ColorScheme cs) {
    final msg = widget.message;
    final fg = msg.isSent ? Colors.white : cs.onSurface;
    final fgMuted = msg.isSent ? Colors.white.withOpacity(0.8) : cs.onSurfaceVariant;

    if (msg.uploadStatus == ChatUploadStatus.uploading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                value: msg.uploadProgress > 0 && msg.uploadProgress < 1
                    ? msg.uploadProgress
                    : null,
                color: fg,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Uploading...',
              style: TextStyle(fontSize: 11, color: fgMuted),
            ),
          ],
        ),
      );
    }

    if (msg.uploadStatus == ChatUploadStatus.failed) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Upload failed',
              style: TextStyle(fontSize: 11, color: fgMuted),
            ),
            if (widget.onRetry != null)
              TextButton(
                onPressed: widget.onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final msg = widget.message;
    final hasImage = msg.imagePath != null || msg.imageUrl != null;
    final hasVideo = msg.videoPath != null || msg.videoUrl != null;
    final hasDocument = msg.isDocument;
    final showCaption = msg.text.isNotEmpty &&
        !(hasDocument && msg.text == (msg.documentName ?? ''));

    return Align(
      alignment: msg.isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: msg.isSent ? widget.onLongPress : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: msg.isSent ? AppColors.waterGradient : null,
            color: msg.isSent ? null : AppColors.blue.withOpacity(0.15),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(msg.isSent ? 20 : 4),
              bottomRight: Radius.circular(msg.isSent ? 4 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                GestureDetector(
                  onTap: () {
                    ChatImageViewerPage.open(
                      context,
                      imageUrl: msg.imageUrl,
                      imagePath: msg.imagePath,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: msg.imagePath != null
                        ? Image.file(
                            File(msg.imagePath!),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: msg.imageUrl!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey.shade300,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                  ),
                ),
              if (hasVideo)
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
              if (hasDocument) _buildDocumentCard(cs),
              _buildUploadStatus(cs),
              if (showCaption) ...[
                if (hasImage || hasVideo || hasDocument) const SizedBox(height: 8),
                Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: msg.isSent ? Colors.white : cs.onSurface,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                msg.time,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: msg.isSent
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
