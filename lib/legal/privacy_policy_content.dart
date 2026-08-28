import '../widgets/legal/legal_document.dart';
import 'legal_document_meta.dart';
import 'legal_business_decisions.dart';

/// Production Privacy Policy copy for Cotrainr MVP (verified behaviour only).
abstract final class PrivacyPolicyContent {
  static const title = 'Privacy Policy';
  static const tagline = 'Your data. Your choices.';
  static const version = LegalDocumentMeta.version;

  static const atAGlance = <String>[
    'What we collect to run Cotrainr',
    'How health, nutrition and location are used',
    'What Trainers and Nutritionists can access',
    'Your controls, requests and contact options',
  ];

  static const introCallout =
      'This Privacy Policy describes how Cotrainr handles personal information '
      'in the current MVP. It is written to match product behaviour. Some legal '
      'details (operator identity, retention periods, governing law and similar) '
      'are still marked as pending business decisions and are not invented here.';

  static List<LegalSectionData> get sections => [
        const LegalSectionData(
          number: '01',
          title: 'About this Privacy Policy',
          body:
              'This Privacy Policy explains what information Cotrainr collects, '
              'how we use it, when it may be shared, and the choices available to '
              'you.\n\n'
              'What this means\n\n'
              'Cotrainr is a fitness and nutrition platform that helps Members '
              'track activity and meals, discover Trainers and Nutritionists, '
              'message providers, and (where offered) join video sessions via '
              'Google Meet.\n\n'
              'This in-app document is the canonical Privacy Policy for the '
              'current app version (${LegalDocumentMeta.version}). We do not rely '
              'on a separate website copy for this release.',
        ),
        LegalSectionData(
          number: '02',
          title: 'Who operates Cotrainr',
          body: LegalBusinessDecisions.operatorCopy,
          callout:
              'Operator name and business address are pending. Contact support '
              'for privacy questions in the meantime.',
        ),
        const LegalSectionData(
          number: '03',
          title: 'Information we collect',
          body:
              'Depending on how you use Cotrainr, we may process the following '
              'high-level categories:\n\n'
              '• Account and profile information you provide\n'
              '• Health and fitness information you enter or allow the app to '
              'read from device health services\n'
              '• Nutrition and meal information you log\n'
              '• Location information when you grant permission\n'
              '• Messages, files and other content you submit\n'
              '• Verification documents if you apply as a Trainer or '
              'Nutritionist\n'
              '• Technical and device information needed to operate the service '
              '(for example session and authentication data, and push tokens '
              'where enabled)\n'
              '• Information from third-party services you choose to connect '
              '(such as Google sign-in or Google Meet, where used)\n\n'
              'We do not claim to collect every possible data category. The '
              'sections below describe the categories relevant to the current '
              'MVP.',
        ),
        const LegalSectionData(
          number: '04',
          title: 'Account and profile information',
          body:
              'When you create or complete a Cotrainr account, we may process:\n\n'
              '• Email address\n'
              '• User ID / username (your public Cotrainr handle)\n'
              '• First and last name\n'
              '• Optional phone number\n'
              '• Date of birth\n'
              '• Gender\n'
              '• Height and weight\n'
              '• Role (Member, Trainer or Nutritionist; the Member role may be '
              'stored internally as “client”)\n'
              '• Profile image and cover image\n'
              '• Bio\n'
              '• Fitness goals\n'
              '• Provider specialties (for Trainers and Nutritionists)\n\n'
              'Your User ID is a public handle on Cotrainr. Email and password '
              'remain the primary password-login method for the MVP. User ID is '
              'not an MVP login method.',
        ),
        const LegalSectionData(
          number: '05',
          title: 'Health, fitness and body information',
          body:
              'Cotrainr may process fitness and body-related information to power '
              'activity tracking and related features. As currently implemented, '
              'this may include:\n\n'
              '• Steps\n'
              '• Activity energy / calories where supported\n'
              '• Distance\n'
              '• Hydration / water intake\n'
              '• Height and weight\n'
              '• BMI calculations derived from height and weight\n'
              '• Fitness goals and related targets or recommendations generated '
              'in-app\n\n'
              'Some of this information is entered by you. Other values may be '
              'read from device integrations you permit, including Android Health '
              'Connect and Apple Health / HealthKit where supported and '
              'configured.\n\n'
              'The app currently requests read-oriented health information '
              'relevant to the metrics above. Cotrainr does not currently process '
              'heart rate, blood pressure, sleep or workout-type categories as '
              'part of this MVP health integration.\n\n'
              'Cotrainr is not a medical record service and does not provide '
              'medical diagnosis. Health permissions are controlled in your '
              'device settings and can be changed or withdrawn there.',
          callout:
              'Health & fitness data is used to operate Cotrainr features. It is '
              'not shared with every provider automatically — see provider '
              'sharing below.',
        ),
        const LegalSectionData(
          number: '06',
          title: 'Nutrition and meal information',
          body:
              'If you use Meal Tracker and related nutrition features, we may '
              'process:\n\n'
              '• Meals and meal items you log\n'
              '• Calories, protein, carbohydrates, fats and other nutrition '
              'values available in the food data Cotrainr uses\n'
              '• Nutrition or planner goals you set\n'
              '• Meal tracking history associated with your account\n\n'
              'Meal photos, where the current app lets you attach them, may '
              'remain stored on your device rather than being uploaded to '
              'Cotrainr servers.\n\n'
              'Cotrainr does not currently use Open Food Facts or barcode '
              'scanning in the MVP.',
        ),
        const LegalSectionData(
          number: '07',
          title: 'Location information',
          body:
              'With your operating-system permission, Cotrainr may access your '
              'device location to support features such as:\n\n'
              '• Finding nearby Trainers\n'
              '• Finding nearby Nutritionists\n'
              '• Discover and nearby fitness services\n\n'
              'Member GPS coordinates used for nearby queries are intended to be '
              'used ephemerally for that request and are not intended to be '
              'stored as your ongoing “current location.”\n\n'
              'Provider and service locations may be stored so Members can '
              'discover services on a map.\n\n'
              'Cotrainr does not claim background location tracking in the MVP. '
              'You can review location permission status and manage it from '
              'Privacy & Security and your device settings. Denying location may '
              'limit nearby discovery features.',
        ),
        const LegalSectionData(
          number: '08',
          title: 'Information shared with Trainers and Nutritionists',
          body:
              'When you connect with a Trainer or Nutritionist, Cotrainr provides '
              'privacy controls so you can choose what certain data those '
              'providers can access through the platform.\n\n'
              'Current controls include:\n\n'
              '• Share Activity Data with Trainer — activity metrics such as '
              'steps, calories, distance and water associated with your daily '
              'metrics\n'
              '• Share Meal Data with Trainer — meals you log in Meal Tracker\n'
              '• Share Meal Logs with Nutritionist — logged meals only\n\n'
              'Nutrition and planner goals are not automatically shared with a '
              'Nutritionist under the meal-log control.\n\n'
              'Access also depends on an accepted provider connection where the '
              'product requires it. Cotrainr does not automatically give every '
              'provider access to your health or meal information.\n\n'
              'Important: for new accounts, these sharing preferences currently '
              'default to on (opt-out). You can change them at any time in '
              'Privacy & Security. Turning a preference off is intended to stop '
              'further provider access through those sharing controls.',
          callout:
              'Sharing defaults are currently on. Review Privacy & Security after '
              'signup if you want to limit what connected providers can see.',
        ),
        const LegalSectionData(
          number: '09',
          title: 'Messages, files and user content',
          body:
              'Cotrainr provides messaging between Members and relevant '
              'providers. Messages may include text and supported attachments or '
              'files.\n\n'
              'We process this content to deliver messaging, display media, and '
              'support safety features such as reporting or blocking where '
              'available.\n\n'
              'Newer chat attachments are stored using private, '
              'participant-authorized storage. Older attachments created under an '
              'earlier public-storage approach may still exist until a separate '
              'migration is completed. Do not assume that every historical file '
              'has always been private.\n\n'
              'We also process other content you submit, such as profile media '
              'and provider reviews where those features are available.\n\n'
              'Cotrainr does not claim end-to-end encryption for messaging. No '
              'messaging system can promise absolute confidentiality. Authorized '
              'personnel, service providers and safety tooling may process '
              'content as needed to operate and protect the service.',
        ),
        const LegalSectionData(
          number: '10',
          title: 'Trainer and Nutritionist verification information',
          body:
              'If you apply to be verified as a Trainer or Nutritionist, Cotrainr '
              'may collect identity documents, certificates and professional '
              'information you submit.\n\n'
              'Verification documents are stored in private storage. Access is '
              'limited through authenticated and authorized retrieval (including '
              'short-lived signed access where used).\n\n'
              'Verification helps Cotrainr review professional submissions. It '
              'does not mean a government authority has verified you, and it does '
              'not guarantee suitability, performance or outcomes for Members.',
        ),
        const LegalSectionData(
          number: '11',
          title: 'Authentication and social login',
          body:
              'Cotrainr supports email and password accounts. Password reset is '
              'handled by email.\n\n'
              'You may also sign in with Google where that option is offered. '
              'Where shown in the app and configured by Cotrainr, additional '
              'social login options (such as Apple or Microsoft) may also be '
              'available through our authentication provider.\n\n'
              'When you use social login, the provider shares limited account '
              'information with Cotrainr (for example identity and email, '
              'depending on the provider and your choices) so we can create or '
              'connect your session.',
        ),
        const LegalSectionData(
          number: '12',
          title: 'Video sessions and integrations',
          body:
              'Where video sessions are offered, Cotrainr may use Google Meet as '
              'the third-party video service. Cotrainr does not operate its own '
              'video infrastructure for live sessions.\n\n'
              'Connecting Google Meet may involve Google authorization (OAuth), '
              'meeting links, session scheduling metadata, and related account '
              'details required by the integration (such as a connected Google '
              'account email where needed).\n\n'
              'Cotrainr does not record the video or audio of Meet sessions. '
              'Google processes Meet media and related information under Google’s '
              'own terms and privacy policy.',
        ),
        const LegalSectionData(
          number: '13',
          title: 'Notifications and device information',
          body:
              'Cotrainr may use local notifications on your device for reminders '
              'and in-app prompts where those features are enabled.\n\n'
              'Push notifications may be used where push delivery is enabled for '
              'your device and account. Where Firebase Cloud Messaging (FCM) is '
              'used, we may store a push token and related delivery preferences '
              'so we can send notifications you have allowed.\n\n'
              'Availability can depend on platform setup and permission status. '
              'You can change notification permissions in your device settings.\n\n'
              'We may also process technical information needed to secure and '
              'operate the app, such as authentication tokens and basic device or '
              'session data.',
        ),
        const LegalSectionData(
          number: '14',
          title: 'How we use your information',
          body:
              'We use personal information to:\n\n'
              '• Create and manage your account\n'
              '• Provide fitness tracking, meal tracking and related features\n'
              '• Support Discover and nearby provider or service features\n'
              '• Enable messaging and (where used) Google Meet video sessions\n'
              '• Support Trainer/Nutritionist onboarding and verification\n'
              '• Apply your privacy and sharing preferences\n'
              '• Deliver notifications you have allowed\n'
              '• Respond to support and privacy requests\n'
              '• Maintain security, prevent abuse and enforce our Terms\n'
              '• Improve reliability and user experience of the MVP\n\n'
              'We do not sell your personal information.',
        ),
        LegalSectionData(
          number: '15',
          title: 'Legal bases for processing',
          body: LegalBusinessDecisions.legalBasesCopy,
        ),
        LegalSectionData(
          number: '16',
          title: 'Health and special-category information',
          body: LegalBusinessDecisions.specialCategoryCopy,
          callout:
              'Health-related processing is limited to operating Cotrainr '
              'features. It is not medical care.',
        ),
        const LegalSectionData(
          number: '17',
          title: 'When we share information',
          body:
              'We may share information with:\n\n'
              '• Trainers or Nutritionists you connect with, according to your '
              'sharing preferences and the relationship status in the product\n'
              '• Service providers that help us operate Cotrainr (hosting, '
              'authentication, storage, mapping, video and similar)\n'
              '• Other users, where you choose to make information public (for '
              'example profile details or reviews)\n'
              '• Professional advisers or authorities when required by law or to '
              'protect rights, safety and security\n\n'
              'We do not share your information with advertisers as a sold data '
              'product in the MVP.',
        ),
        const LegalSectionData(
          number: '18',
          title: 'Third-party service providers',
          body:
              'Cotrainr uses third-party services to operate the app. Depending '
              'on the feature, these may include:\n\n'
              '• Supabase — backend, authentication, database and storage\n'
              '• Google / Firebase — OAuth sign-in, Google Meet integration, '
              'Firebase Cloud Messaging where push is enabled, and Google Fonts '
              'where fonts are loaded from Google\n'
              '• Google Meet — video session creation and join links where '
              'offered\n'
              '• Mapping and Places / place-search providers — maps and nearby '
              'discovery features\n'
              '• Google Play / platform store services — app distribution and, '
              'when live, Android billing pathways\n'
              '• Apple or Microsoft — social sign-in where those options are '
              'offered and configured\n'
              '• Health Connect / Apple Health — device health data you permit\n'
              '• Device operating-system services — permissions, local '
              'notifications and similar platform features\n\n'
              'These providers process information under their own terms and '
              'privacy policies where applicable.\n\n'
              'The MVP does not currently integrate Stripe, Razorpay, Open Food '
              'Facts, Crashlytics or separate analytics SDKs as live product '
              'services.',
        ),
        LegalSectionData(
          number: '19',
          title: 'International data transfers',
          body: LegalBusinessDecisions.transfersCopy,
        ),
        LegalSectionData(
          number: '20',
          title: 'Data retention',
          body: LegalBusinessDecisions.retentionCopy,
        ),
        const LegalSectionData(
          number: '21',
          title: 'Security',
          body:
              'Cotrainr uses technical and organizational safeguards designed to '
              'protect personal information. These include authentication, access '
              'controls, database authorization rules and private storage for '
              'certain sensitive files where applicable.\n\n'
              'No online service can guarantee absolute security. Please protect '
              'your password and device access.\n\n'
              'Cotrainr does not claim end-to-end encryption for messaging or for '
              'Google Meet sessions handled by Google.',
        ),
        const LegalSectionData(
          number: '22',
          title: 'Your privacy choices and controls',
          body:
              'You can:\n\n'
              '• Update profile information in the app\n'
              '• Change provider sharing preferences in Privacy & Security\n'
              '• Manage location, health, camera and notification permissions in '
              'your device settings (and review location status in Privacy & '
              'Security)\n'
              '• Disconnect Google Meet where that option is offered\n'
              '• Contact support for privacy questions\n\n'
              'Some features will not work fully if required permissions are '
              'denied.',
        ),
        LegalSectionData(
          number: '23',
          title: 'Access, correction and data requests',
          body:
              'You may review and update much of your profile information '
              'directly in Cotrainr.\n\n'
              'An automated in-app “Download My Data” export is not available yet '
              '(shown as Coming soon in settings).\n\n'
              'For access, correction or other privacy requests that you cannot '
              'complete in the app, email ${LegalDocumentMeta.supportEmail}. We '
              'do not promise a specific export file format at this time.',
        ),
        LegalSectionData(
          number: '24',
          title: 'Account deletion',
          body:
              'The MVP does not provide immediate automated in-app account '
              'deletion.\n\n'
              'You can request account deletion from Privacy & Security '
              '(“Request Account Deletion”) or by emailing '
              '${LegalDocumentMeta.supportEmail}. Support will confirm with you '
              'before deleting an account and related data we control.\n\n'
              'We do not claim that deletion is instant, and we have not '
              'published a specific deletion SLA in this Policy.',
          callout:
              'Account deletion is currently a support request — not a one-tap '
              'wipe.',
        ),
        LegalSectionData(
          number: '25',
          title: 'Children’s privacy / age eligibility',
          body: LegalBusinessDecisions.childrenPrivacyCopy,
        ),
        const LegalSectionData(
          number: '26',
          title: 'Changes to this Privacy Policy',
          body:
              'We may update this Privacy Policy as Cotrainr evolves. When we '
              'publish a new version, we will update the version label shown in '
              'the app.\n\n'
              'The current accepted version identifier is '
              '${LegalDocumentMeta.version}. We will not silently change the '
              'meaning of an already-accepted version without issuing a new '
              'version through Cotrainr’s legal-version process.\n\n'
              'Whether existing users must re-accept an updated Policy is a '
              'product and legal decision that will be communicated when a new '
              'version ships.',
        ),
        LegalSectionData(
          number: '27',
          title: 'Contact us',
          body:
              'For privacy questions, data requests or account-deletion requests, '
              'contact:\n\n'
              '${LegalDocumentMeta.supportEmail}\n\n'
              'Please do not use noreply addresses for privacy contact. '
              'Transactional system email may still be sent from outbound '
              'addresses that do not accept replies.',
        ),
      ];
}
