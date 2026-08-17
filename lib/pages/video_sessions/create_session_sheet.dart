import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/video_sessions_repository.dart';
import '../../services/leads_models.dart';
import '../../services/leads_service.dart';
import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/profile/account_hub_widgets.dart';

class CreateSessionSheet extends StatefulWidget {
  final void Function(VideoSession session) onCreate;
  final String? preselectedClientId;
  final GoogleMeetIntegrationStatus googleStatus;
  final VoidCallback? onConnectGoogle;
  final bool googleConnecting;

  const CreateSessionSheet({
    super.key,
    required this.onCreate,
    required this.googleStatus,
    this.preselectedClientId,
    this.onConnectGoogle,
    this.googleConnecting = false,
  });

  @override
  State<CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<CreateSessionSheet> {
  final _repo = VideoSessionsRepository();
  final _leadsService = LeadsService();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _customDurationController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _durationMinutes = 45;
  bool _customDuration = false;
  bool _loading = false;
  bool _leadsLoading = true;
  List<Lead> _acceptedLeads = [];
  String? _selectedClientId;
  String _memberSearch = '';
  String? _requestId;

  bool get _googleReady =>
      widget.googleStatus.connected && !widget.googleStatus.reconnectRequired;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.preselectedClientId;
    _requestId =
        'vs-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';
    _loadAcceptedLeads();
  }

