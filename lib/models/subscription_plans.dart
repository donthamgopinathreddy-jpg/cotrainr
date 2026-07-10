/// Display + rules for Cotrainr client subscription tiers.
/// DB enum uses `premium` for the Unlimited tier.
abstract final class SubscriptionPlans {
  static const free = 'free';
  static const basic = 'basic';
  static const unlimited = 'premium';

  static String displayName(String plan) => switch (plan.toLowerCase()) {
        basic => 'Basic',
        unlimited => 'Unlimited',
        _ => 'Free',
      };

  static const freeBenefits = [
    '5–10 nearby trainers in Discover',
    'Chat with up to 5 trainers per month',
    '1 active trainer connection',
    'Video sessions with your subscribed trainer',
    'Read provider reviews',
  ];

  static const basicBenefits = [
    'Unlimited trainer discovery',
    'Unlimited trainer messaging',
    '1 active trainer connection',
    'Video sessions with your subscribed trainer',
    'Review your subscribed trainer',
  ];

  static const unlimitedBenefits = [
    'Unlimited trainers & nutritionists in Discover',
    'Unlimited trainer & nutritionist messaging',
    'Unlimited active trainer & nutritionist connections',
    'Video sessions with trainers and nutritionists',
    'Review subscribed trainers & nutritionists',
    'Priority support',
  ];

  static List<String> benefitsFor(String plan) => switch (plan.toLowerCase()) {
        basic => basicBenefits,
        unlimited => unlimitedBenefits,
        _ => freeBenefits,
      };

  static bool canWriteReviews(String plan) =>
      plan.toLowerCase() == basic || plan.toLowerCase() == unlimited;

  static bool canReviewNutritionist(String plan) =>
      plan.toLowerCase() == unlimited;

  /// Free tier caps nearby provider results (upper bound of marketing range).
  static int? discoverResultCap(String plan) =>
      plan.toLowerCase() == free ? 10 : null;
}
