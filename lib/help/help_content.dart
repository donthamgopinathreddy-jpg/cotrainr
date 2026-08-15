import 'package:flutter/material.dart';

/// Local Help Center content for Cotrainr MVP (verified product behaviour only).
enum HelpCategoryId {
  account,
  health,
  meals,
  providers,
  messaging,
  privacy,
}

enum HelpDeepLink {
  changePassword,
  privacySecurity,
  healthDevices,
  notifications,
  privacyPolicy,
  termsOfService,
}

class HelpCategory {
  const HelpCategory({
    required this.id,
    required this.title,
    required this.chipLabel,
    required this.icon,
    required this.keywords,
  });

  final HelpCategoryId id;
  final String title;
  final String chipLabel;
  final IconData icon;
  final List<String> keywords;
}

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
    this.deepLink,
    this.deepLinkLabel,
    this.popular = false,
  });

  final String id;
  final HelpCategoryId category;
  final String question;
  final String answer;
  final List<String> keywords;
  final HelpDeepLink? deepLink;
  final String? deepLinkLabel;
  final bool popular;
}

abstract final class HelpContent {
  static const categories = <HelpCategory>[
    HelpCategory(
      id: HelpCategoryId.account,
      title: 'Account & Login',
      chipLabel: 'Account',
      icon: Icons.person_outline_rounded,
      keywords: ['account', 'login', 'password', 'profile', 'signin'],
    ),
    HelpCategory(
      id: HelpCategoryId.health,
      title: 'Health & Activity',
      chipLabel: 'Health',
      icon: Icons.favorite_outline_rounded,
      keywords: ['health', 'steps', 'activity', 'fitness'],
    ),
    HelpCategory(
      id: HelpCategoryId.meals,
      title: 'Meals & Nutrition',
      chipLabel: 'Meals',
      icon: Icons.restaurant_outlined,
      keywords: ['meal', 'food', 'nutrition', 'calories'],
    ),
    HelpCategory(
      id: HelpCategoryId.providers,
      title: 'Trainers & Nutritionists',
      chipLabel: 'Providers',
      icon: Icons.fitness_center_rounded,
      keywords: ['trainer', 'nutritionist', 'provider', 'connect'],
    ),
    HelpCategory(
      id: HelpCategoryId.messaging,
      title: 'Messaging',
      chipLabel: 'Messaging',
      icon: Icons.chat_bubble_outline_rounded,
      keywords: ['message', 'chat', 'block', 'report'],
    ),
    HelpCategory(
      id: HelpCategoryId.privacy,
      title: 'Privacy & Data',
      chipLabel: 'Privacy',
      icon: Icons.shield_outlined,
      keywords: ['privacy', 'sharing', 'location', 'deletion', 'data'],
    ),
  ];

