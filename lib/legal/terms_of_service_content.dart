import '../widgets/legal/legal_document.dart';
import 'legal_document_meta.dart';

/// Production Terms of Service copy for Cotrainr MVP (verified behaviour only).
abstract final class TermsOfServiceContent {
  static const title = 'Terms of Service';
  static const tagline = 'The rules for using Cotrainr.';
  static const version = LegalDocumentMeta.version;

  static const atAGlance = <String>[
    'Account responsibilities',
    'Member, Trainer and Nutritionist relationships',
    'Fitness and nutrition responsibilities',
    'Acceptable use and safety',
  ];

  static const introCallout =
      'These Terms govern your use of Cotrainr. Some clauses that depend on '
      'unresolved business decisions (legal entity, governing law, payments) are '
      'marked clearly instead of being invented.';

  static List<LegalSectionData> get sections => [
        const LegalSectionData(
          number: '01',
          title: 'About these Terms',
          body:
              'These Terms of Service (“Terms”) are an agreement between you and '
              'Cotrainr for use of the Cotrainr mobile application and related '
              'services.\n\n'
              'This in-app document is the canonical Terms for the current app '
              'version (2026-08-01).',
        ),
        const LegalSectionData(
          number: '02',
          title: 'Acceptance of Terms',
          body:
              'By creating an account, completing onboarding, or continuing to use '
              'Cotrainr, you agree to these Terms and to our Privacy Policy.\n\n'
              'If you do not agree, do not use Cotrainr.',
        ),
        LegalSectionData(
          number: '03',
          title: 'Eligibility',
          body:
              '${LegalDocumentMeta.decisionRequiredPrefix} Minimum age and '
              'eligibility rules have not been finalized for publication.\n\n'
              'You must be able to form a binding contract in your country and must '
              'provide accurate registration information. If Cotrainr later publishes '
              'a minimum age, you must meet it to continue using the service.',
        ),
        const LegalSectionData(
          number: '04',
          title: 'Your Cotrainr account',
          body:
              'You are responsible for your account credentials and for activity that '
              'occurs under your account.\n\n'
              'Keep your password confidential. Tell support promptly if you believe '
              'your account has been compromised.\n\n'
              'You must provide information that is accurate and keep it reasonably '
              'up to date.',
        ),
        const LegalSectionData(
          number: '05',
          title: 'User ID / public handle',
          body:
              'Your User ID (username) is a public Cotrainr handle. Other users may '
              'see it in contexts such as profiles or messaging.\n\n'
              'User ID is not an MVP password-login method. Do not choose a handle that '
              'impersonates another person or organization, or that violates these Terms.',
        ),
        const LegalSectionData(
          number: '06',
          title: 'Member accounts',
          body:
              'Member accounts (shown as Member in the product; stored internally as '
              '“client” in some systems) can use Cotrainr features such as activity '
              'tracking, meal tracking, Discover, messaging with connected providers, '
              'and related tools.\n\n'
              'Members control certain sharing preferences in Privacy & Security. '
              'Those preferences currently default to sharing enabled (opt-out). '
              'Review them if you want to limit what connected providers can access.',
        ),
        const LegalSectionData(
          number: '07',
          title: 'Trainer accounts',
          body:
              'Trainer accounts are for fitness professionals who offer services '
              'through or in connection with Cotrainr.\n\n'
              'Trainers are responsible for the professional services they provide to '
              'Members. Cotrainr is the software platform and does not personally '
              'deliver every training service on a Trainer’s behalf.\n\n'
              'Trainers must keep professional information reasonably accurate and '
              'comply with applicable laws and professional rules.',
        ),
        const LegalSectionData(
          number: '08',
          title: 'Nutritionist accounts',
          body:
              'Nutritionist accounts are for nutrition professionals who offer '
              'services through or in connection with Cotrainr.\n\n'
              'Nutritionists are responsible for the professional guidance they '
              'provide. Cotrainr is the software platform and does not personally '
              'deliver every nutrition service on a Nutritionist’s behalf.\n\n'
              'Nutritionists must keep professional information reasonably accurate '
              'and comply with applicable laws and professional rules.',
        ),
        const LegalSectionData(
          number: '09',
          title: 'Provider verification',
          body:
              'Trainers and Nutritionists may be asked to submit identity documents, '
              'certificates and professional details for verification review.\n\n'
              'Verification means Cotrainr has reviewed submitted materials under its '
              'process. It does not guarantee government certification, competence, '
              'suitability or outcomes, and it does not create an employment '
              'relationship with Cotrainr unless separately agreed in writing.',
        ),
        const LegalSectionData(
          number: '10',
          title: 'Trainer and Nutritionist relationships',
          body:
              'Members may request or accept connections with Trainers and '
              'Nutritionists. Relationship status in the product (for example '
              'requested or accepted) affects what features and data sharing apply.\n\n'
              'Any training or nutrition engagement between a Member and a provider '
              'is primarily between those parties, subject to these Terms and the '
              'Privacy Policy for platform data handling.\n\n'
              'Cotrainr may provide tools for messaging, discovery and (where '
              'enabled) video sessions, but Cotrainr is not a party to every offline '
              'or professional advice relationship unless expressly stated.',
        ),
        const LegalSectionData(
          number: '11',
          title: 'Fitness and nutrition information',
          body:
              'Cotrainr provides software tools for logging activity, meals, goals '
              'and related information. Content and recommendations in the app are '
              'general fitness and nutrition tools, not personalized medical care.\n\n'
              'You are responsible for deciding whether exercise, diet changes or '
              'targets are appropriate for you.',
        ),
        const LegalSectionData(
          number: '12',
          title: 'No medical advice',
          body:
              'Cotrainr does not provide medical diagnosis, treatment or emergency '
              'care. Nothing in the app replaces advice from a qualified clinician.\n\n'
              'If you have a medical condition, injury, pregnancy, eating disorder '
              'history or other health concern, consult an appropriate professional '
              'before using fitness or nutrition features.\n\n'
              'If you think you are experiencing a medical emergency, contact local '
              'emergency services immediately.',
          callout:
              'Cotrainr is a fitness and nutrition platform — not a medical service.',
        ),
        const LegalSectionData(
          number: '13',
          title: 'Exercise and health risks',
          body:
              'Physical activity and dietary changes involve risk. You use Cotrainr’s '
              'fitness and nutrition features at your own judgment and risk, taking '
              'your personal circumstances into account.\n\n'
              'Stop activity that causes concerning pain, dizziness or other warning '
              'signs and seek professional help when needed.\n\n'
              '[Legal review recommended] Broader liability and risk-allocation '
              'language should be reviewed by counsel before production sign-off. '
              'These Terms do not ask you to waive rights that cannot legally be waived.',
        ),
        const LegalSectionData(
          number: '14',
          title: 'Messaging and communications',
          body:
              'Cotrainr may allow messaging between Members and providers. You are '
              'responsible for the content you send.\n\n'
              'Do not use messaging to harass, scam, threaten or otherwise harm '
              'others. Cotrainr may use reporting and blocking tools where available '
              'to support safety.',
        ),
        const LegalSectionData(
          number: '15',
          title: 'User-generated content',
          body:
              'You retain ownership of content you submit through Cotrainr (such as '
              'profile text, messages, reviews and images), subject to the rights '
              'needed to operate the service.\n\n'
              'You grant Cotrainr a limited, worldwide, non-exclusive licence to host, '
              'store, display and transmit that content solely to operate, secure and '
              'improve Cotrainr features you use. This is not a broad perpetual '
              'commercial licence for unrelated advertising use.\n\n'
              'You represent that you have the rights needed to submit the content '
              'and that it does not violate law or these Terms.\n\n'
              'Social feed features such as CoCircle are not currently available in '
              'the MVP, even if related code exists in the product.',
        ),
        const LegalSectionData(
          number: '16',
          title: 'Reviews, reports and community safety',
          body:
              'Members may leave reviews for providers where that feature is offered. '
              'Reviews must be honest and not abusive or fraudulent.\n\n'
              'You may report or block users where those tools are available. Do not '
              'misuse reporting systems.\n\n'
              'Cotrainr may investigate reports and take action it reasonably considers '
              'appropriate, including limiting features or suspending accounts.',
        ),
        const LegalSectionData(
          number: '17',
          title: 'Acceptable use',
          body:
              'You agree to use Cotrainr lawfully and respectfully. You must not:\n\n'
              '• Access another person’s account without permission\n'
              '• Impersonate others or misrepresent your identity or credentials\n'
              '• Harass, abuse, threaten or exploit other users\n'
              '• Upload unlawful, harmful or infringing content\n'
              '• Distribute malware or attempt to disrupt the service\n'
              '• Commit fraud or social-engineering attacks\n'
              '• Misuse provider verification credentials or documents\n'
              '• Circumvent security or access controls\n'
              '• Scrape or overload the service in a way that harms operations\n'
              '• Use Cotrainr for any purpose that violates applicable law',
        ),
        const LegalSectionData(
          number: '18',
          title: 'Prohibited conduct',
          body:
              'In addition to the acceptable-use rules, you must not attempt to reverse '
              'engineer the service except where mandatory law allows, resell '
              'unauthorized access, or use Cotrainr to build a competing service by '
              'improperly extracting non-public data.\n\n'
              'We may remove content or restrict accounts that violate these Terms.',
        ),
        const LegalSectionData(
          number: '19',
          title: 'Third-party services',
          body:
              'Cotrainr depends on third-party services such as hosting and '
              'authentication providers, mapping providers, device health platforms '
              'and (where used) Zoom. Your use of those services may also be subject '
              'to their terms.\n\n'
              'Cotrainr is not responsible for third-party services it does not control, '
              'except to the extent required by law.',
        ),
        const LegalSectionData(
          number: '20',
          title: 'Zoom and video services',
          body:
              'Video sessions, where offered, may be delivered through Zoom. Cotrainr '
              'does not operate its own video infrastructure.\n\n'
              'You are responsible for complying with Zoom’s terms when you connect '
              'or join sessions.',
        ),
        const LegalSectionData(
          number: '21',
          title: 'Location and discovery services',
          body:
              'Discover and nearby features may use device location (with permission) '
              'and stored provider or service locations.\n\n'
              'Location accuracy depends on your device and map providers. Cotrainr '
              'does not guarantee that every nearby result is complete or current.',
        ),
        const LegalSectionData(
          number: '22',
          title: 'Intellectual property',
          body:
              'Cotrainr, including its branding, software, design and content we '
              'provide, is owned by Cotrainr or its licensors and is protected by '
              'intellectual-property laws.\n\n'
              'Except for the limited rights needed to use the app, these Terms do '
              'not grant you ownership of Cotrainr intellectual property.',
        ),
        LegalSectionData(
          number: '23',
          title: 'Subscriptions and payments',
          body:
              'In-app purchases and live billing are not currently active in the MVP. '
              'Subscription screens may describe future plans as coming soon.\n\n'
              '${LegalDocumentMeta.decisionRequiredPrefix} Detailed subscription, '
              'pricing, payment-processor and tax terms will be published before paid '
              'features go live. Do not treat placeholder subscription UI as a binding '
              'paid plan.',
        ),
        LegalSectionData(
          number: '24',
          title: 'Cancellation and refunds',
          body:
              '${LegalDocumentMeta.decisionRequiredPrefix} Cancellation and refund '
              'rules will be published when paid subscriptions or in-app purchases '
              'become available.\n\n'
              'Because live billing is not active in the MVP, there is no current '
              'in-app paid subscription to cancel through a payment provider.',
        ),
        const LegalSectionData(
          number: '25',
          title: 'Service availability and changes',
          body:
              'We aim to keep Cotrainr available, but we do not guarantee uninterrupted '
              'or error-free service. Features may change, be delayed or be withdrawn '
              'as the product evolves.\n\n'
              'We may perform maintenance or updates that temporarily affect access.',
        ),
        const LegalSectionData(
          number: '26',
          title: 'Suspension and termination',
          body:
              'We may suspend or terminate access if you violate these Terms, create '
              'risk for other users, or if we need to protect the service.\n\n'
              'You may stop using Cotrainr at any time. Account deletion requests are '
              'handled as described below and in the Privacy Policy.',
        ),
        LegalSectionData(
          number: '27',
          title: 'Account deletion',
          body:
              'Immediate automated in-app account deletion is not available in the MVP.\n\n'
              'You may request deletion through Privacy & Security or by contacting '
              '${LegalDocumentMeta.supportEmail}. Support will confirm before deleting '
              'an account. Deletion is not claimed to be instant.',
        ),
        const LegalSectionData(
          number: '28',
          title: 'Disclaimers',
          body:
              'Cotrainr is provided on an “as is” and “as available” basis to the '
              'fullest extent permitted by law.\n\n'
              'We disclaim warranties that are not required by law, including implied '
              'warranties of merchantability, fitness for a particular purpose and '
              'non-infringement, except where such disclaimers are not allowed.\n\n'
              '[Legal review recommended] Final warranty disclaimer language should '
              'be reviewed by counsel for each launch jurisdiction.',
        ),
        const LegalSectionData(
          number: '29',
          title: 'Limitation of liability',
          body:
              'To the fullest extent permitted by law, Cotrainr and its operators are '
              'not liable for indirect, incidental, special, consequential or punitive '
              'damages, or for lost profits, data or goodwill, arising from your use '
              'of the service.\n\n'
              'Nothing in these Terms excludes liability that cannot be excluded under '
              'applicable law (for example liability for death or personal injury '
              'caused by negligence where such exclusion is prohibited).\n\n'
              '[Legal review recommended] Cap amounts and jurisdiction-specific limits '
              'have not been set and must not be invented here.',
        ),
        LegalSectionData(
          number: '30',
          title: 'Indemnity',
          body:
              '${LegalDocumentMeta.decisionRequiredPrefix} A full indemnity clause has '
              'not been approved for this release.\n\n'
              'Pending legal review, you agree to cooperate reasonably with Cotrainr '
              'in resolving claims arising from content you submit or your misuse of '
              'the service.',
        ),
        const LegalSectionData(
          number: '31',
          title: 'Changes to these Terms',
          body:
              'We may update these Terms as Cotrainr changes. Updated Terms will show '
              'a version label in the app.\n\n'
              'The current version identifier is 2026-08-01. Material updates that require '
              'a new acceptance version will follow Cotrainr’s legal-version process. '
              'Whether existing users must re-accept is a separate product and legal '
              'decision.',
        ),
        LegalSectionData(
          number: '32',
          title: 'Governing law',
          body:
              '${LegalDocumentMeta.decisionRequiredPrefix} Governing law and courts / '
              'jurisdiction have not been designated for publication.\n\n'
              'Until that decision is made, disputes will be handled under applicable '
              'mandatory consumer or local laws that cannot be displaced by these Terms.',
        ),
        LegalSectionData(
          number: '33',
          title: 'Contact',
          body:
              'For questions about these Terms, account issues or deletion requests, '
              'contact:\n\n'
              '${LegalDocumentMeta.supportEmail}',
        ),
      ];
}
