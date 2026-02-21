import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../repositories/video_sessions_repository.dart';
import '../../services/leads_service.dart';
import '../../theme/app_colors.dart';

class CreateSessionSheet extends StatefulWidget {
  final void Function(VideoSession session) onCreate;
  final String? preselectedClientId;
  final bool zoomConnected;
  final VoidCallback? onConnectZoom;
  final bool zoomConnecting;

  const CreateSessionSheet({
    super.key,
    required this.onCreate,
    this.preselectedClientId,
    this.zoomConnected = false,
    this.onConnectZoom,
    this.zoomConnecting = false,
  });

  @override
  State<CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<CreateSessionSheet> {
  final _repo = VideoSessionsRepository();
  final _leadsService = LeadsService();
  final _titleController = TextEditingController();
  final _externalLinkController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _durationMinutes = 30;
  int _maxParticipants = 5;
  bool _loading = false;
  bool _useExternalLink = false;
  List<dynamic> _acceptedLeads = [];
  final Set<String> _selectedClientIds = {};
  bool _leadsLoading = true;

  static const int _maxInviteSlots = 4; // host occupies 1 of 5

  @override
  void initState() {
    super.initState();
    _useExternalLink = !widget.zoomConnected;
    _loadAcceptedLeads();
    if (widget.preselectedClientId != null) {
      _selectedClientIds.add(widget.preselectedClientId!);
    }
  }

  Future<void> _loadAcceptedLeads() async {
    setState(() => _leadsLoading = true);
    try {
      final leads = await _leadsService.getAcceptedLeadsAsProvider();
      if (mounted) {
        setState(() {
          _acceptedLeads = leads;
          _leadsLoading = false;
          if (widget.preselectedClientId != null &&
              leads.any((l) => l.clientId == widget.preselectedClientId)) {
            _selectedClientIds.add(widget.preselectedClientId!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _acceptedLeads = [];
          _leadsLoading = false;
        });
      }
    }
  }

  int get _maxSelectable => (_maxParticipants - 1).clamp(0, _maxInviteSlots);

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

  void _toggleClient(String clientId) {
    setState(() {
      if (_selectedClientIds.contains(clientId)) {
        _selectedClientIds.remove(clientId);
      } else if (_selectedClientIds.length < _maxSelectable) {
        _selectedClientIds.add(clientId);
      }
    });
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    if (_useExternalLink) {
      final link = _externalLinkController.text.trim();
      if (link.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please paste a Zoom or meeting link')),
        );
        return;
      }
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link must start with http:// or https://')),
        );
        return;
      }
    }

    final scheduledStart = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (scheduledStart.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled time must be in the future')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final provider = _useExternalLink ? 'external' : 'zoom';
      final joinUrl = _useExternalLink ? _externalLinkController.text.trim() : null;

      final session = await _repo.createSession(
        title: title,
        scheduledStart: scheduledStart,
        durationMinutes: _durationMinutes,
        maxParticipants: _maxParticipants,
        participantIds: _selectedClientIds.toList(),
        provider: provider,
        joinUrl: joinUrl,
      );
      await Clipboard.setData(ClipboardData(text: session.joinUrl));
      if (mounted) widget.onCreate(session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _externalLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zoomConnected = widget.zoomConnected;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create Session',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Training session',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
              ),
              maxLength: 60,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Date',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time_rounded, size: 18),
                    label: Text(
                      _selectedTime != null
                          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'Time',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [30, 45, 60].map((mins) {
                final selected = _durationMinutes == mins;
                return ChoiceChip(
                  label: Text('$mins min'),
                  selected: selected,
                  onSelected: (v) => setState(() => _durationMinutes = mins),
                  selectedColor: AppColors.purple.withOpacity(0.3),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Max participants', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [2, 3, 4, 5].map((n) {
                final selected = _maxParticipants == n;
                return ChoiceChip(
                  label: Text('$n'),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    _maxParticipants = n;
                    while (_selectedClientIds.length > (n - 1)) {
                      _selectedClientIds.remove(_selectedClientIds.first);
                    }
                  }),
                  selectedColor: AppColors.purple.withOpacity(0.3),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Meeting link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Create Zoom meeting'),
                    selected: !_useExternalLink,
                    onSelected: zoomConnected ? (v) => setState(() => _useExternalLink = false) : null,
                    selectedColor: AppColors.purple.withOpacity(0.3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Paste external link'),
                    selected: _useExternalLink,
                    onSelected: (v) => setState(() => _useExternalLink = true),
                    selectedColor: AppColors.purple.withOpacity(0.3),
                  ),
                ),
              ],
            ),
            if (!_useExternalLink && !zoomConnected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Zoom to create meetings',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.onConnectZoom != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.zoomConnecting ? null : widget.onConnectZoom,
                          icon: widget.zoomConnecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.link_rounded, size: 16),
                          label: Text(widget.zoomConnecting ? 'Connecting...' : 'Connect Zoom'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_useExternalLink) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _externalLinkController,
                decoration: InputDecoration(
                  hintText: 'https://zoom.us/j/...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                ),
                keyboardType: TextInputType.url,
                maxLines: 1,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Invite clients (max $_maxSelectable)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_leadsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_acceptedLeads.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No accepted clients. Accept a lead first.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryOf(context)),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _acceptedLeads.length,
                  itemBuilder: (context, i) {
                    final lead = _acceptedLeads[i];
                    final clientId = lead.clientId as String;
                    final name = (lead.client as Map<String, dynamic>?)?['full_name'] as String? ?? 'Client';
                    final selected = _selectedClientIds.contains(clientId);
                    final disabled = !selected && _selectedClientIds.length >= _maxSelectable;
                    return CheckboxListTile(
                      value: selected,
                      onChanged: disabled ? null : (_) => _toggleClient(clientId),
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || (!_useExternalLink && !zoomConnected)) ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
