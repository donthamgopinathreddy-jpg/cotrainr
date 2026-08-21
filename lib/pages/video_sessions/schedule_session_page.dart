import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../repositories/video_sessions_repository.dart';
import '../../services/leads_models.dart';
import '../../services/leads_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import '../../widgets/video_sessions/video_session_theme.dart';
import '../../widgets/video_sessions/video_session_when_cards.dart';

class ScheduleSessionPage extends StatefulWidget {
  final GoogleMeetIntegrationStatus googleStatus;
  final VoidCallback? onConnectGoogle;
  final bool googleConnecting;
  final String? preselectedClientId;

  const ScheduleSessionPage({
    super.key,
    required this.googleStatus,
    this.onConnectGoogle,
    this.googleConnecting = false,
    this.preselectedClientId,
  });

  @override
  State<ScheduleSessionPage> createState() => _ScheduleSessionPageState();
}

class _ScheduleSessionPageState extends State<ScheduleSessionPage> {
  static const _maxInvitees = 20;

  final _repo = VideoSessionsRepository();
  final _leadsService = LeadsService();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _customDurationController = TextEditingController();
  final _titleFocus = FocusNode();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _durationMinutes = 45;
  bool _customDuration = false;
  bool _loading = false;
  bool _leadsLoading = true;
  List<Lead> _acceptedLeads = [];
  final Set<String> _selectedIds = {};
  String? _requestId;
  String? _whenError;

