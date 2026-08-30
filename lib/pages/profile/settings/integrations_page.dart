import 'package:flutter/material.dart';

import '../../../repositories/profile_repository.dart';
import '../../../repositories/video_sessions_repository.dart';
import '../../../theme/account_hub_theme.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/common/cotrainr_back_button.dart';
import '../../../widgets/profile/account_hub_widgets.dart';
import '../../../utils/video_session_error_messages.dart';
import '../../video_sessions/google_meet_oauth_launcher.dart';

/// Settings → Integrations → Google Meet.
///
/// Only trainers and nutritionists may access this page.
/// Clients are redirected back on direct navigation.
class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({
    super.key,
    this.profileRepository,
    this.videoSessionsRepository,
  });

  /// Optional override for tests.
  final ProfileRepository? profileRepository;

  /// Optional override for tests.
  final VideoSessionsRepository? videoSessionsRepository;

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  late final ProfileRepository _profileRepo;
  late final VideoSessionsRepository _repo;
  GoogleMeetIntegrationStatus _status =
      GoogleMeetIntegrationStatus.disconnected();
  bool _loading = true;
  bool _busy = false;
  // Tri-state: null = checking, true = allowed, false = blocked.
  bool? _accessAllowed;

  @override
  void initState() {
    super.initState();
    _profileRepo = widget.profileRepository ?? ProfileRepository();
    _repo = widget.videoSessionsRepository ?? VideoSessionsRepository();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final profile = await _profileRepo.fetchMyProfile();
      final role = profile?['role'] as String?;
      final allowed = role == 'trainer' || role == 'nutritionist';
      if (!mounted) return;
      setState(() => _accessAllowed = allowed);
      if (allowed) {
        _load();
      } else {
        // Block client access — pop back to Settings immediately.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (_) {
      // On error, fail closed: deny access.
      if (!mounted) return;
      setState(() => _accessAllowed = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await _repo.getGoogleMeetStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e, s) {
      VideoSessionErrorMessages.log('getGoogleMeetStatus', e, s);
      if (!mounted) return;
      setState(() {
        _status = GoogleMeetIntegrationStatus.unknown(lastKnown: _status);
        _loading = false;
      });
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      await launchGoogleMeetOAuth(context, _repo);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await _repo.disconnectGoogleMeet();
      await _load();
      if (mounted) showHubSnackBar(context, 'Google Meet disconnected');
    } catch (e, s) {
      VideoSessionErrorMessages.log('disconnectGoogleMeet', e, s);
      if (mounted) {
        showHubSnackBar(context, VideoSessionErrorMessages.forDisconnect(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);

    // While the role check is in progress, show a blank page.
    // If access is denied the page will pop before the user sees anything.
    if (_accessAllowed != true) {
      return Scaffold(backgroundColor: bg);
    }

    final ready = _status.connected && !_status.reconnectRequired;
    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Integrations',
        backgroundColor: bg,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: DesignTokens.videoSessionsAccent,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                HubSectionCard(
                  title: 'Google Meet',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready
                            ? 'Connected'
                            : _status.isUnknown
                                ? 'Status unavailable'
                                : 'Not connected',
                        style: AccountHubTheme.rowTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ready
                            ? (_status.googleEmail ??
                                'Ready to create Meet links for Video Sessions.')
                            : _status.isUnknown
                                ? '${VideoSessionErrorMessages.googleStatusUnknown} Try again in a moment.'
                                : _status.reconnectRequired
                                    ? 'Reconnect Google Meet to schedule video sessions.'
                                    : 'Connect Google Meet to automatically create session links.',
                        style: AccountHubTheme.rowSubtitle(context),
                      ),
                      const SizedBox(height: 12),
                      if (ready)
                        TextButton(
                          onPressed: _busy ? null : _disconnect,
                          style: TextButton.styleFrom(
                            foregroundColor: AccountHubTheme.dangerRed,
                          ),
                          child: const Text('Disconnect'),
                        )
                      else if (_status.isUnknown)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _busy ? null : _load,
                            child: const Text('Retry'),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _connect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.videoSessionsAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _busy
                                  ? 'Connecting…'
                                  : _status.reconnectRequired
                                      ? 'Reconnect Google Meet'
                                      : 'Connect Google Meet',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
