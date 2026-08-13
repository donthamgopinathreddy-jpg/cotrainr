/// Authentication path for the shared Cotrainr onboarding wizard.
enum SignupMode {
  /// Email + password credentials, then shared onboarding, then auth.signUp.
  email,

  /// Existing OAuth session. Shared onboarding without password; trusted RPC finalize.
  social,
}
