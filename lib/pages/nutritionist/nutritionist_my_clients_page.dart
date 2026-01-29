import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/design_tokens.dart';
import '../trainer/create_client_page.dart';

class NutritionistMyClientsPage extends StatefulWidget {
  const NutritionistMyClientsPage({super.key});

  @override
  State<NutritionistMyClientsPage> createState() => _NutritionistMyClientsPageState();
}

class _NutritionistMyClientsPageState extends State<NutritionistMyClientsPage>
    with SingleTickerProviderStateMixin {
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
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadMockData() {
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
        ClientItem(
          id: '4',
          name: 'Mike Wilson',
          email: 'mike@example.com',
          phone: '+1234567893',
          joinDate: DateTime.now().subtract(const Duration(days: 7)),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(rect),
                      child: const Icon(
                        Icons.person_add_outlined,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(rect),
                      child: Text(
                        'MY CLIENTS',
                        style: GoogleFonts.montserrat(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showAddClientDialog(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(rect),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                        ),
                      ),
                      Expanded(
                        child: _buildTabButton(
                          'Pending',
                          1,
                          _selectedTabIndex == 1,
                          textPrimary,
                          textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

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
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTabIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(
            colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.w500,
            fontSize: 15,
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
              color: textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No clients yet',
              style: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add clients to get started',
              style: TextStyle(
                color: textSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            color: Colors.black.withOpacity(0.04),
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
              context.push('/nutritionist/clients/${client.id}', extra: client);
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
                      color: client.statusColor.withOpacity(0.3),
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
                          if (client.status == ClientStatus.active)
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
                      Row(
                        children: [
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
                          if (client.status == ClientStatus.pending) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _pendingRequests.remove(client);
                                  client.status = ClientStatus.active;
                                  _myClients.add(client);
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3ED598).withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (client.status != ClientStatus.pending)
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
