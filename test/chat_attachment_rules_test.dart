import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/utils/chat_attachment_rules.dart';

void main() {
  group('ChatAttachmentRules', () {
    test('allows coaching document types including CSV', () {
      expect(ChatAttachmentRules.isAllowedDocument('plan.pdf'), isTrue);
      expect(ChatAttachmentRules.isAllowedDocument('a.docx'), isTrue);
      expect(ChatAttachmentRules.isAllowedDocument('b.xlsx'), isTrue);
      expect(ChatAttachmentRules.isAllowedDocument('c.pptx'), isTrue);
      expect(ChatAttachmentRules.isAllowedDocument('notes.txt'), isTrue);
      expect(ChatAttachmentRules.isAllowedDocument('data.csv'), isTrue);
      expect(
        ChatAttachmentRules.isAllowedDocument(
          'x.bin',
          mimeType: 'application/pdf',
        ),
        isTrue,
      );
    });

    test('rejects executables and scripts', () {
      expect(ChatAttachmentRules.isAllowedDocument('malware.exe'), isFalse);
      expect(ChatAttachmentRules.isAllowedDocument('app.apk'), isFalse);
      expect(ChatAttachmentRules.isAllowedDocument('run.bat'), isFalse);
      expect(ChatAttachmentRules.isAllowedDocument('x.sh'), isFalse);
      expect(ChatAttachmentRules.isAllowedDocument('hack.js'), isFalse);
      expect(ChatAttachmentRules.isBlockedExtension('hack.js'), isTrue);
    });

    test('image and document size limits', () {
      expect(ChatAttachmentRules.maxImageBytes, 10 * 1024 * 1024);
      expect(ChatAttachmentRules.maxDocumentBytes, 20 * 1024 * 1024);
    });

    test('formatBytes and type labels', () {
      expect(ChatAttachmentRules.formatBytes(900), '900 B');
      expect(ChatAttachmentRules.documentTypeLabel('a.pdf'), 'PDF');
      expect(ChatAttachmentRules.documentTypeLabel('a.docx'), 'DOCX');
      expect(ChatAttachmentRules.documentTypeLabel('a.csv'), 'CSV');
    });
  });
}
