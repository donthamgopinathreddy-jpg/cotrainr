import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../repositories/coach_notes_repository.dart';
import '../../repositories/meal_repository.dart';
import '../../repositories/messages_repository.dart';
import '../../repositories/metrics_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/video_sessions_repository.dart';
import '../../services/coach_client_access_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import '../trainer/create_client_page.dart';
import 'client_coach_notes_page.dart';
import 'client_meals_panel.dart';
import 'client_monitoring_theme.dart';

/// Shared trainer/nutritionist client monitoring screen.
class ClientDetailShell extends StatefulWidget {
  final String clientId;
  final ClientItem? initialClient;
  final bool isNutritionist;
  final CoachClientAccessService? accessService;
  final ProfileRepository? profileRepository;
  final MetricsRepository? metricsRepository;
  final MealRepository? mealRepository;
  final CoachNotesApi? notesRepository;
  final VideoSessionsRepository? sessionsRepository;
  final MessagesRepository? messagesRepository;
  final Future<CoachClientAccessStatus> Function(String clientId)? loadAccess;
  final Future<Map<String, dynamic>?> Function(String clientId)? loadProfile;
  final Future<Map<String, dynamic>?> Function(String clientId)? loadMetrics;
  final Future<DayMealsData> Function(String clientId)? loadMeals;
  final Future<List<CoachNote>> Function(String clientId)? loadNotes;
  final Future<VideoSession?> Function(String clientId)? loadUpcoming;

  const ClientDetailShell({
    super.key,
    required this.clientId,
    this.initialClient,
    this.isNutritionist = false,
    this.accessService,
    this.profileRepository,
    this.metricsRepository,
    this.mealRepository,
    this.notesRepository,
    this.sessionsRepository,
    this.messagesRepository,
    this.loadAccess,
    this.loadProfile,
    this.loadMetrics,
    this.loadMeals,
    this.loadNotes,
    this.loadUpcoming,
  });

  @override
  State<ClientDetailShell> createState() => _ClientDetailShellState();
}

