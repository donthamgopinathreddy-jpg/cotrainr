import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../repositories/coach_notes_repository.dart';

/// Page for clients to view notes from their trainers and nutritionists.
class CoachNotesPage extends StatefulWidget {
  const CoachNotesPage({super.key});

  @override
  State<CoachNotesPage> createState() => _CoachNotesPageState();
}

class _CoachNotesPageState extends State<CoachNotesPage> {
  final CoachNotesRepository _repo = CoachNotesRepository();
  final PageController _pageController = PageController();
  List<CoachNote> _notes = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  List<CoachNote> get _coachNotes =>
      _notes.where((n) => n.coachType == 'trainer').toList();
  List<CoachNote> get _nutritionistNotes =>
      _notes.where((n) => n.coachType == 'nutritionist').toList();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final notes = await _repo.getMyNotes();
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notes = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 7) {
      return '${dt.day}/${dt.month}/${dt.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotes,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildPillTabBar(context, cs),
                  const SizedBox(height: 16),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      children: [
                        _buildNotesPage(cs, _coachNotes, AppColors.blue),
                        _buildNotesPage(cs, _nutritionistNotes, AppColors.green),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPillTabBar(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _currentIndex == 0
                        ? const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFE96A6A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _currentIndex == 0 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _currentIndex == 0
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE53935).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'Coaches',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _currentIndex == 0
                          ? Colors.white
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _currentIndex == 1
                        ? const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFE96A6A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _currentIndex == 1 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _currentIndex == 1
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE53935).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'Nutritionist',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _currentIndex == 1
                          ? Colors.white
                          : cs.onSurfaceVariant,
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

  Widget _buildNotesPage(
    ColorScheme cs,
    List<CoachNote> notes,
    Color accentColor,
  ) {
    return notes.isEmpty
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildEmptyStateContent(cs),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NoteSliderCard(
                  note: note,
                  formatTime: _formatTime,
                  accentColor: accentColor,
                ),
              );
            },
          );
  }

  Widget _buildEmptyStateContent(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 48,
            color: cs.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Notes from your trainers and nutritionists will appear here when they add them from their dashboard.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoteSliderCard extends StatelessWidget {
  final CoachNote note;
  final String Function(DateTime) formatTime;
  final Color accentColor;

  const _NoteSliderCard({
    required this.note,
    required this.formatTime,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor,
                    backgroundImage: note.coachAvatarUrl != null && note.coachAvatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(note.coachAvatarUrl!)
                        : null,
                    child: note.coachAvatarUrl == null || note.coachAvatarUrl!.isEmpty
                        ? Text(
                            (note.coachName ?? 'C').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.coachName ?? 'Coach',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formatTime(note.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              note.content,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface,
                height: 1.35,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
