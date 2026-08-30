import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/notifications_repository.dart';
import '../../repositories/video_sessions_repository.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../utils/meeting_link_rules.dart';
import '../../utils/video_session_error_messages.dart';
import '../../video_sessions/video_session_notification_logic.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import '../../widgets/video_sessions/video_session_people_sheet.dart';
import '../../widgets/video_sessions/video_session_reject_sheet.dart';

class SessionDetailPage extends StatefulWidget {
  final String sessionId;
  final String? initialAction;

  const SessionDetailPage({
    super.key,
    required this.sessionId,
    this.initialAction,
  });

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final _repo = VideoSessionsRepository();
  VideoSession? _session;
  bool _loading = true;
  bool _cancelling = false;
  bool _saving = false;
  bool _responding = false;
  bool _handledInitialAction = false;
  String? _error;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!isVideoSessionUuid(widget.sessionId)) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Session not found';
      });
      return;
    }
    try {
      final session = await _repo.getSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
        if (session == null) _error = 'Session not found';
      });
      if (session != null) {
        _scheduleStatusRefresh(session);
        NotificationsRepository().markVideoSessionNotificationsRead(
          sessionId: session.id,
        );
        _runInitialAction(session);
      }
    } catch (e, s) {
      if (!mounted) return;
      VideoSessionErrorMessages.log('getSession', e, s);
      setState(() {
        _loading = false;
        _error = VideoSessionErrorMessages.forLoadSession(e);
      });
    }
  }

  void _scheduleStatusRefresh(VideoSession session) {
    _statusTimer?.cancel();
    if (session.isPast) return;
    final wait = session.endsAt.difference(DateTime.now()) +
        const Duration(seconds: 1);
    if (wait.isNegative) {
      if (mounted) setState(() {});
      return;
    }
    _statusTimer = Timer(wait, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _runInitialAction(VideoSession session) {
    if (_handledInitialAction) return;
    final action = widget.initialAction;
    if (action != 'join' && action != 'reject') return;
    _handledInitialAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (action == 'join') {
        _join();
      } else if (action == 'reject') {
        unawaited(_reject());
      }
    });
  }

  Future<void> _join() async {
    final session = _session;
    if (session == null || !session.canJoin) return;
    final uri = Uri.tryParse(session.joinUrl);
    if (uri == null) {
      showHubSnackBar(context, 'Invalid meeting link');
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) showHubSnackBar(context, 'Could not open meeting link');
    }
  }

  Future<void> _reject() async {
    final session = _session;
    if (session == null || _responding) return;
    if (!session.isScheduled) {
      showHubSnackBar(context, 'This session can no longer be updated');
      return;
    }
    final name = session.counterpartyName?.trim().isNotEmpty == true
        ? session.counterpartyName!.trim()
        : (session.participantNames.isNotEmpty
            ? session.participantNames.first
            : 'them');
    final result = await showVideoSessionRejectSheet(
      context: context,
      counterpartDisplayName: name,
    );
    if (result == null || !mounted) return;

    setState(() => _responding = true);
    try {
      final role = await _repo.rejectSession(
        sessionId: session.id,
        reasonCode: result.reasonCode,
        reasonText: result.reasonText,
      );
      if (!mounted) return;
      final reason = VideoSessionNotificationLogic.rejectReasonLabel(
        result.reasonCode,
        otherText: result.reasonText,
      );
      setState(() {
        _session = session.copyWith(
          myResponseStatus: 'rejected',
          myResponseReason: reason,
          myRespondedAt: DateTime.now(),
        );
      });
      showHubSnackBar(
        context,
        VideoSessionNotificationLogic.notifiedSnackbar(role),
      );
    } catch (e, s) {
      VideoSessionErrorMessages.log('rejectSession', e, s);
      if (mounted) {
        showHubSnackBar(context, VideoSessionErrorMessages.forResponse(e));
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  Future<void> _copyLink() async {
    final session = _session;
    if (session == null) return;
    await Clipboard.setData(ClipboardData(text: session.joinUrl));
    if (mounted) showHubSnackBar(context, 'Meeting link copied');
  }

  Future<void> _cancel() async {
    final session = _session;
    if (session == null || _cancelling) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: const Text(
          'Participants will no longer be able to join from Cotrainr. '
          'The meeting link is not deleted automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Session'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel Session',
              style: TextStyle(
                color: AccountHubTheme.dangerRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);
    HapticFeedback.lightImpact();
    try {
      await _repo.cancelSession(widget.sessionId);
      if (!mounted) return;
      showHubSnackBar(context, 'Session cancelled');
      CotrainrBackButton.popOrFallback(context, fallbackRoute: '/video');
    } catch (e, s) {
      VideoSessionErrorMessages.log('cancelSession', e, s);
      if (mounted) {
        showHubSnackBar(context, VideoSessionErrorMessages.forCancel(e));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _edit() async {
    final session = _session;
    if (session == null || !session.isScheduled || session.isPast || _saving) {
      return;
    }

    final titleCtrl = TextEditingController(text: session.title);
    final notesCtrl = TextEditingController(text: session.description ?? '');
    DateTime date = session.scheduledStart;
    TimeOfDay time = TimeOfDay.fromDateTime(session.scheduledStart);
    var duration = session.durationMinutes;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: AccountHubTheme.cardBg(ctx),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Edit Session',
                        style: AccountHubTheme.rowTitle(ctx).copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.isGoogleMeet
                            ? 'Google Meet link stays the same when you reschedule.'
                            : 'Update session details.',
                        style: AccountHubTheme.rowSubtitle(ctx),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: date,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModal(() => date = picked);
                                }
                              },
                              child: Text(DateFormat('d MMM yyyy').format(date)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: time,
                                );
                                if (picked != null) {
                                  setModal(() => time = picked);
                                }
                              },
                              child: Text(time.format(ctx)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [30, 45, 60].map((m) {
                          return ChoiceChip(
                            label: Text('$m min'),
                            selected: duration == m,
                            onSelected: (_) => setModal(() => duration = m),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.videoSessionsAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save changes'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      titleCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() => _saving = true);
    try {
      final updated = await _repo.updateSession(
        sessionId: session.id,
        title: titleCtrl.text.trim(),
        scheduledStart: scheduled,
        durationMinutes: duration,
        description: notesCtrl.text.trim(),
        preserveJoinUrl: true,
      );
      if (!mounted) return;
      setState(() => _session = updated.copyWith(
            counterpartyName: session.counterpartyName,
          ));
      showHubSnackBar(context, 'Session updated');
    } catch (e, s) {
      VideoSessionErrorMessages.log('updateSession', e, s);
      if (mounted) {
        showHubSnackBar(context, VideoSessionErrorMessages.forUpdate(e));
      }
    } finally {
      titleCtrl.dispose();
      notesCtrl.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AccountHubTheme.pageBg(context);
    final cs = Theme.of(context).colorScheme;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final session = _session;
    final isHost = session != null && session.hostId == me;

    return CotrainrPopScope(
      fallbackRoute: '/video',
      child: Scaffold(
        backgroundColor: bg,
        appBar: CotrainrAppBar(
          title: 'Session',
          fallbackRoute: '/video',
          backgroundColor: bg,
        ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: DesignTokens.videoSessionsAccent,
              ),
            )
          : session == null
              ? Center(
                  child: Text(
                    _error ?? 'Session not found',
                    style: AccountHubTheme.rowSubtitle(context),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    HubSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.title,
                                  style: AccountHubTheme.rowTitle(context)
                                      .copyWith(fontSize: 20),
                                ),
                              ),
                              _StatusChip(session: session),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (session.people.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Participants',
                              style: AccountHubTheme.sectionTitle(context),
                            ),
                            const SizedBox(height: 8),
                            for (final person in session.people)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    VideoSessionAvatar(
                                      name: person.displayName,
                                      imageUrl: person.avatarUrl,
                                      size: 40,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        person.displayName.trim().isEmpty
                                            ? 'Unnamed profile'
                                            : person.displayName.trim(),
                                        style: AccountHubTheme.rowTitle(context),
                                      ),
                                    ),
                                    VideoSessionResponseChip(
                                      responseStatus:
                                          session.responseStatusFor(
                                        person,
                                        myUserId: me,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (session.participantResponseSummary != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                session.participantResponseSummary!,
                                style: AccountHubTheme.rowSubtitle(context),
                              ),
                            ],
                          ] else ...[
                            const SizedBox(height: 8),
                            _MetaRow(
                              icon: Icons.person_outline_rounded,
                              text: session.withLine,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _MetaRow(
                            icon: Icons.calendar_today_rounded,
                            text: DateFormat('EEEE, d MMM yyyy · h:mm a')
                                .format(session.scheduledStart.toLocal()),
                          ),
                          const SizedBox(height: 8),
                          _MetaRow(
                            icon: Icons.timer_outlined,
                            text: '${session.durationMinutes} minutes',
                          ),
                          if (session.description != null &&
                              session.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text('Notes', style: AccountHubTheme.sectionTitle(context)),
                            const SizedBox(height: 4),
                            Text(
                              session.description!,
                              style: AccountHubTheme.rowSubtitle(context)
                                  .copyWith(
                                color: cs.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (session.hasRejected) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AccountHubTheme.dangerRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unable to attend',
                              style: AccountHubTheme.rowTitle(context).copyWith(
                                color: AccountHubTheme.dangerRed,
                              ),
                            ),
                            if (session.myResponseReason != null &&
                                session.myResponseReason!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reason: ${session.myResponseReason}',
                                style: AccountHubTheme.rowSubtitle(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (session.isScheduled && !session.isPast) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _responding ? null : _reject,
                          style: TextButton.styleFrom(
                            foregroundColor: DesignTokens.videoSessionsAccent,
                          ),
                          child: const Text('Change response'),
                        ),
                      ],
                    ] else if (session.counterpartRejectedOneToOne) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AccountHubTheme.dangerRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unable to attend',
                              style: AccountHubTheme.rowTitle(context).copyWith(
                                color: AccountHubTheme.dangerRed,
                              ),
                            ),
                            if (session.counterpartResponseReason != null &&
                                session.counterpartResponseReason!
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reason: ${session.counterpartResponseReason}',
                                style: AccountHubTheme.rowSubtitle(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!session.hasRejected && session.canJoin)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _join,
                          icon: const Icon(Icons.videocam_rounded),
                          label: const Text('Join Meeting'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignTokens.videoSessionsAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      )
                    else if (!session.hasRejected)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _joinDisabledReason(session),
                          style: AccountHubTheme.rowSubtitle(context),
                        ),
                      ),
                    if (isHost) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _copyLink,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy meeting link'),
                      ),
                      if (session.isScheduled && !session.isPast) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _edit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(_saving ? 'Saving…' : 'Edit session'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _cancelling ? null : _cancel,
                          icon: _cancelling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel Session'),
                          style: TextButton.styleFrom(
                            foregroundColor: AccountHubTheme.dangerRed,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
    ),
    );
  }

  String _joinDisabledReason(VideoSession session) {
    if (session.isCancelled) {
      return 'This session was cancelled.';
    }
    final eligibility = VideoSessionJoinRules.evaluate(
      status: session.status,
      scheduledStart: session.scheduledStart,
      durationMinutes: session.durationMinutes,
      joinUrl: session.joinUrl,
    );
    switch (eligibility) {
      case VideoSessionJoinEligibility.missingLink:
      case VideoSessionJoinEligibility.invalidLink:
        return 'No valid meeting link is available.';
      case VideoSessionJoinEligibility.past:
        return 'This session is in the past.';
      case VideoSessionJoinEligibility.cancelled:
        return 'This session was cancelled.';
      case VideoSessionJoinEligibility.tooEarly:
        return 'Available 5 min before';
      case VideoSessionJoinEligibility.joinable:
        return 'Join is unavailable.';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final VideoSession session;
  const _StatusChip({required this.session});

  @override
  Widget build(BuildContext context) {
    final label = session.hasRejected || session.counterpartRejectedOneToOne
        ? 'Rejected'
        : session.isCancelled
            ? 'Cancelled'
        : session.isPast
            ? 'Completed'
            : 'Upcoming';
    final color = videoSessionStatusColor(context, label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AccountHubTheme.rowSubtitle(context)),
        ),
      ],
    );
  }
}
