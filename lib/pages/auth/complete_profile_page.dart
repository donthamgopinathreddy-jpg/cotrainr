import 'package:flutter/material.dart';

import '../../core/auth/signup_mode.dart';
import 'signup_wizard_page.dart';

/// Route alias: incomplete OAuth users enter shared onboarding (social mode).
class CompleteProfilePage extends StatelessWidget {
  const CompleteProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignupWizardPage(mode: SignupMode.social);
  }
}
