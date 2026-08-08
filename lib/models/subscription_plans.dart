/// Display + rules for Cotrainr client subscription tiers.
///
/// DB / internal IDs:
/// - [free] → `'free'`
/// - [basic] → `'basic'`
/// - [unlimited] → `'premium'` (user-facing label: Ultimate)
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

  /// Monthly NEW unique provider connection requests (calendar month).
  /// `null` = unlimited (Ultimate / premium).
  static int? monthlyConnectionRequestLimit(String plan) {
    final p = plan.toLowerCase();
    if (p == free) return 5;
    if (p == basic) return 15;
    if (p == unlimited) return null;
    return 5;
  }

  static bool hasUnlimitedConnectionRequests(String plan) =>
      monthlyConnectionRequestLimit(plan) == null;

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

  /// Plan eligibility to connect to nutritionists (separate from monthly quota).
  static bool canConnectToNutritionist(String plan) {
    final p = plan.toLowerCase();
    return p == basic || p == unlimited;
  }

  /// Free tier caps nearby **trainer** Discover results only.
  static int? discoverResultCap(String plan) =>
      plan.toLowerCase() == free ? 10 : null;
}