  bool get _googleReady =>
      widget.googleStatus.connected && !widget.googleStatus.reconnectRequired;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedClientId != null) {
      _selectedIds.add(widget.preselectedClientId!);
    }
    _requestId =
        'vs-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey().hashCode}';
    _titleController.addListener(_onFormChanged);
    _customDurationController.addListener(_onFormChanged);
    _loadAcceptedLeads();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAcceptedLeads() async {
    setState(() => _leadsLoading = true);
    try {
      final leads = await _leadsService.getAcceptedLeadsAsProvider();
      if (!mounted) return;
      setState(() {
        _acceptedLeads = leads;
        _leadsLoading = false;
        _selectedIds.removeWhere(
          (id) => !leads.any((l) => l.clientId == id),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _acceptedLeads = [];
        _leadsLoading = false;
      });
    }
  }

  String _leadName(Lead lead) {
    final name = (lead.client?['full_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Unnamed profile';
  }

  String? _leadAvatar(Lead lead) {
    final url = lead.client?['avatar_url'] as String?;
    return url?.trim().isEmpty == true ? null : url?.trim();
  }

  String _chipName(Lead lead) {
    final full = _leadName(lead);
    final first = full.split(RegExp(r'\s+')).first;
    return first.isEmpty ? full : first;
  }

  List<Lead> get _selectedLeads =>
      _acceptedLeads.where((l) => _selectedIds.contains(l.clientId)).toList();

  List<Lead> get _previewLeads => _acceptedLeads.take(3).toList();

  int get _effectiveDuration {
    if (!_customDuration) return _durationMinutes;
    return int.tryParse(_customDurationController.text.trim()) ?? 0;
  }

  DateTime? get _scheduledStart {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  bool get _canSubmit {
    if (_loading || _acceptedLeads.isEmpty || !_googleReady) return false;
    if (_selectedIds.isEmpty) return false;
    if (_titleController.text.trim().isEmpty) return false;
    final start = _scheduledStart;
    if (start == null) return false;
    if (!start.isAfter(DateTime.now())) return false;
    final duration = _effectiveDuration;
    if (duration < 15 || duration > 180) return false;
    return true;
  }

  void _toggleClient(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length >= _maxInvitees) {
        showHubSnackBar(context, 'You can invite up to $_maxInvitees clients');
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showVideoSessionDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _whenError = _validateWhen();
    });
  }

  Future<void> _pickTime() async {
    final picked = await showVideoSessionTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedTime = picked;
      _whenError = _validateWhen();
    });
  }

  String? _validateWhen() {
    final start = _scheduledStart;
    if (start == null) return null;
    if (!start.isAfter(DateTime.now())) {
      return 'Choose a future start time.';
    }
    return null;
  }

  Future<void> _openClientSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ClientPickerSheet(
        leads: _acceptedLeads,
        selectedIds: Set<String>.from(_selectedIds),
        maxInvitees: _maxInvitees,
        nameOf: _leadName,
        avatarOf: _leadAvatar,
        onDone: (ids) {
          setState(() {
            _selectedIds
              ..clear()
              ..addAll(ids);
          });
        },
      ),
    );
  }

  Future<void> _create() async {
    if (_loading || !_canSubmit) return;
    if (!_googleReady) {
      showHubSnackBar(context, 'Connect Google Meet to create video sessions');
      return;
    }
    _whenError = _validateWhen();
    if (_whenError != null) {
      setState(() {});
      return;
    }
    final title = _titleController.text.trim();
    final start = _scheduledStart!;
    final duration = _effectiveDuration;

    setState(() => _loading = true);
    HapticFeedback.lightImpact();
    try {
      final ids = _selectedIds.toList();
      final session = await _repo.createSession(
        title: title,
        scheduledStart: start,
        durationMinutes: duration,
        description: _notesController.text.trim(),
        participantIds: ids,
        maxParticipants: ids.length + 1,
        clientRequestId: _requestId,
      );
      if (!mounted) return;
      Navigator.pop(context, session);
    } on VideoSessionCreateException catch (e) {
      if (!mounted) return;
      showHubSnackBar(context, e.message);
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
    _titleController.removeListener(_onFormChanged);
    _customDurationController.removeListener(_onFormChanged);
    _titleController.dispose();
    _notesController.dispose();
    _customDurationController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final motion = VideoSessionUi.motion(context);
    final vsTheme = Theme.of(context).copyWith(
      colorScheme: cs.copyWith(primary: DesignTokens.videoSessionsAccent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VideoSessionUi.cardBg(context),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VideoSessionUi.radius),
          borderSide: const BorderSide(
            color: DesignTokens.videoSessionsAccent,
            width: 1.6,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VideoSessionUi.radius),
          borderSide: BorderSide(color: VideoSessionUi.border(context)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VideoSessionUi.radius),
          borderSide: BorderSide(color: VideoSessionUi.border(context)),
        ),
      ),
    );

    return Theme(
      data: vsTheme,
      child: Scaffold(
        backgroundColor: VideoSessionUi.pageBg(context),
        appBar: CotrainrAppBar(
          title: 'Schedule Session',
          fallbackRoute: '/video',
          backgroundColor: VideoSessionUi.pageBg(context),
        ),
        body: _leadsLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: DesignTokens.videoSessionsAccent,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (!_googleReady) ...[
                    _CompactGooglePrompt(
                      status: widget.googleStatus,
                      connecting: widget.googleConnecting,
                      onConnect: widget.onConnectGoogle,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text('Participants', style: VideoSessionUi.sectionLabel(context)),
                  const SizedBox(height: 10),
                  if (_acceptedLeads.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: VideoSessionUi.cardBox(context),
                      child: Text(
                        'No active clients available for video sessions.\n'
                        'Accept a client connection first.',
                        style: TextStyle(
                          color: VideoSessionUi.secondaryText(context),
                        ),
                      ),
                    )
                  else ...[
                    AnimatedSize(
                      duration: motion,
                      curve: Curves.easeOut,
                      child: _selectedLeads.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final lead in _selectedLeads)
                                    _SelectedChip(
                                      name: _chipName(lead),
                                      avatarUrl: _leadAvatar(lead),
                                      onRemove: () => _toggleClient(lead.clientId),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    if (_selectedLeads.isEmpty)
                      _SelectClientsButton(onTap: _openClientSheet),
                    if (_previewLeads.isNotEmpty) ...[
                      if (_selectedLeads.isEmpty) const SizedBox(height: 10),
                      for (final lead in _previewLeads)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ClientSelectRow(
                            name: _leadName(lead),
                            avatarUrl: _leadAvatar(lead),
                            selected: _selectedIds.contains(lead.clientId),
                            onTap: () => _toggleClient(lead.clientId),
                          ),
                        ),
                    ],
                    if (_acceptedLeads.length > 3)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _openClientSheet,
                          style: TextButton.styleFrom(
                            foregroundColor: DesignTokens.videoSessionsAccent,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 44),
                          ),
                          child: Text(
                            'View all clients (${_acceptedLeads.length}) →',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Text('Session details', style: VideoSessionUi.sectionLabel(context)),
                  const SizedBox(height: 10),
                  Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    label: 'Session title',
                    textField: true,
                    child: TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: VideoSessionUi.fieldDecoration(
                        context,
                        hintText: 'Strength Coaching',
                      ).copyWith(counterText: ''),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('When', style: VideoSessionUi.sectionLabel(context)),
                  const SizedBox(height: 10),
                  VideoSessionWhenCards(
                    date: _selectedDate,
                    time: _selectedTime,
                    onPickDate: _pickDate,
                    onPickTime: _pickTime,
                    errorText: _whenError,
                  ),
                  const SizedBox(height: 20),
                  Text('Duration', style: VideoSessionUi.sectionLabel(context)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final mins in [30, 45, 60]) ...[
                        Expanded(
                          child: _DurationCard(
                            label: '$mins min',
                            selected: !_customDuration && _durationMinutes == mins,
                            onTap: () => setState(() {
                              _customDuration = false;
                              _durationMinutes = mins;
                            }),
                          ),
                        ),
                        if (mins != 60) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DurationCard(
                    label: 'Custom',
                    selected: _customDuration,
                    onTap: () => setState(() => _customDuration = true),
                  ),
                  if (_customDuration) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customDurationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: VideoSessionUi.fieldDecoration(
                        context,
                        hintText: 'Minutes (15–180)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Notes', style: VideoSessionUi.sectionLabel(context)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: VideoSessionUi.fieldDecoration(
                      context,
                      hintText: 'Add anything your clients should know...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: Semantics(
                      button: true,
                      label: 'Create Session',
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _create : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.videoSessionsAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              cs.onSurface.withValues(alpha: 0.12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(VideoSessionUi.radius),
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SelectClientsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SelectClientsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Select clients',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VideoSessionUi.radius),
        child: Ink(
          height: 48,
          decoration: VideoSessionUi.cardBox(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: DesignTokens.videoSessionsAccent,
              ),
              const SizedBox(width: 6),
              const Text(
                'Select clients',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.videoSessionsAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final VoidCallback onRemove;

  const _SelectedChip({
    required this.name,
    required this.avatarUrl,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: VideoSessionUi.cardBox(context, selected: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoSessionAvatar(name: name, imageUrl: avatarUrl, size: 28),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove $name',
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientSelectRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  const _ClientSelectRow({
    required this.name,
    required this.avatarUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$name, selected' : 'Select $name',
      child: AnimatedContainer(
        duration: VideoSessionUi.motion(context),
        curve: Curves.easeOut,
        decoration: VideoSessionUi.cardBox(context, selected: selected),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(VideoSessionUi.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  VideoSessionAvatar(name: name, imageUrl: avatarUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? DesignTokens.videoSessionsAccent
                        : VideoSessionUi.secondaryText(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label duration',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VideoSessionUi.radius),
        child: AnimatedContainer(
          duration: VideoSessionUi.motion(context),
          height: 48,
          alignment: Alignment.center,
          decoration: VideoSessionUi.cardBox(context, selected: selected),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: DesignTokens.videoSessionsAccent,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? DesignTokens.videoSessionsAccent
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactGooglePrompt extends StatelessWidget {
  final GoogleMeetIntegrationStatus status;
  final bool connecting;
  final VoidCallback? onConnect;

  const _CompactGooglePrompt({
    required this.status,
    required this.connecting,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: VideoSessionUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect Google Meet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            status.reconnectRequired
                ? 'Reconnect Google Meet to schedule video sessions.'
                : 'Connect Google Meet to create session links.',
            style: TextStyle(
              fontSize: 13,
              color: VideoSessionUi.secondaryText(context),
            ),
          ),
          if (onConnect != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: connecting ? null : onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.videoSessionsAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: Text(
                  connecting
                      ? 'Connecting…'
                      : status.reconnectRequired
                          ? 'Reconnect Google Meet'
                          : 'Connect Google Meet',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  final List<Lead> leads;
  final Set<String> selectedIds;
  final int maxInvitees;
  final String Function(Lead) nameOf;
  final String? Function(Lead) avatarOf;
  final void Function(Set<String> ids) onDone;

  const _ClientPickerSheet({
    required this.leads,
    required this.selectedIds,
    required this.maxInvitees,
    required this.nameOf,
    required this.avatarOf,
    required this.onDone,
  });

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  late Set<String> _ids;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ids = Set<String>.from(widget.selectedIds);
  }

  List<Lead> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.leads;
    return widget.leads
        .where((l) => widget.nameOf(l).toLowerCase().contains(q))
        .toList();
  }

  List<Lead> get _selectedLeads =>
      widget.leads.where((l) => _ids.contains(l.clientId)).toList();

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_ids.contains(id)) {
        _ids.remove(id);
      } else if (_ids.length >= widget.maxInvitees) {
        showHubSnackBar(
          context,
          'You can invite up to ${widget.maxInvitees} clients',
        );
      } else {
        _ids.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final unselected = filtered.where((l) => !_ids.contains(l.clientId)).toList();
    final selectedVisible = _selectedLeads.where((l) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return widget.nameOf(l).toLowerCase().contains(q);
    }).toList();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scroll) {
          return Material(
            color: VideoSessionUi.pageBg(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VideoSessionUi.border(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select clients',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: VideoSessionUi.fieldDecoration(
                      ctx,
                      hintText: 'Search clients...',
                    ).copyWith(
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    children: [
                      if (selectedVisible.isNotEmpty) ...[
                        Text(
                          'Selected (${selectedVisible.length})',
                          style: VideoSessionUi.sectionLabel(ctx),
                        ),
                        const SizedBox(height: 8),
                        for (final lead in selectedVisible)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ClientSelectRow(
                              name: widget.nameOf(lead),
                              avatarUrl: widget.avatarOf(lead),
                              selected: true,
                              onTap: () => _toggle(lead.clientId),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      Text('All clients', style: VideoSessionUi.sectionLabel(ctx)),
                      const SizedBox(height: 8),
                      for (final lead in unselected)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ClientSelectRow(
                            name: widget.nameOf(lead),
                            avatarUrl: widget.avatarOf(lead),
                            selected: false,
                            onTap: () => _toggle(lead.clientId),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onDone(_ids);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.videoSessionsAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: Text(
                          'Done (${_ids.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
