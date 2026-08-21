import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../repositories/coach_notes_repository.dart';
import '../../theme/design_tokens.dart';
import '../../utils/client_notes_grouping.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import '../../widgets/video_sessions/video_session_theme.dart';
import 'provider_notes_detail_page.dart';

/// Client inbox for notes from trainers and nutritionists.
class CoachNotesPage extends StatefulWidget {
  final CoachNotesInboxApi? inbox;
  final String? viewerClientId;

  const CoachNotesPage({
    super.key,
    this.inbox,
    this.viewerClientId,
  });

  @override
  State<CoachNotesPage> createState() => _CoachNotesPageState();
}

class _CoachNotesPageState extends State<CoachNotesPage> {
  late final CoachNotesInboxApi _inbox;
  final _scroll = ScrollController();

  bool _loading = true;
  bool _loadFailed = false;
  List<CoachNote> _notes = [];

  @override
  void initState() {
    super.initState();
    _inbox = widget.inbox ?? CoachNotesRepository();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final notes = await _inbox.getMyNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        if (!silent) _notes = [];
      });
    }
  }

  List<ClientNotesProviderGroup> get _groups => groupClientNotesByProvider(
        _notes,
        viewerClientId: widget.viewerClientId,
      );

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final groups = _groups;

    return Scaffold(
      backgroundColor: VideoSessionUi.pageBg(context),
      appBar: CotrainrAppBar(
        title: kClientNotesScreenTitle,
        backgroundColor: VideoSessionUi.pageBg(context),
        foregroundColor: HomePremiumTheme.primaryText(isLight),
        actions: [
          if (!_loading && !_loadFailed && groups.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClientAllNotesPage(groups: groups),
                  ),
                );
              },
              child: const Text('All notes'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignTokens.videoSessionsAccent,
        onRefresh: () => _load(silent: true),
        child: _loading
            ? const _NotesSkeleton()
            : _loadFailed
                ? _ErrorState(onRetry: _load)
                : groups.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: groups.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12, top: 4),
                              child: Text(
                                'YOUR COACHES',
                                style: VideoSessionUi.sectionLabel(context),
                              ),
                            );
                          }
                          final group = groups[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProviderRow(
                              group: group,
                              isLight: isLight,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ProviderNotesDetailPage(group: group),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final ClientNotesProviderGroup group;
  final bool isLight;
  final VoidCallback onTap;

  const _ProviderRow({
    required this.group,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final role = group.roleLabel;
    return Semantics(
      button: true,
      label: [
        group.name,
        ?role,
        noteCountLabel(group.noteCount),
      ].join(', '),
      child: PressableCard(
        borderRadius: VideoSessionUi.radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: VideoSessionUi.cardBox(context),
          child: Row(
            children: [
              VideoSessionAvatar(
                name: group.name,
                imageUrl: group.avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name.isEmpty ? (role ?? '') : group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HomePremiumTheme.primaryText(isLight),
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HomePremiumTheme.secondaryText(isLight),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '${noteCountLabel(group.noteCount)} · Latest ${formatNoteDateShort(group.latestAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: HomePremiumTheme.secondaryText(isLight),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: HomePremiumTheme.secondaryText(isLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Text(
          'No notes yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: HomePremiumTheme.primaryText(isLight),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Feedback from your trainers and nutritionists will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1.35,
            color: HomePremiumTheme.secondaryText(isLight),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Text(
          'Couldn\'t load notes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: HomePremiumTheme.primaryText(isLight),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Try again',
          textAlign: TextAlign.center,
          style: TextStyle(color: HomePremiumTheme.secondaryText(isLight)),
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.videoSessionsAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesSkeleton extends StatelessWidget {
  const _NotesSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE8E8EA)
        : Colors.white.withValues(alpha: 0.08);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(VideoSessionUi.radius),
            ),
          ),
        ),
      ),
    );
  }
}

class ClientAllNotesPage extends StatelessWidget {
  final List<ClientNotesProviderGroup> groups;

  const ClientAllNotesPage({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final notes = [
      for (final group in groups)
        for (final note in group.notes) (group: group, note: note),
    ]..sort((a, b) => b.note.createdAt.compareTo(a.note.createdAt));

    return Scaffold(
      backgroundColor: VideoSessionUi.pageBg(context),
      appBar: CotrainrAppBar(
        title: 'All notes',
        backgroundColor: VideoSessionUi.pageBg(context),
        foregroundColor: HomePremiumTheme.primaryText(isLight),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: notes.length,
        itemBuilder: (context, i) {
          final item = notes[i];
          final role = item.group.roleLabel;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: VideoSessionUi.cardBox(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VideoSessionAvatar(
                        name: item.group.name,
                        imageUrl: item.group.avatarUrl,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          [
                            item.group.name,
                            ?role,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: HomePremiumTheme.primaryText(isLight),
                          ),
                        ),
                      ),
                      Text(
                        formatNoteDateShort(item.note.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: HomePremiumTheme.secondaryText(isLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.note.content,
                    style: TextStyle(
                      height: 1.4,
                      color: HomePremiumTheme.primaryText(isLight),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
