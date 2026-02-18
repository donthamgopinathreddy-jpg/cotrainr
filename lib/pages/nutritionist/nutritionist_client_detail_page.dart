import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../repositories/messages_repository.dart';
import '../../repositories/coach_notes_repository.dart';
import '../trainer/create_client_page.dart';

class NutritionistClientDetailPage extends StatefulWidget {
  final ClientItem? client;
  final String? clientId;

  const NutritionistClientDetailPage({
    super.key,
    this.client,
    this.clientId,
  });

  @override
  State<NutritionistClientDetailPage> createState() => _NutritionistClientDetailPageState();
}

class _NutritionistClientDetailPageState extends State<NutritionistClientDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late TabController _tabController;
  late Animation<double> _fadeAnimation;
  
  final List<String> _tabs = ['Profile', 'Diet Plans', 'Sessions', 'Notes'];

  // Mock client data - in real app, fetch from Supabase using clientId
  late ClientItem _client;
  
  // Mock client profile data (readonly, basic info only)
  final String _age = '28';
  final String _gender = 'Male';
  final String _height = '175 cm';
  final String _weight = '75 kg';
  final List<String> _dietGoals = ['Weight Loss', 'Muscle Gain'];
  final List<String> _dietPreferences = ['Non-vegetarian', 'No allergies'];
  
  // Mock diet plans
  final List<Map<String, dynamic>> _dietPlans = [
    {'title': 'Weight Loss Plan - Week 1', 'date': '2024-01-15', 'type': 'PDF'},
    {'title': 'Meal Plan - January', 'date': '2024-01-10', 'type': 'Image'},
  ];
  
  // Mock sessions
  final List<Map<String, dynamic>> _sessions = [
    {'date': '2024-01-20', 'time': '2:00 PM', 'duration': '45 min', 'type': 'Video Consultation'},
    {'date': '2024-01-15', 'time': '10:00 AM', 'duration': '30 min', 'type': 'Video Consultation'},
  ];

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
        actions: [
          IconButton(
            icon: Icon(Icons.message_outlined, color: textPrimary),
            onPressed: () async {
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
            tooltip: 'Message',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Client Info Header Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  border: Border.all(color: borderColor),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.message_outlined,
                      label: 'Chat',
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
                      icon: Icons.video_call_outlined,
                      label: 'Book Session',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/video/create?role=nutritionist');
                      },
                      textPrimary: textPrimary,
                      surfaceColor: surfaceColor,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tab Bar
            Container(
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

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(textPrimary, textSecondary, surfaceColor, borderColor),
                  _buildDietPlansTab(textPrimary, textSecondary, surfaceColor, borderColor),
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

  Widget _buildProfileTab(
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
          // Basic Info
          Container(
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
                  'Basic Information',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Age', _age, textPrimary, textSecondary),
                const SizedBox(height: 12),
                _buildInfoRow('Gender', _gender, textPrimary, textSecondary),
                const SizedBox(height: 12),
                _buildInfoRow('Height', _height, textPrimary, textSecondary),
                const SizedBox(height: 12),
                _buildInfoRow('Weight', _weight, textPrimary, textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Diet Goals
          Container(
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
                  'Diet Goals',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dietGoals.map((goal) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: DesignTokens.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                    ),
                    child: Text(
                      goal,
                      style: TextStyle(
                        color: DesignTokens.accentOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Diet Preferences
          Container(
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
                  'Diet Preferences',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._dietPreferences.map((pref) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: DesignTokens.accentGreen),
                      const SizedBox(width: 8),
                      Text(
                        pref,
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
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDietPlansTab(
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_dietPlans.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.description_outlined, size: 48, color: textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No diet plans shared yet',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._dietPlans.map((plan) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
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
                    child: Icon(
                      plan['type'] == 'PDF' ? Icons.picture_as_pdf : Icons.image,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan['title'] as String,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan['date'] as String,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.download, color: textSecondary, size: 20),
                ],
              ),
            )),
        ],
      ),
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
      child: Column(
        children: [
          if (_sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.video_library_outlined, size: 48, color: textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions yet',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._sessions.map((session) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
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
                    child: const Icon(
                      Icons.video_call,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['type'] as String,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${session['date']} • ${session['time']} • ${session['duration']}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: textSecondary, size: 20),
                ],
              ),
            )),
        ],
      ),
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
