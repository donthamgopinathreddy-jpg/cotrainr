import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/coach_notes_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/leads_service.dart';
import '../../services/leads_models.dart' show Lead;
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/trainer/trainer_theme.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import 'create_client_page.dart';

class TrainerCoachNotesPage extends StatefulWidget {
  const TrainerCoachNotesPage({super.key});

  @override
  State<TrainerCoachNotesPage> createState() => _TrainerCoachNotesPageState();
}

class _TrainerCoachNotesPageState extends State<TrainerCoachNotesPage> {
  final _notesRepo = CoachNotesRepository();
  final _leadsService = LeadsService();
  final _profileRepo = ProfileRepository();
  final _noteCtrl = TextEditingController();

  List<ClientItem> _clients = [];
  String? _selectedClientId;
  List<CoachNote> _notes = [];
  bool _loadingClients = true;
  bool _loadingNotes = false;
  bool _sending = false;
  String? _clientsError;
  String? _notesError;
  String? _providerType;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loadingClients = true;
      _clientsError = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw StateError('Not authenticated');

      final profile = await _profileRepo.fetchMyProfile();
      final role = (profile?['role'] as String?)?.trim().toLowerCase();
      if (role != 'trainer' && role != 'nutritionist') {
        throw StateError('Provider role unavailable');
      }

      final leads = await _leadsService.getMyLeads();
      final accepted = leads
          .where((l) =>
              l.providerId == uid &&
              l.providerType == role &&
              l.status == 'accepted')
          .toList();

