import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/home_v3/home_premium_theme.dart';

/// Honest Become Trainer hub (Option B).
///
/// No mock Future.delayed conversion. Clients cannot convert roles in-app;
/// they must create a trainer/nutritionist account at signup.
/// Existing providers continue setup via /verification.
class BecomeTrainerPage extends StatelessWidget {
  const BecomeTrainerPage({super.key});

  String get _role {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['role']?.toString().toLowerCase() ?? 'client';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;
    final isProvider = _role == 'trainer' || _role == 'nutritionist';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          isProvider ? 'Provider setup' : 'Become a trainer',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.school_rounded,
              size: 48,
              color: DesignTokens.accentOrange,
            ),
            const SizedBox(height: 16),
            Text(
              isProvider
                  ? 'Finish professional setup & verification'
                  : 'Provider accounts start at signup',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isProvider
                  ? 'Complete your professional profile, then upload verification documents. Role conversion from a client account is not supported in-app.'
                  : 'Cotrainr does not convert client accounts into trainers here. Create a new account as Trainer or Nutritionist, then complete verification.',
              style: TextStyle(color: textSecondary, height: 1.4),
            ),
            const Spacer(),
            if (isProvider) ...[
              FilledButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/verification');
                },
                child: const Text('Continue setup'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/profile/professional');
                },
                child: const Text('Edit professional profile only'),
              ),
            ] else ...[
              FilledButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go('/home');
                },
                child: const Text('Back to home'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
