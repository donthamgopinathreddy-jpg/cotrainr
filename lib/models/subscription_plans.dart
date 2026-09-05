/// Display + product metadata for Cotrainr client subscription tiers.
///
/// DB / internal IDs:
/// - [free] → `'free'`
/// - [basic] → `'basic'`
/// - [unlimited] → `'premium'` (user-facing label: Ultimate)
///
/// Entitlement limits and nutritionist connect eligibility are owned by
/// PostgreSQL (`get_member_entitlements`) — not encoded here.
abstract final class SubscriptionPlans {
  static const free = 'free';
  static const basic = 'basic';
  /// Internal / DB value is `premium`; shown as Ultimate in product UI.
  static const unlimited = 'premium';

  static String displayName(String plan) => switch (plan.toLowerCase()) {
        basic => 'Basic',
        unlimited => 'Ultimate',
        _ => 'Free',
      };

  /// Short label for nutritionist premium access chips.
  static const nutritionistAccessPlansLabel = 'Basic & Ultimate';

  static const freeBenefits = [
    'Browse trainers & nutritionists in Discover',
    'Open full public nutritionist profiles',
    '5 new provider connection requests per month',
    'Unlimited messaging with accepted providers',
    'Read provider reviews',
    'Connect with nutritionists on Basic & Ultimate',
  ];

  static const basicBenefits = [
    'Unlimited trainer & nutritionist discovery',
    '15 new provider connection requests per month',
    'Connect with nutritionists',
    'Unlimited messaging with accepted providers',
    'Review your subscribed trainer',
  ];

  static const unlimitedBenefits = [
    'Unlimited trainers & nutritionists in Discover',
    'Unlimited new provider connection requests',
    'Unlimited messaging with accepted providers',
    'Review subscribed trainers & nutritionists',
    'Priority support',
  ];

  static List<String> benefitsFor(String plan) => switch (plan.toLowerCase()) {
        basic => basicBenefits,
        unlimited => unlimitedBenefits,
        _ => freeBenefits,
      };

  static bool canWriteReviews(String plan) => true;

  static bool canReviewNutritionist(String plan) => true;

  /// Free / Basic / Ultimate — browse nutritionists is always allowed.
  static bool canBrowseNutritionists(String plan) => true;

  /// Free tier caps nearby **trainer** Discover results only.
  static int? discoverResultCap(String plan) =>
      plan.toLowerCase() == free ? 10 : null;
}