      final seen = <String>{};
      final items = <ClientItem>[];
      for (final lead in accepted) {
        if (!seen.add(lead.clientId)) continue;
        final client = lead.client;
        final name = (client?['full_name'] as String?)?.trim() ?? '';
        final username = (client?['username'] as String?)?.trim() ?? '';
        items.add(
          ClientItem(
            id: lead.clientId,
            name: name.isNotEmpty
                ? name
                : (username.isNotEmpty ? username : 'Client'),
            email: username.isNotEmpty ? '@$username' : '—',
            phone: '',
            joinDate: lead.createdAt,
            status: ClientStatus.active,
            avatar: (client?['avatar_url'] as String?)?.trim(),
            alerts: const [],
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _providerType = role;
        _clients = items;
        _loadingClients = false;
        _clientsError = null;
        if (_selectedClientId != null &&
            !items.any((client) => client.id == _selectedClientId)) {
          _selectedClientId = null;
          _notes = [];
        }
        if (_selectedClientId == null && items.isNotEmpty) {
          _selectedClientId = items.first.id;
        }
      });
      if (_selectedClientId != null) await _loadNotes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingClients = false;
        _clientsError = 'Could not load your clients.';
      });
    }
  }

  Future<void> _loadNotes() async {
    final id = _selectedClientId;
    if (id == null || id.isEmpty) return;
    setState(() {
      _loadingNotes = true;
      _notesError = null;
    });
    try {
      final notes = await _notesRepo.getNotesForClient(id);
      if (!mounted) return;
      setState(() {
        _notes = List<CoachNote>.from(notes)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loadingNotes = false;
        _notesError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingNotes = false;
        _notesError = 'Could not load notes for this client.';
      });
    }
  }

  void _selectClient(String clientId) {
    if (_selectedClientId == clientId) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedClientId = clientId;
      _notes = [];
      _notesError = null;
    });
    _loadNotes();
  }

  Future<void> _sendNote() async {
    final id = _selectedClientId;
    final text = _noteCtrl.text.trim();
    if (id == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final note = await _notesRepo.addNote(id, text);
      if (!mounted) return;
      if (note != null) {
        HapticFeedback.mediumImpact();
        setState(() {
          _notes = [note, ..._notes];
          _notesError = null;
        });
        _noteCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note sent to client'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send note. Check the client connection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send note. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  ClientItem? get _selectedClient {
    final selectedId = _selectedClientId;
    if (selectedId == null) return null;
    for (final client in _clients) {
      if (client.id == selectedId) return client;
    }
    return null;
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight
        ? HomePremiumTheme.lightWarmBg
        : HomePremiumTheme.darkCharcoal;
    final client = _selectedClient;

    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Client Notes',
        backgroundColor: isLight ? Colors.white : HomePremiumTheme.darkCard,
        foregroundColor: HomePremiumTheme.primaryText(isLight),
      ),
      body: _loadingClients
          ? const Center(child: CircularProgressIndicator())
          : _clientsError != null
              ? _errorState(
                  isLight,
                  message: _clientsError!,
                  onRetry: _loadClients,
                )
              : _clients.isEmpty
                  ? _emptyClients(isLight)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(
                            'Select a client',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: HomePremiumTheme.secondaryText(isLight),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _clients.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final c = _clients[i];
                              final selected = c.id == _selectedClientId;
                              return PressableCard(
                                borderRadius: 20,
                                onTap: () => _selectClient(c.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 6, 14, 6),
                                  decoration: BoxDecoration(
                                    gradient:
                                        selected ? TrainerTheme.gradient : null,
                                    color: selected
                                        ? null
                                        : (isLight
                                            ? HomePremiumTheme.lightCreamCard
                                            : HomePremiumTheme.darkCard),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow:
                                        HomePremiumTheme.softCardShadow(isLight),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      VideoSessionAvatar(
                                        name: c.name,
                                        imageUrl: c.avatar,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : HomePremiumTheme.primaryText(
                                                  isLight,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (client != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Notes for ${client.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: HomePremiumTheme.primaryText(isLight),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (client.id.isEmpty) return;
                                    final path = _providerType == 'nutritionist'
                                        ? '/nutritionist/clients/${client.id}'
                                        : '/clients/${client.id}';
                                    context.push(path, extra: client);
                                  },
                                  child: const Text('Open profile'),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: _loadingNotes
                              ? const Center(child: CircularProgressIndicator())
                              : _notesError != null
                                  ? _errorState(
                                      isLight,
                                      message: _notesError!,
                                      onRetry: _loadNotes,
                                    )
                                  : _notes.isEmpty
                                      ? _emptyNotes(isLight)
                                      : RefreshIndicator(
                                          onRefresh: _loadNotes,
                                          color: TrainerTheme.accent,
                                          child: ListView.builder(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              8,
                                              16,
                                              8,
                                            ),
                                            itemCount: _notes.length,
                                            itemBuilder: (context, i) {
                                              return _noteCard(
                                                _notes[i],
                                                isLight,
                                              );
                                            },
                                          ),
                                        ),
                        ),
                        _composeBar(isLight, client?.name ?? 'client'),
                      ],
                    ),
    );
  }

  Widget _errorState(
    bool isLight, {
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HomePremiumTheme.primaryText(isLight),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyClients(bool isLight) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
            const SizedBox(height: 16),
            Text(
              'No clients yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HomePremiumTheme.primaryText(isLight),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accept clients from My Clients to send them notes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HomePremiumTheme.secondaryText(isLight)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyNotes(bool isLight) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
        Icon(
          Icons.note_add_outlined,
          size: 48,
          color: HomePremiumTheme.secondaryText(isLight).withValues(alpha: 0.6),
        ),
        const SizedBox(height: 12),
        Text(
          'No notes yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: HomePremiumTheme.secondaryText(isLight),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Notes you send to clients will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _noteCard(CoachNote note, bool isLight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : HomePremiumTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.content,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: HomePremiumTheme.primaryText(isLight),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(note.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: HomePremiumTheme.secondaryText(isLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composeBar(bool isLight, String clientName) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : HomePremiumTheme.darkCard,
        boxShadow: HomePremiumTheme.softCardShadow(isLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _noteCtrl,
              enabled: !_sending,
              maxLines: 4,
              minLines: 1,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Note for $clientName…',
                counterText: '',
                filled: true,
                fillColor: isLight
                    ? HomePremiumTheme.lightWarmBg
                    : HomePremiumTheme.darkCharcoal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: TrainerTheme.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Send note',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sending ? null : _sendNote,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _sending ? null : TrainerTheme.gradient,
                    color: _sending ? Colors.grey : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
