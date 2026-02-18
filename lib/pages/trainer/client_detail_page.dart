import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../repositories/messages_repository.dart';
import '../../repositories/coach_notes_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/metrics_repository.dart';
import '../../repositories/meal_repository.dart' show MealRepository, DayMealsData;
import 'create_client_page.dart';

class ClientDetailPage extends StatefulWidget {
  final ClientItem? client;
  final String? clientId;

  const ClientDetailPage({
    super.key,
    this.client,
    this.clientId,
  });

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late TabController _tabController;
  late Animation<double> _fadeAnimation;
  
  final List<String> _tabs = ['Overview', 'Metrics', 'Workouts', 'Meals', 'Sessions', 'Notes'];

  late ClientItem _client;

  int _currentSteps = 0;
  int _goalSteps = 10000;
  int _currentCalories = 0;
  double _currentWater = 0;
  double _goalWater = 2.5;
  double _currentDistance = 0;
  double _bmi = 0;
  String _bmiStatus = '—';
  DayMealsData? _mealsData;
  final ProfileRepository _profileRepo = ProfileRepository();
  final MetricsRepository _metricsRepo = MetricsRepository();
  final MealRepository _mealRepo = MealRepository();

  // Notes controller
  final TextEditingController _notesController = TextEditingController();
  final CoachNotesRepository _notesRepo = CoachNotesRepository();
  
