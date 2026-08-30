import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/account_status.dart';
import '../../core/auth/verification_error_messages.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

/// Shown when `profiles.account_status` is suspended or banned.
///
/// Deliberately exposes no internal moderation notes; the only actions are
/// retry (a suspension may have expired) and sign out.
class AccountRestrictedPage extends StatefulWidget {
  const AccountRestrictedPage({super.key});

  @override
  State<AccountRestrictedPage> createState() => _AccountRestrictedPageState();
}

class _AccountRestrictedPageState extends State<AccountRestrictedPage> {
  AccountRestriction _restriction =
      const AccountRestriction(status: AccountStatus.suspended);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final raw = await Supabase.instance.client
          .rpc('get_my_profile')
          .timeout(const Duration(seconds: 15));
      Map<String, dynamic>? profile;
      if (raw is List && raw.isNotEmpty) {
        profile = Map<String, dynamic>.from(raw.first as Map);
      } else if (raw is Map) {
        profile = Map<String, dynamic>.from(raw);
      }
      final restriction = AccountStatusParser.fromProfile(profile);
      if (!mounted) return;
      if (!restriction.isRestricted) {
        context.go('/auth/continue');
        return;
      }
      setState(() {
        _restriction = restriction;
        _busy = false;
      });
    } catch (e, s) {
      VerificationErrorMessages.log('accountRestrictedLoad', e, s);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e, s) {
      VerificationErrorMessages.log('accountRestrictedSignOut', e, s);
    }
    if (!mounted) return;
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _restriction.status == AccountStatus.banned
                      ? Icons.block_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 72,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  _restriction.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _restriction.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _load,
                    child: Text(_busy ? 'Checking…' : 'Check again'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