  static const articles = <HelpArticle>[
    // —— Account & Login ——
    HelpArticle(
      id: 'sign-in',
      category: HelpCategoryId.account,
      question: 'How do I sign in?',
      answer:
          'Open Login and sign in with your email and password.\n\n'
          'You can also use Google sign-in where that option is shown. Other social '
          'options may appear when they are enabled for your device.\n\n'
          'Your User ID is your public Cotrainr handle. It is not used to sign in '
          'for the current MVP.',
      keywords: ['sign in', 'login', 'email', 'google', 'oauth', 'user id'],
      popular: false,
    ),
    HelpArticle(
      id: 'reset-password',
      category: HelpCategoryId.account,
      question: 'How do I reset my password?',
      answer:
          'On the Login screen, tap Forgot password? Enter the email for your '
          'account. Cotrainr will send a reset email so you can choose a new password.',
      keywords: ['reset', 'forgot', 'password', 'email'],
    ),
    HelpArticle(
      id: 'change-password',
      category: HelpCategoryId.account,
      question: 'How do I change my password?',
      answer:
          'Go to Settings → Change Password (also available from Privacy & Security). '
          'Enter your new password and confirm it.',
      keywords: ['change', 'password', 'update'],
      deepLink: HelpDeepLink.changePassword,
      deepLinkLabel: 'Change Password',
      popular: true,
    ),
    HelpArticle(
      id: 'user-id-login',
      category: HelpCategoryId.account,
      question: 'Can I sign in with my User ID?',
      answer:
          'Not in the current MVP. Sign in with email and password (or Google where '
          'available).\n\n'
          'Your User ID remains a public profile handle, not a login method.',
      keywords: ['user id', 'username', 'handle', 'login'],
    ),
    HelpArticle(
      id: 'edit-profile',
      category: HelpCategoryId.account,
      question: 'How do I edit my profile?',
      answer:
          'Open Settings → Edit Profile to update profile details such as name, bio, '
          'and photos.',
      keywords: ['edit', 'profile', 'name', 'photo'],
    ),
    HelpArticle(
      id: 'delete-account',
      category: HelpCategoryId.account,
      question: 'How do I request account deletion?',
      answer:
          'Account deletion is not available as an instant in-app action yet.\n\n'
          'Go to Privacy & Security → Request Account Deletion, or email '
          'support@cotrainr.com. Support will confirm with you before deleting '
          'your account.',
      keywords: ['delete', 'account', 'removal', 'erase'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
      popular: true,
    ),

    // —— Health ——
    HelpArticle(
      id: 'connect-health',
      category: HelpCategoryId.health,
      question: 'How do I connect health data?',
      answer:
          'Go to Settings → Health Connect (Apple Health on iOS). Allow Cotrainr to '
          'read the activity data you choose to share from your device health service.',
      keywords: ['connect', 'health', 'health connect', 'apple health'],
      deepLink: HelpDeepLink.healthDevices,
      deepLinkLabel: 'Open Health Connect',
      popular: true,
    ),
    HelpArticle(
      id: 'activity-types',
      category: HelpCategoryId.health,
      question: 'What activity data does Cotrainr use?',
      answer:
          'Where supported, Cotrainr can read steps, activity energy / calories, '
          'distance, and water from Health Connect or Apple Health.\n\n'
          'You can also enter height, weight, and fitness goals in your profile. '
          'Cotrainr does not currently use heart rate, sleep, or workout-type '
          'categories in this MVP health integration.',
      keywords: ['steps', 'calories', 'distance', 'water', 'metrics'],
    ),
    HelpArticle(
      id: 'health-permissions',
      category: HelpCategoryId.health,
      question: 'How do I manage health permissions?',
      answer:
          'Open Settings → Health Connect to connect or manage permissions. You can '
          'also change health access in your phone’s system Health / Health Connect '
          'settings.',
      keywords: ['permission', 'health', 'manage', 'access'],
      deepLink: HelpDeepLink.healthDevices,
      deepLinkLabel: 'Open Health Connect',
    ),
    HelpArticle(
      id: 'steps-not-updating',
      category: HelpCategoryId.health,
      question: 'Why are my steps not updating?',
      answer:
          'Check that Health Connect or Apple Health is connected and that steps '
          'permission is allowed. Make sure the device health app has recent step '
          'data, then open Cotrainr again or pull to refresh where available.\n\n'
          'Cotrainr reads from your health service — it does not invent steps from '
          'phone sensors alone in the current MVP.',
      keywords: ['steps', 'not updating', 'sync', 'zero'],
      deepLink: HelpDeepLink.healthDevices,
      deepLinkLabel: 'Open Health Connect',
    ),
    HelpArticle(
      id: 'trainer-see-activity',
      category: HelpCategoryId.health,
      question: 'Can my trainer see my activity data?',
      answer:
          'Only if you are connected with an accepted Trainer relationship and '
          'Share Activity Data with Trainer is turned on in Privacy & Security.\n\n'
          'That control covers steps, calories, distance, and water from your daily '
          'metrics. Sharing defaults are currently on — you can turn them off anytime.',
      keywords: ['trainer', 'activity', 'sharing', 'metrics'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
      popular: true,
    ),

    // —— Meals ——
    HelpArticle(
      id: 'log-meal',
      category: HelpCategoryId.meals,
      question: 'How do I log a meal?',
      answer:
          'Open Meal Tracker, choose a meal (for example breakfast or lunch), then '
          'tap Add Food to log items.',
      keywords: ['log', 'meal', 'add food', 'tracker'],
    ),
    HelpArticle(
      id: 'trainer-meals',
      category: HelpCategoryId.meals,
      question: 'Can my trainer see my meal logs?',
      answer:
          'Yes, when you have an accepted Trainer connection and Share Meal Data with '
          'Trainer is enabled in Privacy & Security.\n\n'
          'This shares meals you log in Meal Tracker — not unrelated account data.',
      keywords: ['trainer', 'meals', 'sharing'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
    ),
    HelpArticle(
      id: 'nutritionist-meals',
      category: HelpCategoryId.meals,
      question: 'Can my nutritionist see my meal logs?',
      answer:
          'When you have an accepted Nutritionist connection and Share Meal Logs with '
          'Nutritionist is enabled, they can see logged meals.\n\n'
          'Calorie and planner targets stay private under that control — meal logs '
          'and nutrition goals are not the same dataset.',
      keywords: ['nutritionist', 'meals', 'goals', 'sharing'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
      popular: true,
    ),
    HelpArticle(
      id: 'meal-sharing',
      category: HelpCategoryId.meals,
      question: 'How do I change meal sharing?',
      answer:
          'Open Privacy & Security and use:\n\n'
          '• Share Meal Data with Trainer\n'
          '• Share Meal Logs with Nutritionist\n\n'
          'Then tap Save.',
      keywords: ['meal', 'sharing', 'privacy', 'toggle'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
      popular: true,
    ),

    // —— Providers ——
    HelpArticle(
      id: 'connect-trainer',
      category: HelpCategoryId.providers,
      question: 'How do I connect with a trainer?',
      answer:
          'Open Discover, find a Trainer, and send a connection request. When the '
          'Trainer accepts, you can message them and sharing preferences may apply.\n\n'
          'Some plans may limit how many connections you can request.',
      keywords: ['connect', 'trainer', 'discover', 'request'],
    ),
    HelpArticle(
      id: 'trainer-info',
      category: HelpCategoryId.providers,
      question: 'What information can my trainer see?',
      answer:
          'With an accepted connection, a Trainer may see information you share through '
          'Cotrainr based on your privacy controls — including activity metrics and '
          'meal logs when those toggles are on.\n\n'
          'They do not automatically receive everything in your account.',
      keywords: ['trainer', 'see', 'access', 'data'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
    ),
    HelpArticle(
      id: 'nutritionist-info',
      category: HelpCategoryId.providers,
      question: 'What information can my nutritionist see?',
      answer:
          'With an accepted connection and Share Meal Logs with Nutritionist enabled, '
          'a Nutritionist can see logged meals.\n\n'
          'They do not get calorie/planner targets through that meal-log control.',
      keywords: ['nutritionist', 'see', 'access', 'meals'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
    ),
    HelpArticle(
      id: 'privacy-providers',
      category: HelpCategoryId.providers,
      question: 'How do privacy controls affect providers?',
      answer:
          'Privacy & Security lets you turn activity and meal sharing on or off for '
          'Trainers and meal-log sharing for Nutritionists.\n\n'
          'Access also depends on an accepted connection. Defaults are currently on '
          '(opt-out) — review them after you connect with someone.',
      keywords: ['privacy', 'controls', 'providers', 'defaults'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
    ),

    // —— Messaging ——
    HelpArticle(
      id: 'who-message',
      category: HelpCategoryId.messaging,
      question: 'Who can I message?',
      answer:
          'Members can message Trainers or Nutritionists after a connection is '
          'accepted. Messaging is for Member–provider conversations in the current MVP.\n\n'
          'Social feed messaging (CoCircle) is not available in the MVP.',
      keywords: ['message', 'who', 'chat', 'provider'],
      popular: true,
    ),
    HelpArticle(
      id: 'cant-send',
      category: HelpCategoryId.messaging,
      question: 'Why can’t I send a message?',
      answer:
          'Sending usually requires an accepted connection with that provider. If the '
          'request is still pending, you may only be able to view the conversation.\n\n'
          'If you blocked each other, messaging may also be unavailable.',
      keywords: ['can\'t send', 'disabled', 'pending', 'blocked'],
    ),
    HelpArticle(
      id: 'photos-files',
      category: HelpCategoryId.messaging,
      question: 'Can I send photos or files?',
      answer:
          'Yes. Chat supports text and supported attachments or files. Newer uploads '
          'use private participant-authorized storage.\n\n'
          'Cotrainr does not claim end-to-end encryption for messages.',
      keywords: ['photo', 'file', 'attachment', 'image'],
    ),
    HelpArticle(
      id: 'report-block',
      category: HelpCategoryId.messaging,
      question: 'How do I report or block someone?',
      answer:
          'Open the chat with that person and use the menu to Report or Block. '
          'Blocking limits further contact through Cotrainr safety tools.',
      keywords: ['report', 'block', 'safety', 'abuse'],
    ),

    // —— Privacy ——
    HelpArticle(
      id: 'control-sharing',
      category: HelpCategoryId.privacy,
      question: 'How do I control data sharing?',
      answer:
          'Open Privacy & Security. You can control:\n\n'
          '• Share Activity Data with Trainer\n'
          '• Share Meal Data with Trainer\n'
          '• Share Meal Logs with Nutritionist\n\n'
          'Tap Save after you make changes.',
      keywords: ['sharing', 'privacy', 'controls', 'data'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
      popular: true,
    ),
    HelpArticle(
      id: 'location-use',
      category: HelpCategoryId.privacy,
      question: 'How is my location used?',
      answer:
          'With permission, Cotrainr may use your location to show nearby Trainers, '
          'Nutritionists, and fitness services in Discover.\n\n'
          'Member GPS used for nearby search is intended for that request and is not '
          'meant to be stored as your ongoing current location. Manage permission from '
          'Privacy & Security → Location → Manage, or in system settings.',
      keywords: ['location', 'gps', 'nearby', 'discover'],
      deepLink: HelpDeepLink.privacySecurity,
      deepLinkLabel: 'Open Privacy & Security',
    ),
    HelpArticle(
      id: 'download-data',
      category: HelpCategoryId.privacy,
      question: 'Can I download my data?',
      answer:
          'An automated Download My Data export is not available yet — it is marked '
          'Coming soon in Privacy & Security.\n\n'
          'For privacy or data requests, email support@cotrainr.com.',
      keywords: ['download', 'export', 'data', 'gdpr'],
    ),
    HelpArticle(
      id: 'privacy-policy-link',
      category: HelpCategoryId.privacy,
      question: 'Where can I read the Privacy Policy?',
      answer:
          'Open Settings → Privacy Policy, or Privacy & Security → Privacy Policy. '
          'The same in-app document is shown during signup.',
      keywords: ['privacy policy', 'legal'],
      deepLink: HelpDeepLink.privacyPolicy,
      deepLinkLabel: 'Open Privacy Policy',
    ),
    HelpArticle(
      id: 'terms-link',
      category: HelpCategoryId.privacy,
      question: 'Where can I read the Terms of Service?',
      answer:
          'Open Settings → Terms of Service. The same in-app Terms are linked during '
          'signup.',
      keywords: ['terms', 'terms of service', 'legal'],
      deepLink: HelpDeepLink.termsOfService,
      deepLinkLabel: 'Open Terms of Service',
    ),
  ];

  static List<HelpArticle> get popularArticles =>
      articles.where((a) => a.popular).toList(growable: false);

  static List<HelpArticle> forCategory(HelpCategoryId id) =>
      articles.where((a) => a.category == id).toList(growable: false);

  static List<HelpArticle> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    bool matches(HelpArticle a) {
      if (a.question.toLowerCase().contains(q)) return true;
      if (a.answer.toLowerCase().contains(q)) return true;
      for (final k in a.keywords) {
        if (k.toLowerCase().contains(q)) return true;
      }
      final cat = categories.firstWhere((c) => c.id == a.category);
      if (cat.title.toLowerCase().contains(q)) return true;
      for (final k in cat.keywords) {
        if (k.toLowerCase().contains(q)) return true;
      }
      return false;
    }

    return articles.where(matches).toList(growable: false);
  }
}
