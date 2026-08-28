import 'legal_document_meta.dart';

/// Centralized unresolved legal/business values for Cotrainr production docs.
///
/// Do not invent operator identity, governing law, minimum age, retention
/// periods, or payment rules here. User-facing copy references these markers
/// instead of fabricating details.
abstract final class LegalBusinessDecisions {
  LegalBusinessDecisions._();

  /// Shown in-app when a clause still needs legal/business sign-off.
  static const String requiredPrefix = LegalDocumentMeta.decisionRequiredPrefix;

  /// Minimum eligibility age — not finalized for publication.
  static const String? minimumAgeYears = null;

  static String get eligibilityAgeCopy {
    if (minimumAgeYears != null) {
      return 'You must be at least $minimumAgeYears years old to use Cotrainr.';
    }
    return '$requiredPrefix Minimum age and children’s eligibility rules have '
        'not been finalized for publication.\n\n'
        'You must be able to form a binding contract where you live and must '
        'provide accurate registration information. If Cotrainr later publishes '
        'a minimum age, you must meet it to continue using the service.';
  }

  static String get childrenPrivacyCopy {
    if (minimumAgeYears != null) {
      return 'Cotrainr is not directed to children under $minimumAgeYears. '
          'If we learn that we hold an account for a child below that age '
          'without appropriate permission, we will take steps to delete it.';
    }
    return '$requiredPrefix Minimum user age and children’s privacy rules have '
        'not been finalized for publication.\n\n'
        'Until that decision is confirmed, do not use Cotrainr if you are not '
        'able to form a binding contract where you live, and do not submit '
        'personal information for children.';
  }

  static String get operatorCopy =>
      '$requiredPrefix The legal entity or operator name that publishes '
      'Cotrainr, and any registered or business address, has not been '
      'approved for publication in this document.\n\n'
      'Until that information is confirmed, privacy and legal questions should '
      'be sent to ${LegalDocumentMeta.supportEmail}.';

  static String get governingLawCopy =>
      '$requiredPrefix Governing law and courts / venue have not been '
      'designated for publication.\n\n'
      'Until that decision is made, disputes will be handled under applicable '
      'mandatory consumer or local laws that cannot be displaced by these Terms.';

  static String get indemnityCopy =>
      '$requiredPrefix A full indemnity clause has not been approved for this '
      'release.\n\n'
      'Pending legal review, you agree to cooperate reasonably with Cotrainr '
      'in resolving claims arising from content you submit or your misuse of '
      'the service.';

  static String get retentionCopy =>
      '$requiredPrefix Specific retention periods for each data category have '
      'not been approved for publication.\n\n'
      'In practice, we keep information while your account is active and as '
      'needed to operate Cotrainr, resolve disputes, enforce our Terms, and '
      'meet legal obligations. When you request account deletion, we remove or '
      'anonymise personal data we no longer need, subject to legitimate '
      'retention exceptions (for example security logs, fraud records, or '
      'legal holds).';

  static String get transfersCopy =>
      '$requiredPrefix Supabase hosting region and any formal international '
      'transfer mechanism (for example SCCs) have not been finalized for '
      'publication.\n\n'
      'Cotrainr uses cloud infrastructure providers that may process data in '
      'more than one country. We take reasonable steps appropriate to the '
      'services we use and will update this section when transfer details are '
      'confirmed.';

  static String get legalBasesCopy =>
      '$requiredPrefix Exact GDPR (or other) legal-basis mapping for each '
      'processing activity has not been finalized for publication.\n\n'
      'Depending on your location and how you use Cotrainr, we may rely on '
      'bases such as contract performance, legitimate interests (for example '
      'security and service improvement), consent where required (for example '
      'certain device permissions), and legal obligation. Health and other '
      'sensitive categories receive additional care and will follow '
      'jurisdiction-specific rules once confirmed.';

  static String get specialCategoryCopy =>
      '$requiredPrefix The precise legal basis and safeguards for health and '
      'other special-category information under each launch jurisdiction have '
      'not been finalized for publication.\n\n'
      'Fitness, body and nutrition information is processed to operate the '
      'features you use, with access controls and device permissions where '
      'applicable. We do not treat Cotrainr as a medical record system.';

  static const List<String> unresolvedForReport = [
    'Legal / operator entity name and business address',
    'Official legal and privacy contact beyond support@cotrainr.com (if different)',
    'Minimum age / children’s eligibility rules',
    'Governing law and dispute venue',
    'Exact data retention periods by category',
    'International transfer mechanism and hosting region disclosure',
    'Jurisdiction-specific consumer/refund wording when paid billing launches',
    'Full indemnity / liability-cap language for counsel approval',
    'Whether each new legal version requires mandatory re-acceptance for existing users',
    'Dedicated Cotrainr Partner Terms document for partner-center applications',
  ];
}