  Future<void> _loadAcceptedLeads() async {
    setState(() => _leadsLoading = true);
    try {
      final leads = await _leadsService.getAcceptedLeadsAsProvider();
      if (!mounted) return;
      setState(() {
        _acceptedLeads = leads;
        _leadsLoading = false;
        if (_selectedClientId != null &&
            !leads.any((l) => l.clientId == _selectedClientId)) {
          _selectedClientId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _acceptedLeads = [];
        _leadsLoading = false;
      });
    }
  }

  List<Lead> get _filteredLeads {
    final q = _memberSearch.trim().toLowerCase();
    if (q.isEmpty) return _acceptedLeads;
    return _acceptedLeads.where((lead) {
      final name = (lead.client?['full_name'] as String? ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  int get _effectiveDuration {
    if (!_customDuration) return _durationMinutes;
    return int.tryParse(_customDurationController.text.trim()) ?? 0;
  }

  Future<void> _create() async {
    if (_loading) return;
    if (!_googleReady) {
      showHubSnackBar(context, 'Connect Google Meet to create video sessions');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showHubSnackBar(context, 'Enter a session title');
      return;
    }
    if (_selectedClientId == null) {
      showHubSnackBar(context, 'Select a member');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      showHubSnackBar(context, 'Select date and start time');
      return;
    }
    final duration = _effectiveDuration;
    if (duration < 15 || duration > 180) {
      showHubSnackBar(context, 'Duration must be between 15 and 180 minutes');
      return;
    }

    final scheduledStart = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (scheduledStart.isBefore(DateTime.now())) {
      showHubSnackBar(context, 'Scheduled time must be in the future');
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.lightImpact();
    try {
      final session = await _repo.createSession(
        title: title,
        scheduledStart: scheduledStart,
        durationMinutes: duration,
        description: _notesController.text.trim(),
        participantIds: [_selectedClientId!],
        maxParticipants: 2,
        clientRequestId: _requestId,
      );
      if (!mounted) return;
      widget.onCreate(session);
    } on VideoSessionCreateException catch (e) {
      if (!mounted) return;
      if (e.code == 'GOOGLE_NOT_CONNECTED' ||
          e.code == 'GOOGLE_RECONNECT_REQUIRED') {
        showHubSnackBar(context, e.message);
      } else {
        showHubSnackBar(context, e.message);
      }
    } catch (e) {
      if (!mounted) return;
      showHubSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: AccountHubTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Schedule Session',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _GoogleMeetBanner(
              status: widget.googleStatus,
              connecting: widget.googleConnecting,
              onConnect: widget.onConnectGoogle,
            ),
            const SizedBox(height: 16),
            Text('Who\'s joining', style: AccountHubTheme.rowTitle(context)),
            const SizedBox(height: 8),
            if (_leadsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_acceptedLeads.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'No active members available for video sessions.\n'
                  'Accept a member connection first.',
                  style: AccountHubTheme.rowSubtitle(context),
                ),
              )
            else ...[
              if (_acceptedLeads.length > 5)
                TextField(
                  onChanged: (v) => setState(() => _memberSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search members',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              if (_acceptedLeads.length > 5) const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredLeads.length,
                  itemBuilder: (context, i) {
                    final lead = _filteredLeads[i];
                    final name =
                        (lead.client?['full_name'] as String?)?.trim().isNotEmpty ==
                                true
                            ? lead.client!['full_name'] as String
                            : 'Unnamed profile';
                    final selected = _selectedClientId == lead.clientId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            DesignTokens.videoSessionsAccent.withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: DesignTokens.videoSessionsAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      trailing: Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected
                            ? DesignTokens.videoSessionsAccent
                            : cs.onSurface.withValues(alpha: 0.35),
                      ),
                      onTap: () =>
                          setState(() => _selectedClientId = lead.clientId),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'Session title',
                hintText: 'e.g. Strength Coaching',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      _selectedDate == null
                          ? 'Date'
                          : DateFormat('d MMM yyyy').format(_selectedDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(
                      _selectedTime == null
                          ? 'Start time'
                          : _selectedTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Times use your device timezone',
              style: AccountHubTheme.rowSubtitle(context),
            ),
            const SizedBox(height: 16),
            Text('Duration', style: AccountHubTheme.rowTitle(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mins in [30, 45, 60])
                  ChoiceChip(
                    label: Text('$mins min'),
                    selected: !_customDuration && _durationMinutes == mins,
                    onSelected: (_) => setState(() {
                      _customDuration = false;
                      _durationMinutes = mins;
                    }),
                    selectedColor:
                        DesignTokens.videoSessionsAccent.withValues(alpha: 0.25),
                  ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _customDuration,
                  onSelected: (_) => setState(() => _customDuration = true),
                  selectedColor:
                      DesignTokens.videoSessionsAccent.withValues(alpha: 0.25),
                ),
              ],
            ),
            if (_customDuration) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customDurationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Minutes (15–180)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_loading ||
                        _acceptedLeads.isEmpty ||
                        !_googleReady)
                    ? null
                    : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.videoSessionsAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      cs.onSurface.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Session',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMeetBanner extends StatelessWidget {
  final GoogleMeetIntegrationStatus status;
  final bool connecting;
  final VoidCallback? onConnect;

  const _GoogleMeetBanner({
    required this.status,
    required this.connecting,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final ready = status.connected && !status.reconnectRequired;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ready
            ? AccountHubTheme.goalsGreen.withValues(alpha: 0.1)
            : DesignTokens.videoSessionsAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? AccountHubTheme.goalsGreen.withValues(alpha: 0.35)
              : DesignTokens.videoSessionsAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ready ? 'Meeting: Google Meet' : 'Connect Google Meet',
            style: AccountHubTheme.rowTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            ready
                ? (status.googleEmail == null
                    ? 'A new Meet link will be created automatically.'
                    : 'Connected as ${status.googleEmail}')
                : status.reconnectRequired
                    ? 'Reconnect Google Meet to create video sessions.'
                    : 'Connect Google Meet to create video sessions.',
            style: AccountHubTheme.rowSubtitle(context),
          ),
          if (!ready && onConnect != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: connecting ? null : onConnect,
                icon: connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  connecting
                      ? 'Connecting…'
                      : status.reconnectRequired
                          ? 'Reconnect Google Meet'
                          : 'Connect Google',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.videoSessionsAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared helper used by Video Sessions page to open Google OAuth.
Future<void> launchGoogleMeetOAuth(
  BuildContext context,
  VideoSessionsRepository repo,
) async {
  try {
    final url = await repo.getGoogleOAuthUrl();
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (context.mounted) {
      showHubSnackBar(
        context,
        'Complete Google sign-in in the browser, then return here',
      );
    }
  } on VideoSessionCreateException catch (e) {
    if (context.mounted) showHubSnackBar(context, e.message);
  } catch (_) {
    if (context.mounted) {
      showHubSnackBar(context, 'Could not open Google sign-in');
    }
  }
}
