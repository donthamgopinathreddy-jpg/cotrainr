import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../repositories/coach_notes_repository.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import 'client_monitoring_theme.dart';

class ClientCoachNotesPage extends StatefulWidget {
  final String clientId;
  final String clientName;
  final CoachNotesApi? notesRepository;

  const ClientCoachNotesPage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.notesRepository,
  });

  @override
  State<ClientCoachNotesPage> createState() => _ClientCoachNotesPageState();
}

class _ClientCoachNotesPageState extends State<ClientCoachNotesPage> {
  late final CoachNotesApi _repo;
  final _controller = TextEditingController();
  List<CoachNote> _notes = [];
  bool _loading = true;
  bool _sending = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.notesRepository ?? CoachNotesRepository();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = await _repo.getNotesForClient(widget.clientId);
      if (!mounted) return;
      setState(() {
        _notes = _newestFirst(notes);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notes. Pull to retry.';
      });
    }
  }

  List<CoachNote> _newestFirst(List<CoachNote> notes) {
    final copy = List<CoachNote>.from(notes);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      final note = await _repo.addNote(widget.clientId, text);
      if (!mounted) return;
      if (note == null) {
        showHubSnackBar(context, 'Could not add note. Accept this client first.');
        return;
      }
      setState(() {
        _notes = _newestFirst([note, ..._notes]);
        _controller.clear();
      });
    } catch (_) {
      if (mounted) {
        showHubSnackBar(context, 'Could not add note. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(CoachNote note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text(
          'The client will no longer see this note.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: DesignTokens.accentRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _repo.deleteNote(note.id);
      if (!mounted) return;
      setState(() {
        _notes = _notes.where((n) => n.id != note.id).toList();
      });
    } catch (_) {
      if (mounted) {
        showHubSnackBar(context, 'Could not delete note. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.clientName.trim().isEmpty ? 'Client' : widget.clientName.trim();
    return Scaffold(
      backgroundColor: ClientMonitoringUi.pageBg(context),
      appBar: AppBar(
        backgroundColor: ClientMonitoringUi.pageBg(context),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ClientMonitoringUi.secondary(context),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Notes you add here are visible to the client.',
                style: TextStyle(
                  fontSize: 13,
                  color: ClientMonitoringUi.secondary(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: DesignTokens.videoSessionsAccent,
                    ),
                  )
                : RefreshIndicator(
                    color: DesignTokens.videoSessionsAccent,
                    onRefresh: _load,
                    child: _error != null
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ClientMonitoringUi.secondary(context),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _load,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : _notes.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height: MediaQuery.sizeOf(context).height * 0.18,
                                  ),
                                  Text(
                                    'No notes yet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: DesignTokens.textPrimaryOf(context),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Add a note below. Your client can read it.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ClientMonitoringUi.secondary(context),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: _notes.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final note = _notes[i];
                                  return _NoteRow(
                                    note: note,
                                    onDelete: _deleting
                                        ? null
                                        : () => _confirmDelete(note),
                                  );
                                },
                              ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Add note',
                      textField: true,
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add note',
                          filled: true,
                          fillColor: ClientMonitoringUi.cardBg(context),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              ClientMonitoringUi.radius,
                            ),
                            borderSide: BorderSide(
                              color: ClientMonitoringUi.border(context),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              ClientMonitoringUi.radius,
                            ),
                            borderSide: BorderSide(
                              color: ClientMonitoringUi.border(context),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              ClientMonitoringUi.radius,
                            ),
                            borderSide: const BorderSide(
                              color: DesignTokens.videoSessionsAccent,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: Semantics(
                      button: true,
                      label: 'Add note',
                      child: ElevatedButton(
                        onPressed: _sending ? null : _add,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.videoSessionsAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final CoachNote note;
  final VoidCallback? onDelete;

  const _NoteRow({required this.note, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: ClientMonitoringUi.cardBox(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ClientMonitoringUi.shortDate(note.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ClientMonitoringUi.secondary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: DesignTokens.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete note',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: ClientMonitoringUi.secondary(context),
              ),
            ),
        ],
      ),
    );
  }
}
