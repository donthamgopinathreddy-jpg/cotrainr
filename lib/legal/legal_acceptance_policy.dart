/// Client-side documentation of server legal-acceptance rules.
///
/// Authoritative writes/checks live in Supabase
/// (`record_legal_acceptance`, `get_onboarding_state`,
/// `require_legal_reacceptance`). This helper exists so widget/unit tests can
/// assert the intended product behaviour without inventing a second store.
abstract final class LegalAcceptancePolicy {
  LegalAcceptancePolicy._();

  /// Whether an existing acceptance row satisfies the onboarding legal gate.
  ///
  /// When [requireReacceptance] is false (MVP default after a version bump),
  /// any prior acceptance prevents forcing users back into complete-profile.
  /// When true, versions must match the current published pair.
  static bool satisfiesOnboardingLegalGate({
    required bool hasAnyAcceptance,
    required String? acceptedTermsVersion,
    required String? acceptedPrivacyVersion,
    required String currentTermsVersion,
    required String currentPrivacyVersion,
    required bool requireReacceptance,
  }) {
    if (!hasAnyAcceptance) return false;
    if (!requireReacceptance) return true;
    return acceptedTermsVersion == currentTermsVersion &&
        acceptedPrivacyVersion == currentPrivacyVersion;
  }

  /// Client-submitted versions must equal the server current pair.
  static bool versionsMatchCurrent({
    required String submittedTerms,
    required String submittedPrivacy,
    required String currentTerms,
    required String currentPrivacy,
  }) {
    return submittedTerms == currentTerms && submittedPrivacy == currentPrivacy;
  }
}
