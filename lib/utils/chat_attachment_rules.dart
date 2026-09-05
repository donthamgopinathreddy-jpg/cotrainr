import 'package:path/path.dart' as p;

/// Chat attachment validation helpers (images + coaching documents).
class ChatAttachmentRules {
  ChatAttachmentRules._();

  static const int maxImageBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxDocumentBytes = 20 * 1024 * 1024; // 20 MB
  static const int maxAudioBytes = 10 * 1024 * 1024; // 10 MB

  static const Set<String> allowedImageExts = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  };

  static const Set<String> allowedAudioExts = {
    '.m4a',
    '.aac',
    '.mp3',
    '.mp4',
  };

  static const Set<String> allowedDocumentExts = {
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.txt',
    '.csv',
  };

  static const Set<String> blockedExts = {
    '.exe',
    '.apk',
    '.bat',
    '.cmd',
    '.sh',
    '.js',
    '.mjs',
    '.jar',
    '.dll',
    '.com',
    '.msi',
    '.ps1',
    '.vbs',
    '.scr',
    '.dmg',
    '.app',
  };

  static String extensionOf(String pathOrName) =>
      p.extension(pathOrName).toLowerCase();

  static bool isBlockedExtension(String pathOrName) =>
      blockedExts.contains(extensionOf(pathOrName));

  static bool isAllowedImage(String pathOrName, {String? mimeType}) {
    if (isBlockedExtension(pathOrName)) return false;
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) return true;
    return allowedImageExts.contains(extensionOf(pathOrName));
  }

  static bool isAllowedAudio(String pathOrName, {String? mimeType}) {
    if (isBlockedExtension(pathOrName)) return false;
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('audio/')) return true;
    return allowedAudioExts.contains(extensionOf(pathOrName));
  }

  static bool isAllowedDocument(String pathOrName, {String? mimeType}) {
    if (isBlockedExtension(pathOrName)) return false;
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.isNotEmpty && _documentMimes.contains(mime)) return true;
    return allowedDocumentExts.contains(extensionOf(pathOrName));
  }

  static const Set<String> _documentMimes = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'application/csv',
  };

  static String? mimeForPath(String pathOrName) {
    final ext = extensionOf(pathOrName);
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.mp4' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.m4a' || '.aac' => 'audio/mp4',
      '.mp3' => 'audio/mpeg',
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt' => 'application/vnd.ms-powerpoint',
      '.pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt' => 'text/plain',
      '.csv' => 'text/csv',
      _ => null,
    };
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String documentTypeLabel(String pathOrName, {String? mimeType}) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.contains('pdf') || extensionOf(pathOrName) == '.pdf') return 'PDF';
    if (mime.contains('word') ||
        {'.doc', '.docx'}.contains(extensionOf(pathOrName))) {
      return extensionOf(pathOrName) == '.doc' ? 'DOC' : 'DOCX';
    }
    if (mime.contains('sheet') ||
        mime.contains('excel') ||
        {'.xls', '.xlsx', '.csv'}.contains(extensionOf(pathOrName))) {
      if (extensionOf(pathOrName) == '.csv' || mime.contains('csv')) {
        return 'CSV';
      }
      return extensionOf(pathOrName) == '.xls' ? 'XLS' : 'XLSX';
    }
    if (mime.contains('presentation') ||
        mime.contains('powerpoint') ||
        {'.ppt', '.pptx'}.contains(extensionOf(pathOrName))) {
      return extensionOf(pathOrName) == '.ppt' ? 'PPT' : 'PPTX';
    }
    if (mime.startsWith('text/') || extensionOf(pathOrName) == '.txt') {
      return 'TXT';
    }
    final ext = extensionOf(pathOrName);
    if (ext.isEmpty) return 'FILE';
    return ext.replaceFirst('.', '').toUpperCase();
  }

  static IconDataForDoc iconKind(String pathOrName, {String? mimeType}) {
    final label = documentTypeLabel(pathOrName, mimeType: mimeType);
    return switch (label) {
      'PDF' => IconDataForDoc.pdf,
      'DOC' || 'DOCX' => IconDataForDoc.word,
      'XLS' || 'XLSX' || 'CSV' => IconDataForDoc.sheet,
      'PPT' || 'PPTX' => IconDataForDoc.slides,
      _ => IconDataForDoc.generic,
    };
  }
}

enum IconDataForDoc { pdf, word, sheet, slides, generic }
