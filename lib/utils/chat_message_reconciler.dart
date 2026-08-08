/// Pure reconciliation helpers for chat bubbles keyed by canonical DB message id.
///
/// Optimistic rows use [localId] until [confirmOptimistic] replaces them with
/// the server [messageId]. Realtime echoes for known ids are ignored.
class ChatMessageReconciler {
  ChatMessageReconciler();

  final List<ReconciledChatMessage> messages = [];
  final Set<String> _canonicalIds = {};
  final Set<String> _localIds = {};

  Set<String> get canonicalIds => Set.unmodifiable(_canonicalIds);

  void replaceAll(List<ReconciledChatMessage> loaded) {
    messages
      ..clear()
      ..addAll(loaded);
    _canonicalIds
      ..clear()
      ..addAll(
        loaded
            .map((m) => m.messageId)
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );
    _localIds.clear();
  }

  /// Append an optimistic bubble. Returns the local correlation id.
  String addOptimistic({
    required String text,
    required bool isSent,
    required String time,
    String? imagePath,
    String? videoPath,
    String? documentPath,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
    ChatUploadStatus uploadStatus = ChatUploadStatus.none,
    String? localId,
  }) {
    final id = localId ??
        'local_${DateTime.now().microsecondsSinceEpoch}_${messages.length}';
    _localIds.add(id);
    messages.add(
      ReconciledChatMessage(
        text: text,
        isSent: isSent,
        time: time,
        localId: id,
        imagePath: imagePath,
        videoPath: videoPath,
        documentPath: documentPath,
        documentName: documentName,
        documentMime: documentMime,
        documentSizeBytes: documentSizeBytes,
        uploadStatus: uploadStatus,
      ),
    );
    return id;
  }

  /// Replace optimistic [localId] with the canonical DB message.
  /// Idempotent if Realtime already inserted [messageId].
  bool confirmOptimistic({
    required String localId,
    required String messageId,
    required String text,
    required bool isSent,
    required String time,
    String? imageUrl,
    String? videoUrl,
    String? documentUrl,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
  }) {
    if (messageId.isEmpty) return false;
    _canonicalIds.add(messageId);
    _localIds.remove(localId);
    messages.removeWhere((m) => m.localId == localId);

    if (_hasMessageId(messageId)) {
      return true;
    }

    messages.add(
      ReconciledChatMessage(
        text: text,
        isSent: isSent,
        time: time,
        messageId: messageId,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        documentUrl: documentUrl,
        documentName: documentName,
        documentMime: documentMime,
        documentSizeBytes: documentSizeBytes,
        uploadStatus: ChatUploadStatus.none,
      ),
    );
    return true;
  }

  bool updateOptimistic(
    String localId, {
    ChatUploadStatus? uploadStatus,
    double? uploadProgress,
    String? imageUrl,
    String? documentUrl,
  }) {
    final index = messages.indexWhere((m) => m.localId == localId);
    if (index < 0) return false;
    final m = messages[index];
    messages[index] = m.copyWith(
      uploadStatus: uploadStatus,
      uploadProgress: uploadProgress,
      imageUrl: imageUrl,
      documentUrl: documentUrl,
    );
    return true;
  }

  /// Remove a specific optimistic bubble (safe failure path).
  bool removeOptimistic(String localId) {
    _localIds.remove(localId);
    final index = messages.indexWhere((m) => m.localId == localId);
    if (index < 0) return false;
    messages.removeAt(index);
    return true;
  }

  /// Apply a Realtime/server insert. Returns false if already known (no-op).
  bool upsertCanonical({
    required String messageId,
    required String text,
    required bool isSent,
    required String time,
    String? imageUrl,
    String? videoUrl,
    String? documentUrl,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
  }) {
    if (messageId.isEmpty) return false;
    if (_canonicalIds.contains(messageId) || _hasMessageId(messageId)) {
      return false;
    }
    _canonicalIds.add(messageId);
    messages.add(
      ReconciledChatMessage(
        text: text,
        isSent: isSent,
        time: time,
        messageId: messageId,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        documentUrl: documentUrl,
        documentName: documentName,
        documentMime: documentMime,
        documentSizeBytes: documentSizeBytes,
      ),
    );
    return true;
  }

  bool _hasMessageId(String messageId) =>
      messages.any((m) => m.messageId == messageId);
}

enum ChatUploadStatus { none, uploading, failed }

class ReconciledChatMessage {
  final String text;
  final bool isSent;
  final String time;
  final String? messageId;
  final String? localId;
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

  const ReconciledChatMessage({
    required this.text,
    required this.isSent,
    required this.time,
    this.messageId,
    this.localId,
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

  ReconciledChatMessage copyWith({
    String? text,
    bool? isSent,
    String? time,
    String? messageId,
    String? localId,
    String? imagePath,
    String? videoPath,
    String? imageUrl,
    String? videoUrl,
    String? documentPath,
    String? documentUrl,
    String? documentName,
    String? documentMime,
    int? documentSizeBytes,
    ChatUploadStatus? uploadStatus,
    double? uploadProgress,
  }) {
    return ReconciledChatMessage(
      text: text ?? this.text,
      isSent: isSent ?? this.isSent,
      time: time ?? this.time,
      messageId: messageId ?? this.messageId,
      localId: localId ?? this.localId,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      documentPath: documentPath ?? this.documentPath,
      documentUrl: documentUrl ?? this.documentUrl,
      documentName: documentName ?? this.documentName,
      documentMime: documentMime ?? this.documentMime,
      documentSizeBytes: documentSizeBytes ?? this.documentSizeBytes,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}
