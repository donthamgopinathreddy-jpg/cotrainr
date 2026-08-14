/// Shared metadata for in-app Privacy Policy and Terms of Service.
///
/// Keep in sync with `current_legal_versions()` until a deliberate version bump.
class LegalDocumentMeta {
  LegalDocumentMeta._();

  static const String version = '2026-08-01';
  static const String effectiveDateLabel = '1 August 2026';
  static const String lastUpdatedLabel = '1 August 2026';

  /// User-facing privacy/legal contact (not transactional noreply).
  static const String supportEmail = 'support@cotrainr.com';

  static const String decisionRequiredPrefix =
      'LEGAL/BUSINESS DECISION REQUIRED.';
}
