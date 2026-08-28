import '../widgets/legal/legal_document.dart';
import 'legal_document_meta.dart';
import 'legal_business_decisions.dart';

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
              'What this means\n\n'
              'This in-app document is the canonical Terms for the current app '
              'version (${LegalDocumentMeta.version}). If wording elsewhere '
              'conflicts with this document for the same version, this in-app '
              'copy controls for that version.\n\n'
              'Related documents\n\n'
              'Our Privacy Policy explains how personal information is handled. '
              'You should read it together with these Terms.',
        ),
        const LegalSectionData(
          number: '02',
          title: 'Acceptance of Terms',
          body:
              'By creating an account, completing onboarding, or continuing to use '
              'Cotrainr, you agree to these Terms and to our Privacy Policy.\n\n'
              'What this means\n\n'
              'If you do not agree, do not create an account and do not use '
              'Cotrainr.\n\n'
              'Your responsibilities\n\n'
              'Make sure you understand the role you select (Member, Trainer or '
              'Nutritionist) and the rules that apply to that role.',
        ),
        LegalSectionData(
          number: '03',
          title: 'Eligibility',
          body: LegalBusinessDecisions.eligibilityAgeCopy,
        ),
        const LegalSectionData(
          number: '04',
          title: 'Your Cotrainr account',
          body:
              'You are responsible for your account credentials and for activity '
              'that occurs under your account.\n\n'
              'Your responsibilities\n\n'
              '• Keep your password confidential and use a strong unique password.\n'
              '• Provide registration information that is accurate and keep it '
              'reasonably up to date.\n'
              '• Tell support promptly if you believe your account has been '
              'compromised.\n\n'
              'When we may take action\n\n'
              'We may restrict or suspend accounts that appear compromised, '
              'misused, or used in breach of these Terms.',
        ),
        const LegalSectionData(
          number: '05',
          title: 'User ID / public handle',
          body:
              'Your User ID (username) is a public Cotrainr handle. Other users '
              'may see it in contexts such as profiles or messaging.\n\n'
              'What this means\n\n'
              'User ID is not an MVP password-login method. Email and password '
              '(and Google sign-in where offered) are the login methods for this '
              'release.\n\n'
              'Your responsibilities\n\n'
              'Do not choose a handle that impersonates another person or '
              'organization, or that otherwise violates these Terms.',
        ),
        const LegalSectionData(
          number: '06',
          title: 'Member accounts',
          body:
              'Member accounts (shown as Member in the product; stored internally '
              'as “client” in some systems) can use Cotrainr features such as '
              'activity tracking, meal tracking, Discover, messaging with '
              'connected providers, Member Pass where offered, and related tools.\n\n'
              'Your responsibilities\n\n'
              'Members control certain sharing preferences in Privacy & Security. '
              'Those preferences currently default to sharing enabled (opt-out). '
              'Review them if you want to limit what connected providers can '
              'access.\n\n'
              'Social feed products such as CoCircle are not part of the current '
              'MVP experience.',
        ),
        const LegalSectionData(
          number: '07',
          title: 'Trainer accounts',
          body:
              'Trainer accounts are for fitness professionals who offer services '
              'through or in connection with Cotrainr.\n\n'
              'What this means\n\n'
              'Trainers are responsible for the professional services they provide '
              'to Members. Cotrainr is the software platform and does not '
              'personally deliver every training service on a Trainer’s behalf.\n\n'
              'Your responsibilities\n\n'
              'Trainers must keep professional information reasonably accurate and '
              'comply with applicable laws and professional rules. Do not claim '
              'credentials you do not hold.',
        ),
        const LegalSectionData(
          number: '08',
          title: 'Nutritionist accounts',
          body:
              'Nutritionist accounts are for nutrition professionals who offer '
              'services through or in connection with Cotrainr.\n\n'
              'What this means\n\n'
              'Nutritionists are responsible for the professional guidance they '
              'provide. Cotrainr is the software platform and does not personally '
              'deliver every nutrition service on a Nutritionist’s behalf.\n\n'
              'Your responsibilities\n\n'
              'Nutritionists must keep professional information reasonably '
              'accurate and comply with applicable laws and professional rules. '
              'Do not claim credentials you do not hold.',
        ),
        const LegalSectionData(
          number: '09',
          title: 'Provider verification',
          body:
              'Trainers and Nutritionists may be asked to submit identity '
              'documents, certificates and professional details for verification '
              'review.\n\n'
              'What this means\n\n'
              'Verification means Cotrainr has reviewed submitted materials under '
              'its process. It does not guarantee government certification, '
              'competence, suitability or outcomes, and it does not create an '
              'employment relationship with Cotrainr unless separately agreed in '
              'writing.\n\n'
              'Your responsibilities\n\n'
              'Submit only authentic documents. Misrepresentation may lead to '
              'rejection, suspension or termination.',
        ),
        const LegalSectionData(
          number: '10',
          title: 'Trainer and Nutritionist relationships',
          body:
              'Members may request or accept connections with Trainers and '
              'Nutritionists. Relationship status in the product (for example '
              'requested or accepted) affects what features and data sharing '
              'apply.\n\n'
              'What this means\n\n'
              'Any training or nutrition engagement between a Member and a '
              'provider is primarily between those parties, subject to these '
              'Terms and the Privacy Policy for platform data handling.\n\n'
              'Cotrainr may provide tools for messaging, discovery and (where '
              'enabled) video sessions, but Cotrainr is not a party to every '
              'offline or professional advice relationship unless expressly '
              'stated.\n\n'
              'Your responsibilities\n\n'
              'Use relationship tools honestly. Do not fabricate connections or '
              'pressure others to share data they have chosen to withhold.',
        ),
        const LegalSectionData(
          number: '11',
          title: 'Fitness and nutrition information',
          body:
              'Cotrainr provides software tools for logging activity, meals, '
              'goals and related information. Content and recommendations in the '
              'app are general fitness and nutrition tools, not personalized '
              'medical care.\n\n'
              'Your responsibilities\n\n'
              'You are responsible for deciding whether exercise, diet changes or '
              'targets are appropriate for you, including advice you receive from '
              'providers you choose to work with.',
        ),
        const LegalSectionData(
          number: '12',
          title: 'No medical advice',
          body:
              'Cotrainr does not provide medical diagnosis, treatment or emergency '
              'care. Nothing in the app replaces advice from a qualified '
              'clinician.\n\n'
              'Your responsibilities\n\n'
              'If you have a medical condition, injury, pregnancy, eating '
              'disorder history or other health concern, consult an appropriate '
              'professional before using fitness or nutrition features.\n\n'
              'If you think you are experiencing a medical emergency, contact '
              'local emergency services immediately.',
          callout:
              'Cotrainr is a fitness and nutrition platform — not a medical '
              'service.',
        ),
        const LegalSectionData(
          number: '13',
          title: 'Exercise and health risks',
          body:
              'Physical activity and dietary changes involve risk. You use '
              'Cotrainr’s fitness and nutrition features at your own judgment and '
              'risk, taking your personal circumstances into account.\n\n'
              'Your responsibilities\n\n'
              'Stop activity that causes concerning pain, dizziness or other '
              'warning signs and seek professional help when needed.\n\n'
              'What this means\n\n'
              'These Terms do not ask you to waive rights that cannot legally be '
              'waived. Broader liability and risk-allocation language remains '
              'subject to legal review for each launch jurisdiction.',
        ),
        const LegalSectionData(
          number: '14',
          title: 'Messaging and communications',
          body:
              'Cotrainr may allow messaging between Members and connected '
              'providers. You are responsible for the content you send.\n\n'
              'What this means\n\n'
              'Messaging is intended for provider–Member coaching and related '
              'communications. It is not a general social network inbox.\n\n'
              'Your responsibilities\n\n'
              'Do not use messaging to harass, scam, threaten or otherwise harm '
              'others. Cotrainr may use reporting and blocking tools where '
              'available to support safety.\n\n'
              'Cotrainr does not claim end-to-end encryption for in-app messaging.',
        ),
        const LegalSectionData(
          number: '15',
          title: 'User-generated content',
          body:
              'You retain ownership of content you submit through Cotrainr (such '
              'as profile text, messages, reviews and images), subject to the '
              'rights needed to operate the service.\n\n'
              'What this means\n\n'
              'You grant Cotrainr a limited, worldwide, non-exclusive licence to '
              'host, store, display and transmit that content solely to operate, '
              'secure and improve Cotrainr features you use. This is not a broad '
              'perpetual commercial licence for unrelated advertising use.\n\n'
              'Your responsibilities\n\n'
              'You represent that you have the rights needed to submit the '
              'content and that it does not violate law or these Terms.\n\n'
              'Social feed features such as CoCircle are not currently available '
              'in the MVP, even if related code exists in the product.',
        ),
        const LegalSectionData(
          number: '16',
          title: 'Reviews, reports and community safety',
          body:
              'Members may leave reviews for providers where that feature is '
              'offered. Reviews must be honest and not abusive or fraudulent.\n\n'
              'Your responsibilities\n\n'
              'You may report or block users where those tools are available. Do '
              'not misuse reporting systems to harass others or to evade '
              'legitimate moderation.\n\n'
              'When we may take action\n\n'
              'Cotrainr may investigate reports and take action it reasonably '
              'considers appropriate, including limiting features or suspending '
              'accounts.',
        ),
        const LegalSectionData(
          number: '17',
          title: 'Acceptable use',
          body:
              'You agree to use Cotrainr lawfully, honestly and respectfully.\n\n'
              'What this means\n\n'
              'Treat other users fairly, follow these Terms, and use the product '
              'only for its intended fitness and nutrition collaboration '
              'purposes.\n\n'
              'Detailed prohibited conduct is listed in the next section.',
        ),
        const LegalSectionData(
          number: '18',
          title: 'Prohibited conduct',
          body:
              'You must not do any of the following:\n\n'
              'Safety and behaviour\n\n'
              '• Harass, bully, threaten, stalk, intimidate or exploit other '
              'users\n'
              '• Share hate speech, discriminatory abuse, or sexual content that '
              'is unwanted or unlawful\n'
              '• Encourage self-harm, disordered eating, or unsafe training '
              'practices as a form of harm\n'
              '• Impersonate another person, brand or organization\n'
              '• Misrepresent your identity, role, qualifications or verification '
              'status\n\n'
              'Fraud, scams and commercial misuse\n\n'
              '• Run scams, phishing or social-engineering attacks through '
              'Cotrainr\n'
              '• Commit payment, subscription or entitlement fraud\n'
              '• Misuse Member Pass, membership cards, QR codes, Member IDs or '
              'partner-centre benefits (including forging, sharing for improper '
              'entry, or presenting another person’s Pass as your own)\n'
              '• Submit false or altered verification documents or professional '
              'credentials\n'
              '• Misuse reporting, blocking or safety tools\n\n'
              'Security and platform integrity\n\n'
              '• Access another person’s account without permission\n'
              '• Attempt to bypass, probe or defeat authentication, authorization, '
              'row-level security (RLS), signed URLs, private storage or other '
              'access controls\n'
              '• Scrape, harvest or overload the service in a way that harms '
              'operations or other users\n'
              '• Distribute malware, ransomware or other harmful code\n'
              '• Reverse engineer the service except where mandatory law allows\n'
              '• Resell unauthorized access, or extract non-public data to build a '
              'competing service improperly\n\n'
              'Content and communications\n\n'
              '• Upload unlawful, infringing, deceptive or otherwise harmful '
              'content\n'
              '• Spam users with unsolicited commercial messages\n'
              '• Record, capture or redistribute video or audio from sessions '
              'without required consent and legal permission\n'
              '• Use Cotrainr for any purpose that violates applicable law\n\n'
              'When we may take action\n\n'
              'We may remove content, limit features, suspend or terminate '
              'accounts, and cooperate with partners or authorities where '
              'reasonably necessary to address violations.',
        ),
        const LegalSectionData(
          number: '19',
          title: 'Third-party services',
          body:
              'Cotrainr depends on third-party services to operate. Depending on '
              'the feature, these may include:\n\n'
              '• Google services (for example sign-in and related Google APIs)\n'
              '• Firebase (for example Cloud Messaging where push is enabled)\n'
              '• Supabase (backend, authentication, database and storage)\n'
              '• Mapping and place-search providers used for Discover and nearby '
              'features\n'
              '• Google Play / platform store services where Android distribution '
              'or billing applies\n'
              '• Health Connect and Apple Health / HealthKit where you grant '
              'permission\n\n'
              'What this means\n\n'
              'Your use of those services may also be subject to their terms and '
              'privacy policies. Cotrainr is not responsible for third-party '
              'services it does not control, except to the extent required by '
              'law.',
        ),
        const LegalSectionData(
          number: '20',
          title: 'Video sessions and third-party video services',
          body:
              'Where video sessions are offered, Cotrainr may schedule sessions and '
              'provide join links using Google Meet through a Google account '
              'connection (OAuth) you authorize.\n\n'
              'What this means\n\n'
              'Cotrainr may process Meet-related session metadata needed to '
              'operate the feature (for example meeting links, titles, scheduled '
              'times, participants and connection status). Video and audio of the '
              'session itself are handled by Google Meet, not by a Cotrainr-owned '
              'recording pipeline.\n\n'
              'Cotrainr does not record the video or audio of Meet sessions.\n\n'
              'Your responsibilities\n\n'
              '• Connect only an account you are authorized to use.\n'
              '• Comply with Google’s terms when you connect or join sessions.\n'
              '• Do not make unauthorized recordings of sessions.',
        ),
        const LegalSectionData(
          number: '21',
          title: 'Location and discovery services',
          body:
              'Discover and nearby features may use device location (with '
              'permission) and stored provider or service locations.\n\n'
              'What this means\n\n'
              'Location accuracy depends on your device and map providers. '
              'Cotrainr does not guarantee that every nearby result is complete '
              'or current.\n\n'
              'Your responsibilities\n\n'
              'Grant location permission only if you want nearby discovery '
              'features. You can change permission in your device settings.',
        ),
        const LegalSectionData(
          number: '22',
          title: 'Intellectual property',
          body:
              'Cotrainr, including its branding, software, design and content we '
              'provide, is owned by Cotrainr or its licensors and is protected by '
              'intellectual-property laws.\n\n'
              'What this means\n\n'
              'Except for the limited rights needed to use the app, these Terms do '
              'not grant you ownership of Cotrainr intellectual property.\n\n'
              'Your responsibilities\n\n'
              'Do not copy, modify or redistribute Cotrainr materials except as '
              'allowed by law or with written permission.',
        ),
        LegalSectionData(
          number: '23',
          title: 'Subscriptions and payments',
          body:
              'In-app purchases and live billing are not currently active in the '
              'MVP. Subscription or Member Pass screens may describe future plans '
              'as coming soon.\n\n'
              'What this means\n\n'
              'Do not treat placeholder subscription UI as a binding paid plan.\n\n'
              '${LegalBusinessDecisions.requiredPrefix} Detailed subscription, '
              'pricing, payment-processor and tax terms will be published before '
              'paid features go live. When Android billing is offered, purchases '
              'may be processed through Google Play according to Play’s rules and '
              'the then-current Cotrainr payment terms.',
        ),
        LegalSectionData(
          number: '24',
          title: 'Cancellation and refunds',
          body:
              '${LegalBusinessDecisions.requiredPrefix} Cancellation and refund '
              'rules will be published when paid subscriptions or in-app '
              'purchases become available.\n\n'
              'What this means\n\n'
              'Because live billing is not active in the MVP, there is no current '
              'in-app paid subscription to cancel through a payment provider.\n\n'
              'When Android billing launches through Google Play, store-level '
              'cancellation and refund pathways may also apply under Google’s '
              'policies, in addition to any Cotrainr terms published at that '
              'time.',
        ),
        const LegalSectionData(
          number: '25',
          title: 'Service availability and changes',
          body:
              'We aim to keep Cotrainr available, but we do not guarantee '
              'uninterrupted or error-free service. Features may change, be '
              'delayed or be withdrawn as the product evolves.\n\n'
              'What this means\n\n'
              'We may perform maintenance or updates that temporarily affect '
              'access. We may also introduce, rename or retire features (including '
              'integrations) to improve security or product quality.',
        ),
        const LegalSectionData(
          number: '26',
          title: 'Suspension and termination',
          body:
              'We may suspend or terminate access if you violate these Terms, '
              'create risk for other users, or if we need to protect the '
              'service.\n\n'
              'Your responsibilities\n\n'
              'You may stop using Cotrainr at any time. Account deletion requests '
              'are handled as described below and in the Privacy Policy.\n\n'
              'When we may take action\n\n'
              'Where practical, we may limit action to the conduct involved, but '
              'serious or repeated violations may result in full account '
              'restriction.',
        ),
        LegalSectionData(
          number: '27',
          title: 'Account deletion',
          body:
              'Immediate automated in-app account deletion is not available in the '
              'MVP.\n\n'
              'What this means\n\n'
              'You may request deletion through Privacy & Security or by '
              'contacting ${LegalDocumentMeta.supportEmail}. Support will confirm '
              'before deleting an account. Deletion is not claimed to be '
              'instant.\n\n'
              'Related data handling after deletion is described in the Privacy '
              'Policy.',
        ),
        const LegalSectionData(
          number: '28',
          title: 'Disclaimers',
          body:
              'To the fullest extent permitted by law, Cotrainr is provided on an '
              '“as is” and “as available” basis.\n\n'
              'What this means\n\n'
              'We disclaim warranties that are not required by law, including '
              'implied warranties of merchantability, fitness for a particular '
              'purpose and non-infringement, except where such disclaimers are '
              'not allowed.\n\n'
              'Without limiting the above, Cotrainr does not warrant that:\n\n'
              '• the app will be uninterrupted, secure or error-free;\n'
              '• fitness, nutrition, discovery or provider results will meet your '
              'expectations;\n'
              '• third-party services (including Google Meet, maps, health '
              'platforms or stores) will always be available; or\n'
              '• provider verification guarantees professional outcomes.\n\n'
              'Nothing in these Terms excludes warranties or consumer rights that '
              'cannot legally be excluded.',
        ),
        const LegalSectionData(
          number: '29',
          title: 'Limitation of liability',
          body:
              'To the fullest extent permitted by law, Cotrainr and its operators '
              'are not liable for indirect, incidental, special, consequential or '
              'punitive damages, or for lost profits, data or goodwill, arising '
              'from your use of the service.\n\n'
              'What this means\n\n'
              'Nothing in these Terms excludes liability that cannot be excluded '
              'under applicable law (for example liability for death or personal '
              'injury caused by negligence where such exclusion is prohibited, or '
              'other non-excludable consumer rights).\n\n'
              'Specific monetary liability caps have not been set for this release '
              'and are not invented here. Any future cap will appear only after '
              'legal approval.',
        ),
        LegalSectionData(
          number: '30',
          title: 'Indemnity',
          body: LegalBusinessDecisions.indemnityCopy,
        ),
        const LegalSectionData(
          number: '31',
          title: 'Changes to these Terms',
          body:
              'We may update these Terms as Cotrainr changes. Updated Terms will '
              'show a version label in the app.\n\n'
              'What this means\n\n'
              'The current version identifier is ${LegalDocumentMeta.version}. '
              'Material updates that require a new acceptance version will follow '
              'Cotrainr’s legal-version process.\n\n'
              'Whether existing users must re-accept is a separate product and '
              'legal decision and will be communicated when a new version ships.',
        ),
        LegalSectionData(
          number: '32',
          title: 'Governing law',
          body: LegalBusinessDecisions.governingLawCopy,
        ),
        LegalSectionData(
          number: '33',
          title: 'Contact',
          body:
              'For questions about these Terms, account issues or deletion '
              'requests, contact:\n\n'
              '${LegalDocumentMeta.supportEmail}',
        ),
      ];
}
