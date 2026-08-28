from pathlib import Path

p = Path(r"c:\Users\HP\Documents\projects\cotrainr_flutter\lib\pages\messaging\chat_screen.dart")
text = p.read_text(encoding="utf-8")
start = text.find("  Future<void> _pickGallery() async {")
end = text.find("  void _showAttachmentMenu() {")
if start < 0 or end < 0 or end <= start:
    raise SystemExit(f"markers not found start={start} end={end}")

new = r"""  Future<void> _pickGallery() async {
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

"""

p.write_text(text[:start] + new + text[end:], encoding="utf-8", newline="\n")
print("ok")
