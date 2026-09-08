import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/account_status.dart';
import '../../core/auth/verification_error_messages.dart';
import '../../services/account_deletion_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

/// Shown when `profiles.account_status` is suspended or banned.
///
/// Deliberately exposes no internal moderation notes. Restricted users can
/// re-check status, sign out, or permanently delete their own account.
class AccountRestrictedPage extends StatefulWidget {
  const AccountRestrictedPage({super.key});

  @override
  State<AccountRestrictedPage> createState() => _AccountRestrictedPageState();
}

class _AccountRestrictedPageState extends State<AccountRestrictedPage> {
  AccountRestriction _restriction =
      const AccountRestriction(status: AccountStatus.suspended);
  bool _busy = false;
  bool _deleting = false;
  bool _hasLoadedRestriction = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_deleting || _busy) return;
    setState(() {
      _busy = true;
      _loadError = null;
    });
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
        _hasLoadedRestriction = true;
        _busy = false;
      });
    } catch (e, s) {
      VerificationErrorMessages.log('accountRestrictedLoad', e, s);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _loadError =
            'Could not check your account status. Check your connection and try again.';
      });
    }
  }

  Future<void> _signOut() async {
    if (_deleting || _busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e, s) {
      VerificationErrorMessages.log('accountRestrictedSignOut', e, s);
    }
    if (!mounted) return;
    context.go('/welcome');
  }

  Future<void> _deleteAccount() async {
    if (_deleting || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete Account?'),
        content: const Text(
          'This permanently deletes your Cotrainr account and associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete Account',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _busy = true;
    });
    try {
      await AccountDeletionService().deleteCurrentAccount();
      if (!mounted) return;
      context.go('/welcome');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your account. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_hasLoadedRestriction && _busy) {
      return Scaffold(
        backgroundColor: DesignTokens.backgroundOf(context),
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_hasLoadedRestriction && _loadError != null) {
      return Scaffold(
        backgroundColor: DesignTokens.backgroundOf(context),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 56,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Couldn’t check your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _load,
                      child: Text(_busy ? 'Checking…' : 'Try again'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _busy ? null : _signOut,
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
                    child: Text(_busy && !_deleting ? 'Checking…' : 'Check again'),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _deleteAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(
                        color: AppColors.red.withValues(alpha: 0.55),
                      ),
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Delete Account'),
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
