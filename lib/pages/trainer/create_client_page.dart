import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';

class CreateClientPage extends StatefulWidget {
  const CreateClientPage({super.key});

  @override
  State<CreateClientPage> createState() => _CreateClientPageState();
}

class _CreateClientPageState extends State<CreateClientPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _selectedTabIndex = 0;

  // Mock data - in real app, fetch from Supabase
  final List<ClientItem> _myClients = [];
  final List<ClientItem> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadMockData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    // Mock data - replace with actual Supabase query
    setState(() {
      _myClients.addAll([
        ClientItem(
          id: '1',
          name: 'John Doe',
          email: 'john@example.com',
          phone: '+1234567890',
          joinDate: DateTime.now().subtract(const Duration(days: 30)),
          status: ClientStatus.active,
          avatar: null,
        ),
        ClientItem(
          id: '2',
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '+1234567891',
          joinDate: DateTime.now().subtract(const Duration(days: 15)),
          status: ClientStatus.active,
          avatar: null,
        ),
      ]);
      _pendingRequests.addAll([
        ClientItem(
          id: '3',
          name: 'Bob Johnson',
          email: 'bob@example.com',
          phone: '+1234567892',
          joinDate: DateTime.now().subtract(const Duration(days: 2)),
          status: ClientStatus.pending,
          avatar: null,
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final surfaceColor = DesignTokens.surfaceOf(context);
    final borderColor = DesignTokens.borderColorOf(context);

    return Scaffold(
      backgroundColor: DesignTokens.backgroundOf(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(DesignTokens.spacing20),
                child: Row(
                  children: [
                    Text(
                      'My Clients',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeH1,
                        fontWeight: DesignTokens.fontWeightBold,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // Add client button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showAddClientDialog(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(DesignTokens.spacing12),
                        decoration: BoxDecoration(
                          gradient: DesignTokens.primaryGradient,
                          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing20,
                  vertical: DesignTokens.spacing12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search clients...',
                      hintStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(Icons.search, color: textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing16,
                        vertical: DesignTokens.spacing12,
                      ),
                    ),
                  ),
                ),
              ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        'My Clients',
                        0,
                        _selectedTabIndex == 0,
                        textPrimary,
                        textSecondary,
                        surfaceColor,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        'Pending',
                        1,
                        _selectedTabIndex == 1,
                        textPrimary,
                        textSecondary,
                        surfaceColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DesignTokens.spacing16),

              // Content
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildClientsList(_myClients, textPrimary, textSecondary, surfaceColor, borderColor)
                    : _buildClientsList(_pendingRequests, textPrimary, textSecondary, surfaceColor, borderColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    int index,
    bool isSelected,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTabIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacing12),
        decoration: BoxDecoration(
          gradient: isSelected ? DesignTokens.primaryGradient : null,
          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontWeight: isSelected
                ? DesignTokens.fontWeightSemiBold
                : DesignTokens.fontWeightRegular,
            fontSize: DesignTokens.fontSizeBody,
          ),
        ),
      ),
    );
  }

  Widget _buildClientsList(
    List<ClientItem> clients,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    if (clients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: textSecondary,
            ),
            const SizedBox(height: DesignTokens.spacing16),
            Text(
              'No clients yet',
              style: TextStyle(
                color: textSecondary,
                fontSize: DesignTokens.fontSizeBody,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        return _buildClientCard(context, client, textPrimary, textSecondary, surfaceColor, borderColor);
      },
    );
  }

  Widget _buildClientCard(
    BuildContext context,
    ClientItem client,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
            child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              if (client.id.isNotEmpty) {
                context.push('/clients/${client.id}', extra: client);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Client ID is missing'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            splashColor: DesignTokens.accentOrange.withOpacity(0.1),
            highlightColor: DesignTokens.accentOrange.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: client.status == 'Active'
                            ? DesignTokens.accentGreen.withOpacity(0.3)
                            : DesignTokens.accentOrange.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: client.avatar != null
                          ? Image.network(
                              client.avatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildAvatarPlaceholder(client.name),
                            )
                          : _buildAvatarPlaceholder(client.name),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                client.name,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (client.status == 'Active')
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: DesignTokens.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          client.email,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: client.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            client.statusString,
                            style: TextStyle(
                              color: client.statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  if (client.status == ClientStatus.pending)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // Accept client request
                          setState(() {
                            _pendingRequests.remove(client);
                            client.status = ClientStatus.active;
                            _myClients.add(client);
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: DesignTokens.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: DesignTokens.accentOrange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary.withOpacity(0.4),
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: DesignTokens.primaryGradient,
      ),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignTokens.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
        title: Text(
          'Add Client',
          style: TextStyle(
            color: DesignTokens.textPrimaryOf(context),
            fontWeight: DesignTokens.fontWeightBold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: DesignTokens.textSecondaryOf(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Name (Optional)',
                labelStyle: TextStyle(color: DesignTokens.textSecondaryOf(context)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: DesignTokens.textSecondaryOf(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement add client logic
              Navigator.pop(context);
            },
            child: Text(
              'Add',
              style: TextStyle(
                color: DesignTokens.accentOrange,
                fontWeight: DesignTokens.fontWeightSemiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ClientStatus { active, atRisk, newClient, pending }

enum ClientAlert {
  missedCheckin,
  proteinLow,
  waterLow,
  weightSpike,
  overtraining,
}

class ClientItem {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime joinDate;
  ClientStatus status;
  final String? avatar;
  final List<ClientAlert> alerts;
  final double? adherencePercentage; // 0-100
  final DateTime? lastCheckIn;
  final String? leadId; // For pending: needed to accept

  ClientItem({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.joinDate,
    required this.status,
    this.avatar,
    this.alerts = const [],
    this.adherencePercentage,
    this.lastCheckIn,
    this.leadId,
  });

  String get statusString {
    switch (status) {
      case ClientStatus.active:
        return 'Active';
      case ClientStatus.atRisk:
        return 'At Risk';
      case ClientStatus.newClient:
        return 'New';
      case ClientStatus.pending:
        return 'Pending';
    }
  }

  Color get statusColor {
    switch (status) {
      case ClientStatus.active:
        return DesignTokens.accentGreen;
      case ClientStatus.atRisk:
        return DesignTokens.accentRed;
      case ClientStatus.newClient:
        return DesignTokens.accentBlue;
      case ClientStatus.pending:
        return DesignTokens.accentOrange;
    }
  }

  String getAlertLabel(ClientAlert alert) {
    switch (alert) {
      case ClientAlert.missedCheckin:
        return 'Missed Check-in';
      case ClientAlert.proteinLow:
        return 'Protein Low';
      case ClientAlert.waterLow:
        return 'Water Low';
      case ClientAlert.weightSpike:
        return 'Weight Spike';
      case ClientAlert.overtraining:
        return 'Overtraining';
    }
  }

  IconData getAlertIcon(ClientAlert alert) {
    switch (alert) {
      case ClientAlert.missedCheckin:
        return Icons.event_busy;
      case ClientAlert.proteinLow:
        return Icons.restaurant;
      case ClientAlert.waterLow:
        return Icons.water_drop;
      case ClientAlert.weightSpike:
        return Icons.trending_up;
      case ClientAlert.overtraining:
        return Icons.warning;
    }
  }
}