class _ClientDetailShellState extends State<ClientDetailShell>
    with SingleTickerProviderStateMixin {
  CoachClientAccessService? _accessService;
  ProfileRepository? _profileRepo;
  MetricsRepository? _metricsRepo;
  MealRepository? _mealRepo;
  CoachNotesApi? _notesRepo;
  VideoSessionsRepository? _sessionsRepo;
  MessagesRepository? _messagesRepo;
  late final TabController _tabs;

  bool _loading = true;
  String? _error;
  CoachClientAccessStatus? _access;
  String? _name;
  String? _username;
  String? _avatarUrl;
  Map<String, dynamic>? _metrics;
  DayMealsData? _meals;
  List<CoachNote> _notes = [];
  VideoSession? _upcoming;

  bool get _isTrainer => !widget.isNutritionist;

  @override
  void initState() {
    super.initState();
    _accessService = widget.accessService;
    _profileRepo = widget.profileRepository;
    _metricsRepo = widget.metricsRepository;
    _mealRepo = widget.mealRepository;
    _notesRepo = widget.notesRepository;
    _sessionsRepo = widget.sessionsRepository;
    _messagesRepo = widget.messagesRepository;
    _tabs = TabController(length: 2, vsync: this);
    _seedFromExtra();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _seedFromExtra() {
    final extra = widget.initialClient;
    if (extra == null) return;
    if (extra.id != widget.clientId) return;
    final name = extra.name.trim();
    if (name.isEmpty || name.toLowerCase() == 'john doe') return;
    _name = name;
    final email = extra.email.trim();
    if (email.startsWith('@')) _username = email.substring(1);
    _avatarUrl = extra.avatar;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.clientId.trim();
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Client not found';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final access = widget.loadAccess != null
          ? await widget.loadAccess!(id)
          : await (_accessService ??=
                  CoachClientAccessService())
              .getClientAccess(id);
      if (!mounted) return;
      if (!access.hasAcceptedLead) {
        setState(() {
          _access = access;
          _loading = false;
          _error = 'This client is not connected.';
        });
        return;
      }

      final profile = widget.loadProfile != null
          ? await widget.loadProfile!(id)
          : await (_profileRepo ??= ProfileRepository()).fetchUserProfile(id);
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _access = access;
          _loading = false;
          _error = 'Client not found';
        });
        return;
      }

      final name = (profile['full_name'] as String?)?.trim();
      final username = (profile['username'] as String?)?.trim();
      final avatar = (profile['avatar_url'] as String?)?.trim();

      List<CoachNote> notes = const [];
      VideoSession? upcoming;
      Map<String, dynamic>? metrics;
      DayMealsData? meals;

        try {
          notes = widget.loadNotes != null
              ? await widget.loadNotes!(id)
              : await (_notesRepo ??= CoachNotesRepository())
                  .getNotesForClient(id);
        } catch (_) {}
        if (!mounted) return;

        try {
          upcoming = widget.loadUpcoming != null
              ? await widget.loadUpcoming!(id)
              : await (_sessionsRepo ??= VideoSessionsRepository())
                  .upcomingSessionForClient(id);
        } catch (_) {}
        if (!mounted) return;

        if (_isTrainer && access.canViewMetrics) {
          try {
            metrics = widget.loadMetrics != null
                ? await widget.loadMetrics!(id)
                : await (_metricsRepo ??= MetricsRepository())
                    .getClientMetricsForDate(id, DateTime.now());
          } catch (_) {}
          if (!mounted) return;
        }

        if (access.canViewMeals) {
          try {
            meals = widget.loadMeals != null
                ? await widget.loadMeals!(id)
                : await (_mealRepo ??= MealRepository())
                    .getClientDayMeals(id, DateTime.now());
          } catch (_) {}
          if (!mounted) return;
        }

      setState(() {
        _access = access;
        _name = (name != null && name.isNotEmpty)
            ? name
            : (username != null && username.isNotEmpty ? username : 'Client');
        _username = username;
        _avatarUrl = avatar?.isEmpty == true ? null : avatar;
        _metrics = metrics;
        _meals = meals;
        _notes = List<CoachNote>.from(notes)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _upcoming = upcoming;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this client. Pull to retry.';
      });
    }
  }

  Future<void> _openChat() async {
    HapticFeedback.lightImpact();
    final convId = await (_messagesRepo ??= MessagesRepository())
        .createOrFindConversation(widget.clientId);
    if (!mounted) return;
    if (convId == null) {
      showHubSnackBar(context, 'Unable to open chat. Please try again.');
      return;
    }
    context.push('/messaging/chat/$convId', extra: {
      'userName': _name ?? 'Client',
      'isOnline': true,
      'avatarUrl': _avatarUrl,
    });
  }

  void _openVideo() {
    HapticFeedback.lightImpact();
    context.push('/video?openCreate=1&clientId=${widget.clientId}');
  }

  Future<void> _openNotes() async {
    HapticFeedback.lightImpact();
    final notesApi = _notesRepo ??= CoachNotesRepository();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCoachNotesPage(
          clientId: widget.clientId,
          clientName: _name ?? 'Client',
          notesRepository: notesApi,
        ),
      ),
    );
    if (!mounted) return;
    try {
      final notes = widget.loadNotes != null
          ? await widget.loadNotes!(widget.clientId)
          : await notesApi.getNotesForClient(widget.clientId);
      if (mounted) {
        setState(() {
          _notes = List<CoachNote>.from(notes)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClientMonitoringUi.pageBg(context),
      appBar: AppBar(
        backgroundColor: ClientMonitoringUi.pageBg(context),
        elevation: 0,
        title: Text(
          _name ?? 'Client',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading && _name == null
          ? const Center(
              child: CircularProgressIndicator(
                color: DesignTokens.videoSessionsAccent,
              ),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: _Header(
                        name: _name ?? 'Client',
                        username: _username,
                        avatarUrl: _avatarUrl,
                        active: _access?.hasAcceptedLead == true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ActionRow(
                        onMessage: _openChat,
                        onVideo: _openVideo,
                        onNotes: _openNotes,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      controller: _tabs,
                      labelColor: DesignTokens.videoSessionsAccent,
                      unselectedLabelColor: ClientMonitoringUi.secondary(context),
                      indicatorColor: DesignTokens.videoSessionsAccent,
                      indicatorWeight: 2.5,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Meals'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          RefreshIndicator(
                            color: DesignTokens.videoSessionsAccent,
                            onRefresh: _load,
                            child: _OverviewTab(
                              isTrainer: _isTrainer,
                              access: _access,
                              metrics: _metrics,
                              meals: _meals,
                              notes: _notes,
                              upcoming: _upcoming,
                              loading: _loading,
                              onViewMeals: () => _tabs.animateTo(1),
                              onViewNotes: _openNotes,
                              onViewSession: _upcoming == null
                                  ? null
                                  : () => context.push(
                                        '/video/session/${_upcoming!.id}',
                                      ),
                            ),
                          ),
                          _MealsTab(
                            access: _access,
                            meals: _meals,
                            richMacros: widget.isNutritionist,
                            loading: _loading,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String? username;
  final String? avatarUrl;
  final bool active;

  const _Header({
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final handle = (username ?? '').trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: ClientMonitoringUi.cardBox(context),
      child: Row(
        children: [
          VideoSessionAvatar(
            name: name,
            imageUrl: avatarUrl,
            size: ClientMonitoringUi.avatarSize,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ClientMonitoringUi.title(context).copyWith(fontSize: 18),
                ),
                if (handle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ClientMonitoringUi.secondary(context),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  active ? 'Active' : 'Not connected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? DesignTokens.accentGreen
                        : ClientMonitoringUi.secondary(context),
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

class _ActionRow extends StatelessWidget {
  final VoidCallback onMessage;
  final VoidCallback onVideo;
  final VoidCallback onNotes;

  const _ActionRow({
    required this.onMessage,
    required this.onVideo,
    required this.onNotes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Message',
            primary: false,
            onTap: onMessage,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.videocam_rounded,
            label: 'Video Session',
            primary: true,
            onTap: onVideo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.edit_note_rounded,
            label: 'Client Notes',
            primary: false,
            onTap: onNotes,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: ClientMonitoringUi.actionHeight,
        child: primary
            ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.videoSessionsAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ClientMonitoringUi.radius),
                  ),
                ),
                child: _Content(icon: icon, label: label, compact: true),
              )
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.textPrimaryOf(context),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: BorderSide(color: ClientMonitoringUi.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ClientMonitoringUi.radius),
                  ),
                ),
                child: _Content(icon: icon, label: label, compact: false),
              ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  const _Content({
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: compact ? Colors.white : null,
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final bool isTrainer;
  final CoachClientAccessStatus? access;
  final Map<String, dynamic>? metrics;
  final DayMealsData? meals;
  final List<CoachNote> notes;
  final VideoSession? upcoming;
  final bool loading;
  final VoidCallback onViewMeals;
  final VoidCallback onViewNotes;
  final VoidCallback? onViewSession;

  const _OverviewTab({
    required this.isTrainer,
    required this.access,
    required this.metrics,
    required this.meals,
    required this.notes,
    required this.upcoming,
    required this.loading,
    required this.onViewMeals,
    required this.onViewNotes,
    required this.onViewSession,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && access == null) {
      return const Center(
        child: CircularProgressIndicator(color: DesignTokens.videoSessionsAccent),
      );
    }

    final children = <Widget>[];
    if (upcoming != null) {
      children.add(_UpcomingCard(session: upcoming!, onView: onViewSession));
    }
    if (isTrainer) {
      children.add(_ActivityCard(access: access, metrics: metrics));
    }
    if (access?.canViewMeals == true || access?.hasAcceptedLead == true) {
      children.add(
        _MealSummaryCard(
          access: access,
          meals: meals,
          rich: !isTrainer,
          onView: onViewMeals,
        ),
      );
    }
    if (notes.isNotEmpty) {
      children.add(_NotePreviewCard(note: notes.first, onView: onViewNotes));
    }

    if (children.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Text(
            'No monitoring data to show yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ClientMonitoringUi.secondary(context)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final VideoSession session;
  final VoidCallback? onView;
  const _UpcomingCard({required this.session, this.onView});

  @override
  Widget build(BuildContext context) {
    final local = session.scheduledStart.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final when = day == today
        ? 'Today · ${ClientMonitoringUi.timeOfDay(local)}'
        : '${ClientMonitoringUi.shortDate(local)} · ${ClientMonitoringUi.timeOfDay(local)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ClientMonitoringUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upcoming session', style: ClientMonitoringUi.sectionLabel(context)),
          const SizedBox(height: 8),
          Text(session.title, style: ClientMonitoringUi.title(context)),
          const SizedBox(height: 4),
          Text(
            '$when · ${session.durationMinutes} min',
            style: TextStyle(color: ClientMonitoringUi.secondary(context)),
          ),
          if (onView != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(
                  foregroundColor: DesignTokens.videoSessionsAccent,
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final CoachClientAccessStatus? access;
  final Map<String, dynamic>? metrics;
  const _ActivityCard({required this.access, required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (access?.canViewMetrics != true) {
      return _PrivacyCard(
        title: 'Activity today',
        message: 'Activity sharing is off. This client has chosen not to share activity metrics.',
      );
    }
    if (metrics == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: ClientMonitoringUi.cardBox(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity today', style: ClientMonitoringUi.sectionLabel(context)),
            const SizedBox(height: 8),
            Text(
              'No activity logged today',
              style: TextStyle(color: ClientMonitoringUi.secondary(context)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ClientMonitoringUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity today', style: ClientMonitoringUi.sectionLabel(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Steps',
                  value: _num(metrics!['steps'], asInt: true),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Calories',
                  value: _kcal(metrics!['calories_burned']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Distance',
                  value: _km(metrics!['distance_km']),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Water',
                  value: _liters(metrics!['water_intake_liters']),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _num(dynamic raw, {bool asInt = false}) {
    if (raw == null) return '—';
    final n = (raw as num);
    if (asInt) return NumberFormat('#,###').format(n.round());
    return n.toString();
  }

  String _kcal(dynamic raw) {
    if (raw == null) return '—';
    return '${(raw as num).round()} kcal';
  }

  String _km(dynamic raw) {
    if (raw == null) return '—';
    return '${(raw as num).toStringAsFixed(1)} km';
  }

  String _liters(dynamic raw) {
    if (raw == null) return '—';
    return '${(raw as num).toStringAsFixed(1)} L';
  }
}

class _MealSummaryCard extends StatelessWidget {
  final CoachClientAccessStatus? access;
  final DayMealsData? meals;
  final bool rich;
  final VoidCallback onView;

  const _MealSummaryCard({
    required this.access,
    required this.meals,
    required this.rich,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    if (access?.canViewMeals != true) {
      return const _PrivacyCard(
        title: 'Meals today',
        message: 'Meal sharing is off',
      );
    }
    final data = meals ?? DayMealsData.empty();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ClientMonitoringUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meals today', style: ClientMonitoringUi.sectionLabel(context)),
          const SizedBox(height: 8),
          if (!data.hasLoggedMeals)
            Text(
              'No meals logged today',
              style: TextStyle(color: ClientMonitoringUi.secondary(context)),
            )
          else ...[
            Text(
              '${data.loggedItemCount} logged',
              style: ClientMonitoringUi.title(context),
            ),
            const SizedBox(height: 6),
            Text(
              rich
                  ? '${data.totalCalories} kcal  ·  P ${data.totalProtein.round()}g  ·  C ${data.totalCarbs.round()}g  ·  F ${data.totalFats.round()}g  ·  Fi ${data.totalFiber.round()}g'
                  : '${data.totalCalories} kcal\n${data.totalProtein.round()} g protein',
              style: TextStyle(
                height: 1.35,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.videoSessionsAccent,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'View meals',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotePreviewCard extends StatelessWidget {
  final CoachNote note;
  final VoidCallback onView;
  const _NotePreviewCard({required this.note, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ClientMonitoringUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Latest coach note', style: ClientMonitoringUi.sectionLabel(context)),
          const SizedBox(height: 8),
          Text(
            note.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: DesignTokens.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ClientMonitoringUi.shortDate(note.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: ClientMonitoringUi.secondary(context),
            ),
          ),
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.videoSessionsAccent,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              'View notes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final String title;
  final String message;
  const _PrivacyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ClientMonitoringUi.cardBox(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ClientMonitoringUi.sectionLabel(context)),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: ClientMonitoringUi.secondary(context)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ClientMonitoringUi.sectionLabel(context)),
        const SizedBox(height: 4),
        Text(value, style: ClientMonitoringUi.value(context)),
      ],
    );
  }
}

class _MealsTab extends StatelessWidget {
  final CoachClientAccessStatus? access;
  final DayMealsData? meals;
  final bool richMacros;
  final bool loading;

  const _MealsTab({
    required this.access,
    required this.meals,
    required this.richMacros,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && meals == null && access?.canViewMeals == true) {
      return const Center(
        child: CircularProgressIndicator(color: DesignTokens.videoSessionsAccent),
      );
    }
    if (access?.canViewMeals != true) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _PrivacyCard(
          title: 'Meals',
          message: 'Meal sharing is off',
        ),
      );
    }
    return ClientMealsPanel(
      meals: meals ?? DayMealsData.empty(),
      richMacros: richMacros,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignTokens.textPrimaryOf(context)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.videoSessionsAccent,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