  // Notes list - from Supabase coach_notes
  List<CoachNote> _notesList = [];


  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ClientItem(
      id: widget.clientId ?? '1',
      name: 'John Doe',
      email: 'john@example.com',
      phone: '+1234567890',
      joinDate: DateTime.now().subtract(const Duration(days: 30)),
      status: ClientStatus.active,
      avatar: null,
      alerts: [ClientAlert.waterLow],
      adherencePercentage: 85.5,
      lastCheckIn: DateTime.now().subtract(const Duration(hours: 2)),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fadeController.forward();
    _loadNotes();
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    final id = widget.clientId ?? _client.id;
    if (id.isEmpty) return;
    try {
      final profile = await _profileRepo.fetchUserProfile(id);
      if (profile != null && mounted) {
        setState(() {
          _client = ClientItem(
            id: id,
            name: profile['full_name'] as String? ?? profile['username'] as String? ?? 'Client',
            email: profile['username'] != null ? '@${profile['username']}' : '—',
            phone: profile['phone'] as String? ?? '',
            joinDate: _client.joinDate,
            status: _client.status,
            avatar: profile['avatar_url'] as String?,
            alerts: _client.alerts,
            adherencePercentage: _client.adherencePercentage,
            lastCheckIn: _client.lastCheckIn,
          );
          _bmi = (profile['bmi'] as num?)?.toDouble() ?? 0;
          _bmiStatus = profile['bmi_status'] as String? ?? '—';
        });
      }
      final todayMetrics = await _metricsRepo.getClientMetricsForDate(id, DateTime.now());
      final meals = await _mealRepo.getClientDayMeals(id, DateTime.now());
      if (mounted) {
        setState(() {
          _currentSteps = (todayMetrics?['steps'] as num?)?.toInt() ?? 0;
          _currentCalories = ((todayMetrics?['calories_burned'] as num?)?.toDouble() ?? 0.0).round();
          _currentWater = (todayMetrics?['water_intake_liters'] as num?)?.toDouble() ?? 0;
          _currentDistance = (todayMetrics?['distance_km'] as num?)?.toDouble() ?? 0;
          _mealsData = meals;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadNotes() async {
    final id = widget.clientId ?? _client.id;
    if (id.isEmpty) return;
    try {
      final notes = await _notesRepo.getNotesForClient(id);
      if (mounted) setState(() => _notesList = notes);
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      appBar: AppBar(
        title: Text(
          _client.name,
          style: TextStyle(
            color: textPrimary,
            fontWeight: DesignTokens.fontWeightBold,
            fontSize: DesignTokens.fontSizeH3,
          ),
        ),
        backgroundColor: DesignTokens.surfaceOf(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Client Info Header Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DesignTokens.accentOrange.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _client.avatar != null
                              ? Image.network(
                                  _client.avatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildAvatarPlaceholder(),
                                )
                              : _buildAvatarPlaceholder(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Client Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _client.name,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: DesignTokens.fontSizeH3,
                                fontWeight: DesignTokens.fontWeightBold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _client.email,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: DesignTokens.fontSizeBody,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _client.statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                                  ),
                                  child: Text(
                                    _client.statusString,
                                    style: TextStyle(
                                      color: _client.statusColor,
                                      fontSize: DesignTokens.fontSizeBodySmall,
                                      fontWeight: DesignTokens.fontWeightSemiBold,
                                    ),
                                  ),
                                ),
                                if (_client.alerts.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DesignTokens.accentRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 14,
                                          color: DesignTokens.accentRed,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_client.alerts.length}',
                                          style: TextStyle(
                                            color: DesignTokens.accentRed,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildActionButtons(context, textPrimary, textSecondary, surfaceColor, borderColor),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Tab Bar
            SliverToBoxAdapter(
              child: Container(
                color: surfaceColor,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: textPrimary,
                  unselectedLabelColor: textSecondary,
                  indicatorColor: DesignTokens.accentOrange,
                  indicatorWeight: 3,
                  tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                  onTap: (index) {
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ),

            // Tab Content
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(textPrimary, textSecondary, surfaceColor, borderColor),
                  _buildMetricsTab(textPrimary, textSecondary, surfaceColor, borderColor),
                  _buildWorkoutsTab(textPrimary, textSecondary, surfaceColor, borderColor),
                  _buildMealsTab(textPrimary, textSecondary, surfaceColor, borderColor),
                  _buildSessionsTab(textPrimary, textSecondary, surfaceColor, borderColor),
                  _buildNotesTab(textPrimary, textSecondary, surfaceColor, borderColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.message_outlined,
            label: 'Message',
            onTap: () async {
              HapticFeedback.lightImpact();
              final convId = await MessagesRepository().createOrFindConversation(_client.id);
              if (convId != null && context.mounted) {
                context.push('/messaging/chat/$convId', extra: {
                  'userName': _client.name,
                  'isOnline': true,
                  'avatarUrl': _client.avatar,
                });
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open chat. Please try again.')),
                );
              }
            },
            textPrimary: textPrimary,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.assignment_outlined,
            label: 'Assign Plan',
            onTap: () {
              HapticFeedback.lightImpact();
              _showAssignPlanDialog(context, textPrimary, textSecondary, surfaceColor, borderColor);
            },
            textPrimary: textPrimary,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.video_call_outlined,
            label: 'Book Session',
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/video/create?role=trainer');
            },
            textPrimary: textPrimary,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.notifications_active_outlined,
            label: 'Send Reminder',
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Send reminder notification
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reminder sent to ${_client.name}')),
              );
            },
            textPrimary: textPrimary,
            surfaceColor: surfaceColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color surfaceColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          border: Border.all(
            color: DesignTokens.borderColorOf(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reports Section
          _buildReportsSection(textPrimary, textSecondary, surfaceColor, borderColor),
          const SizedBox(height: 24),
          // Quick Stats
          _buildQuickStats(textPrimary, textSecondary, surfaceColor, borderColor),
          const SizedBox(height: 24),
          // Alerts
          if (_client.alerts.isNotEmpty) ...[
            _buildAlertsSection(textPrimary, textSecondary, surfaceColor, borderColor),
            const SizedBox(height: 24),
          ],
          // Recent Activity
          _buildRecentActivity(textPrimary, textSecondary, surfaceColor, borderColor),
        ],
      ),
    );
  }

  Widget _buildMetricsTab(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildOverviewContent(textPrimary, textSecondary, surfaceColor, borderColor),
    );
  }

  Widget _buildWorkoutsTab(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.fitness_center, size: 48, color: textSecondary),
                const SizedBox(height: 16),
                Text(
                  'Workout Log',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View ${_client.name}\'s workout history and progress',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsTab(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildMealsContent(textPrimary, textSecondary, surfaceColor, borderColor),
    );
  }


  Widget _buildSessionsTab(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildSessionsContent(textPrimary, textSecondary, surfaceColor, borderColor),
    );
  }

  Widget _buildNotesTab(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Column(
      children: [
        Expanded(
          child: _notesList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 64,
                        color: textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notes yet',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: DesignTokens.fontSizeBody,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notesList.length,
                  itemBuilder: (context, index) {
                    final note = _notesList[index]; // Newest first (already ordered)
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  note.content,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: DesignTokens.fontSizeBody,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatNoteDate(note.createdAt),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: DesignTokens.fontSizeBodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(
              top: BorderSide(color: borderColor),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _notesController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Add notes about ${_client.name}...',
                    hintStyle: TextStyle(color: textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                      borderSide: BorderSide(color: DesignTokens.accentOrange, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: DesignTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _sendNoteToClient(textPrimary),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatNoteDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _sendNoteToClient(Color textPrimary) async {
    final noteText = _notesController.text.trim();
    if (noteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a note before sending'),
          backgroundColor: textPrimary.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final clientId = widget.clientId ?? _client.id;
    if (clientId.isEmpty) return;

    final note = await _notesRepo.addNote(clientId, noteText);
    if (!mounted) return;

    if (note != null) {
      setState(() => _notesList = [note, ..._notesList]);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note sent to ${_client.name}'),
          backgroundColor: DesignTokens.accentGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      _notesController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not send note. Make sure you have accepted this client.'),
          backgroundColor: DesignTokens.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildReportsSection(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reports',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // TODO: Export PDF
                  HapticFeedback.lightImpact();
                },
                icon: Icon(Icons.download, size: 18, color: DesignTokens.accentOrange),
                label: Text(
                  'Export PDF',
                  style: TextStyle(color: DesignTokens.accentOrange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekly Summary
          _buildReportCard(
            'Weekly Summary',
            'Steps: 58.2k | Calories: 12.4k | Water: 11.3L',
            Icons.summarize,
            textPrimary,
            textSecondary,
          ),
          const SizedBox(height: 12),
          // Adherence
          if (_client.adherencePercentage != null)
            _buildReportCard(
              'Adherence',
              '${_client.adherencePercentage!.toStringAsFixed(1)}%',
              Icons.trending_up,
              textPrimary,
              textSecondary,
            ),
          const SizedBox(height: 12),
          // Trend Charts
          _buildReportCard(
            'Trend Charts',
            'View 7-day, 30-day, and 90-day trends',
            Icons.show_chart,
            textPrimary,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String value,
    IconData icon,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.backgroundOf(context),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Steps', '8.2k', Icons.directions_walk, textPrimary, textSecondary),
              ),
              Expanded(
                child: _buildStatItem('Calories', '1.8k', Icons.local_fire_department, textPrimary, textSecondary),
              ),
              Expanded(
                child: _buildStatItem('Water', '1.5L', Icons.water_drop, textPrimary, textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        Icon(icon, size: 24, color: textSecondary),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsSection(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: DesignTokens.accentRed, size: 20),
              const SizedBox(width: 8),
              Text(
                'Alerts',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._client.alerts.map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  _client.getAlertIcon(alert),
                  size: 16,
                  color: DesignTokens.accentRed,
                ),
                const SizedBox(width: 8),
                Text(
                  _client.getAlertLabel(alert),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_client.lastCheckIn != null)
            Text(
              'Last check-in: ${_formatDateTime(_client.lastCheckIn!)}',
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
  }


  Widget _buildOverviewContent(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _buildMetricListItem(
            icon: Icons.directions_walk,
            title: 'Steps',
            value: '$_currentSteps / $_goalSteps',
            unit: 'steps',
            color: DesignTokens.accentGreen,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const Divider(height: 24),
          _buildMetricListItem(
            icon: Icons.local_fire_department,
            title: 'Calories',
            value: '$_currentCalories / 2000',
            unit: 'kcal',
            color: DesignTokens.accentOrange,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const Divider(height: 24),
          _buildMetricListItem(
            icon: Icons.water_drop,
            title: 'Water',
            value: '${_currentWater.toStringAsFixed(1)} / ${_goalWater.toStringAsFixed(1)}',
            unit: 'L',
            color: DesignTokens.accentBlue,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const Divider(height: 24),
          _buildMetricListItem(
            icon: Icons.straighten,
            title: 'Distance',
            value: '${_currentDistance.toStringAsFixed(1)} / 5.0',
            unit: 'km',
            color: DesignTokens.accentPurple,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const Divider(height: 24),
          _buildMetricListItem(
            icon: Icons.monitor_weight,
            title: 'BMI',
            value: _bmi.toStringAsFixed(1),
            unit: _bmiStatus,
            color: _bmiStatus == 'Normal' ? DesignTokens.accentGreen : DesignTokens.accentOrange,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricListItem({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: DesignTokens.fontSizeBodySmall,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: DesignTokens.fontSizeBodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealsContent(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/meal-tracker');
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: DesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
              ),
              child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Meals",
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mealsData != null && _mealsData!.totalCalories > 0
                        ? '${_mealsData!.totalCalories} cal • P: ${_mealsData!.totalProtein.toStringAsFixed(0)}g'
                        : 'No meals logged today',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: DesignTokens.fontSizeBodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textSecondary, size: 24),
          ],
        ),
      ),
    );
  }


  Widget _buildSessionsContent(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/video?role=client');
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: DesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
              ),
              child: const Icon(Icons.video_library, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View Video Sessions',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See ${_client.name}\'s scheduled and past sessions',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: DesignTokens.fontSizeBodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textSecondary, size: 24),
          ],
        ),
      ),
    );
  }



  void _showAssignPlanDialog(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    String selectedPlanType = 'diet'; // 'diet' or 'workout'
    String selectedWorkoutType = 'calisthenics'; // 'calisthenics', 'yoga', 'zumba'
    final TextEditingController planTitleController = TextEditingController();
    final TextEditingController caloriesController = TextEditingController();
    final TextEditingController planDetailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          ),
          title: Text(
            'Assign Plan',
            style: TextStyle(
              color: textPrimary,
              fontSize: DesignTokens.fontSizeH3,
              fontWeight: DesignTokens.fontWeightBold,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan Type Selection
                  Text(
                    'Plan Type',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedPlanType = 'diet'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selectedPlanType == 'diet'
                                  ? DesignTokens.accentOrange.withOpacity(0.1)
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                              border: Border.all(
                                color: selectedPlanType == 'diet'
                                    ? DesignTokens.accentOrange
                                    : borderColor,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  color: selectedPlanType == 'diet'
                                      ? DesignTokens.accentOrange
                                      : textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Diet/Calories',
                                  style: TextStyle(
                                    color: selectedPlanType == 'diet'
                                        ? DesignTokens.accentOrange
                                        : textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedPlanType = 'workout'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selectedPlanType == 'workout'
                                  ? DesignTokens.accentOrange.withOpacity(0.1)
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                              border: Border.all(
                                color: selectedPlanType == 'workout'
                                    ? DesignTokens.accentOrange
                                    : borderColor,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.fitness_center,
                                  color: selectedPlanType == 'workout'
                                      ? DesignTokens.accentOrange
                                      : textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Workout',
                                  style: TextStyle(
                                    color: selectedPlanType == 'workout'
                                        ? DesignTokens.accentOrange
                                        : textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Workout Type Selection (only if workout is selected)
                  if (selectedPlanType == 'workout') ...[
                    Text(
                      'Workout Type',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.fontWeightSemiBold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['calisthenics', 'yoga', 'zumba'].map((type) {
                        final isSelected = selectedWorkoutType == type;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedWorkoutType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DesignTokens.accentOrange.withOpacity(0.1)
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                              border: Border.all(
                                color: isSelected ? DesignTokens.accentOrange : borderColor,
                              ),
                            ),
                            child: Text(
                              type[0].toUpperCase() + type.substring(1),
                              style: TextStyle(
                                color: isSelected ? DesignTokens.accentOrange : textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Plan Title
                  Text(
                    'Plan Title',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: planTitleController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Weekly Meal Plan',
                      hintStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                        borderSide: BorderSide(color: DesignTokens.accentOrange, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Calories Input (only if diet is selected)
                  if (selectedPlanType == 'diet') ...[
                    Text(
                      'Daily Calories Intake',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.fontWeightSemiBold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g., 2000',
                        hintStyle: TextStyle(color: textSecondary),
                        suffixText: 'kcal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                          borderSide: BorderSide(color: DesignTokens.accentOrange, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Plan Details
                  Text(
                    'Plan Details',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: planDetailsController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: selectedPlanType == 'diet'
                          ? 'Enter meal plan details, daily breakdown...'
                          : 'Enter workout plan details, exercises, sets, reps...',
                      hintStyle: TextStyle(color: textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                        borderSide: BorderSide(color: DesignTokens.accentOrange, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                planTitleController.dispose();
                caloriesController.dispose();
                planDetailsController.dispose();
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: textSecondary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: DesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              ),
              child: TextButton(
                onPressed: () {
                  if (planTitleController.text.trim().isEmpty ||
                      planDetailsController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please fill in all required fields'),
                        backgroundColor: DesignTokens.accentRed,
                      ),
                    );
                    return;
                  }
                  
                  if (selectedPlanType == 'diet' && caloriesController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enter daily calories intake'),
                        backgroundColor: DesignTokens.accentRed,
                      ),
                    );
                    return;
                  }
                  
                  // TODO: Save plan to Supabase and send notification to client
                  // This would typically involve:
                  // 1. Saving plan to database
                  // 2. Sending push notification to client
                  // 3. Creating notification record
                  
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Plan sent to ${_client.name}. They will receive a notification and can save it as a document.',
                      ),
                      backgroundColor: DesignTokens.accentGreen,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  
                  planTitleController.dispose();
                  caloriesController.dispose();
                  planDetailsController.dispose();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Send Plan',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: DesignTokens.primaryGradient,
      ),
      child: Center(
        child: Text(
          _client.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
