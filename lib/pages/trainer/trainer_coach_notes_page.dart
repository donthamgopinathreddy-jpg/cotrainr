import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/coach_notes_repository.dart';
import '../../services/leads_service.dart';
import '../../services/leads_models.dart' show Lead;
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
  final _noteCtrl = TextEditingController();

  List<ClientItem> _clients = [];
  String? _selectedClientId;
  List<CoachNote> _notes = [];
  bool _loadingClients = true;
  bool _loadingNotes = false;
  bool _sending = false;

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
    setState(() => _loadingClients = true);
    try {
      final leads = await _leadsService.getMyLeads();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final role = Supabase.instance.client.auth.currentUser?.userMetadata?['role']
          ?.toString()
          .toLowerCase();
      final providerType =
          role == 'nutritionist' ? 'nutritionist' : 'trainer';
      final accepted = uid == null
          ? <Lead>[]
          : leads
              .where((l) =>
                  l.providerId == uid &&
                  l.providerType == providerType &&
                  l.status == 'accepted')
              .toList();

      final items = accepted.map((lead) {
        final client = lead.client;
        final name = client?['full_name'] as String? ?? 'Client';
        final username = client?['username'] as String? ?? '';
        return ClientItem(
          id: lead.clientId,
          name: name.isNotEmpty ? name : username,
          email: username.isNotEmpty ? '@$username' : '—',
          phone: '',
          joinDate: lead.createdAt,
          status: ClientStatus.active,
          avatar: client?['avatar_url'] as String?,
          alerts: [],
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _clients = items;
        _loadingClients = false;
        if (_selectedClientId == null && items.isNotEmpty) {
          _selectedClientId = items.first.id;
          _loadNotes();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _loadNotes() async {
    final id = _selectedClientId;
    if (id == null || id.isEmpty) return;
    setState(() => _loadingNotes = true);
    try {
      final notes = await _notesRepo.getNotesForClient(id);
      if (mounted) {
        setState(() {
          _notes = notes;
          _loadingNotes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNotes = false);
    }
  }

  void _selectClient(String clientId) {
    if (_selectedClientId == clientId) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedClientId = clientId;
      _notes = [];
    });
    _loadNotes();
  }

  Future<void> _sendNote() async {
    final id = _selectedClientId;
    final text = _noteCtrl.text.trim();
    if (id == null || text.isEmpty) return;

    setState(() => _sending = true);
    final note = await _notesRepo.addNote(id, text);
    if (!mounted) return;
    setState(() => _sending = false);

    if (note != null) {
      HapticFeedback.mediumImpact();
      setState(() => _notes = [note, ..._notes]);
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
          content: Text('Could not send note. Accept the client first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  ClientItem? get _selectedClient {
    if (_selectedClientId == null) return null;
    for (final c in _clients) {
      if (c.id == _selectedClientId) return c;
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
    final bg = isLight ? HomePremiumTheme.lightWarmBg : HomePremiumTheme.darkCharcoal;
    final client = _selectedClient;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Client Notes',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : HomePremiumTheme.darkCard,
        foregroundColor: HomePremiumTheme.primaryText(isLight),
      ),
      body: _loadingClients
          ? const Center(child: CircularProgressIndicator())
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
                              padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                              decoration: BoxDecoration(
                                gradient: selected ? TrainerTheme.gradient : null,
                                color: selected
                                    ? null
                                    : (isLight
                                        ? HomePremiumTheme.lightCreamCard
                                        : HomePremiumTheme.darkCard),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: HomePremiumTheme.softCardShadow(isLight),
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
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : HomePremiumTheme.primaryText(isLight),
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
                                final role = Supabase
                                    .instance.client.auth.currentUser
                                    ?.userMetadata?['role']
                                    ?.toString()
                                    .toLowerCase();
                                final path = role == 'nutritionist'
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
                          : _notes.isEmpty
                              ? _emptyNotes(isLight)
                              : RefreshIndicator(
                                  onRefresh: _loadNotes,
                                  color: TrainerTheme.accent,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                    itemCount: _notes.length,
                                    itemBuilder: (context, i) {
                                      final note = _notes[i];
                                      return _noteCard(note, isLight);
                                    },
                                  ),
                                ),
                    ),
                    _composeBar(isLight, client?.name ?? 'client'),
                  ],
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
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Note for $clientName…',
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
                  borderSide: const BorderSide(color: TrainerTheme.accent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
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
        ],
      ),
    );
  }
}
