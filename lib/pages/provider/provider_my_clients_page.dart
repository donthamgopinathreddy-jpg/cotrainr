import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/provider_practice_provider.dart';
import '../../services/leads_models.dart' show Lead;
import '../../services/leads_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/app_overlays.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/profile/account_hub_widgets.dart';
import '../../widgets/video_sessions/video_session_avatar.dart';
import '../../widgets/video_sessions/video_session_theme.dart';
import '../trainer/create_client_page.dart';

/// Maps a provider-side lead into a [ClientItem] for My Clients UI.
/// Always preserves [Lead.id] as [ClientItem.leadId] for requested and accepted.
@visibleForTesting
ClientItem mapLeadToClientItem(Lead lead) {
  final client = lead.client;
  final name = (client?['full_name'] as String?)?.trim() ?? '';
  final username = (client?['username'] as String?)?.trim() ?? '';
  return ClientItem(
    id: lead.clientId,
    name: name.isNotEmpty ? name : (username.isNotEmpty ? username : 'Client'),
    email: username.isNotEmpty ? '@$username' : 'Active',
    phone: '',
    joinDate: lead.createdAt,
    status: lead.status == 'accepted'
        ? ClientStatus.active
        : ClientStatus.pending,
    avatar: (client?['avatar_url'] as String?)?.trim(),
    leadId: lead.id,
    requestMessage: lead.message,
  );
}

class ProviderMyClientsPage extends ConsumerStatefulWidget {
  final String providerType;
  final String clientPathPrefix;
  final LeadsService? leadsService;
  final Future<void> Function({required String leadId, required String status})?
  updateLeadStatus;
  final Future<void> Function({required String leadId, required String reason})?
  endConnection;
  final List<ClientItem>? initialClients;
  final List<ClientItem>? initialRequests;

  const ProviderMyClientsPage({
    super.key,
    required this.providerType,
    required this.clientPathPrefix,
    this.leadsService,
    this.updateLeadStatus,
    this.endConnection,
    this.initialClients,
    this.initialRequests,
  });

  @override
  ConsumerState<ProviderMyClientsPage> createState() =>
      _ProviderMyClientsPageState();
}

class _ProviderMyClientsPageState extends ConsumerState<ProviderMyClientsPage> {
  LeadsService? _leadsService;
  final _clientsScroll = ScrollController();
  final _requestsScroll = ScrollController();

  int _selectedTabIndex = 0;
  bool _loading = true;
  String? _busyLeadId;
  final List<ClientItem> _myClients = [];
  final List<ClientItem> _requests = [];

  @override
  void initState() {
    super.initState();
    _leadsService = widget.leadsService;
    _selectedTabIndex = ref.read(providerClientsTabIntentProvider).clamp(0, 1);
    if (widget.initialClients != null || widget.initialRequests != null) {
      _myClients.addAll(widget.initialClients ?? const []);
      _requests.addAll(widget.initialRequests ?? const []);
      _loading = false;
    } else {
      _leadsService ??= LeadsService();
      _loadLeads();
    }
  }

  @override
  void dispose() {
    _clientsScroll.dispose();
    _requestsScroll.dispose();
    super.dispose();
  }

  Future<void> _loadLeads({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final service = _leadsService;
      if (service == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final leads = await service.getMyLeads();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final filtered = leads
          .where(
            (l) => l.providerId == uid && l.providerType == widget.providerType,
          )
          .toList();
      final accepted = filtered.where((l) => l.status == 'accepted').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final pending = filtered.where((l) => l.status == 'requested').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // One active card per client (ignore corrupt duplicate accepted rows).
      final seenClients = <String>{};
      final acceptedUnique = <Lead>[];
      for (final l in accepted) {
        if (seenClients.add(l.clientId)) acceptedUnique.add(l);
      }
      final seenPending = <String>{};
      final pendingUnique = <Lead>[];
      for (final l in pending) {
        if (seenPending.add(l.clientId)) pendingUnique.add(l);
      }
      if (!mounted) return;
      setState(() {
        _myClients
          ..clear()
          ..addAll(acceptedUnique.map(mapLeadToClientItem));
        _requests
          ..clear()
          ..addAll(pendingUnique.map(mapLeadToClientItem));
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showHubSnackBar(context, 'Could not load clients. Pull to retry.');
      }
    }
  }

  void _invalidateCounts() {
    try {
      invalidateProviderHomeCounts(ref);
    } catch (_) {}
  }

  Future<void> _updateLead(ClientItem client, String status) async {
    final leadId = client.leadId;
    if (leadId == null || _busyLeadId != null) return;
    setState(() => _busyLeadId = leadId);
    try {
      if (widget.updateLeadStatus != null) {
        await widget.updateLeadStatus!(leadId: leadId, status: status);
      } else {
        final service = _leadsService;
        if (service == null) {
          throw StateError('Missing leads service');
        }
        await service.updateLeadStatus(leadId: leadId, status: status);
      }
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((c) => c.leadId == leadId);
        if (status == 'accepted') {
          _myClients.insert(
            0,
            ClientItem(
              id: client.id,
              name: client.name,
              email: client.email == 'Active' ? 'Active' : client.email,
              phone: '',
              joinDate: client.joinDate,
              status: ClientStatus.active,
              avatar: client.avatar,
              leadId: leadId,
            ),
          );
        }
        _busyLeadId = null;
      });
      _invalidateCounts();
      showHubSnackBar(
        context,
        status == 'accepted' ? 'Client accepted' : 'Request declined',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyLeadId = null);
      showHubSnackBar(context, 'Could not update this request. Try again.');
      await _loadLeads(silent: true);
    }
  }

  Future<void> _showEndRelationshipSheet(ClientItem client) async {
    final leadId = client.leadId;
    if (leadId == null || leadId.isEmpty || _busyLeadId != null) return;

    HapticFeedback.selectionClick();
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return _EndRelationshipSheet(
          clientName: client.name,
          onKeep: () => Navigator.of(ctx).pop(),
          onConfirm: (reason) async {
            if (_busyLeadId != null) return false;
            setState(() => _busyLeadId = leadId);
            final effectiveReason = reason.trim().isEmpty
                ? 'Ended by provider'
                : reason.trim();
            try {
              if (widget.endConnection != null) {
                await widget.endConnection!(
                  leadId: leadId,
                  reason: effectiveReason,
                );
              } else {
                final service = _leadsService ?? LeadsService();
                await service.endConnection(
                  leadId: leadId,
                  reason: effectiveReason,
                );
              }
              if (!ctx.mounted) return true;
              Navigator.of(ctx).pop();
              if (!mounted) return true;
              setState(() {
                _myClients.removeWhere((c) => c.leadId == leadId);
                _busyLeadId = null;
              });
              _invalidateCounts();
              await _loadLeads(silent: true);
              if (!mounted) return true;
              showHubSnackBar(context, 'Relationship ended');
              return true;
            } catch (_) {
              if (mounted) {
                setState(() => _busyLeadId = null);
                showHubSnackBar(
                  context,
                  'Could not end this relationship. Try again.',
                );
              }
              return false;
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(providerClientsTabIntentProvider, (prev, next) {
      final tab = next.clamp(0, 1);
      if (tab != _selectedTabIndex) {
        setState(() => _selectedTabIndex = tab);
      }
    });

    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final bg = isLight
        ? HomePremiumTheme.lightWarmBg
        : DesignTokens.darkBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Clients',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Tabs(
                selected: _selectedTabIndex,
                requestCount: _requests.length,
                onSelect: (i) {
                  HapticFeedback.selectionClick();
                  ref.read(providerClientsTabIntentProvider.notifier).state = i;
                  setState(() => _selectedTabIndex = i);
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const _ListSkeleton()
                  : RefreshIndicator(
                      color: DesignTokens.videoSessionsAccent,
                      onRefresh: () async {
                        await _loadLeads(silent: true);
                        _invalidateCounts();
                      },
                      child: _selectedTabIndex == 0
                          ? _ClientsList(
                              items: _myClients,
                              controller: _clientsScroll,
                              isLight: isLight,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              emptyTitle: 'No clients yet',
                              emptyBody:
                                  'New client connections will appear here.',
                              busyLeadId: _busyLeadId,
                              onOpen: _openClient,
                              onEndRelationship: _showEndRelationshipSheet,
                            )
                          : _ClientsList(
                              items: _requests,
                              controller: _requestsScroll,
                              isLight: isLight,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              emptyTitle: 'No requests right now',
                              emptyBody:
                                  'Pending client requests will appear here.',
                              busyLeadId: _busyLeadId,
                              onAccept: (c) => _updateLead(c, 'accepted'),
                              onDecline: (c) => _updateLead(c, 'declined'),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openClient(ClientItem client) {
    if (client.id.isEmpty) return;
    context.push('${widget.clientPathPrefix}/${client.id}', extra: client);
  }
}

class _Tabs extends StatelessWidget {
  final int selected;
  final int requestCount;
  final ValueChanged<int> onSelect;

  const _Tabs({
    required this.selected,
    required this.requestCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: VideoSessionUi.cardBox(context),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: 'Clients',
              selected: selected == 0,
              onTap: () => onSelect(0),
            ),
          ),
          Expanded(
            child: _Tab(
              label: requestCount > 0 ? 'Requests $requestCount' : 'Requests',
              selected: selected == 1,
              showDot: requestCount > 0,
              semanticLabel: requestCount > 0
                  ? 'Requests, $requestCount needing action'
                  : 'Requests',
              onTap: () => onSelect(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showDot;
  final String? semanticLabel;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? DesignTokens.videoSessionsAccent
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : HomePremiumTheme.secondaryText(isLight),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (showDot) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: DesignTokens.accentRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientsList extends StatelessWidget {
  final List<ClientItem> items;
  final ScrollController controller;
  final bool isLight;
  final Color textPrimary;
  final Color textSecondary;
  final String emptyTitle;
  final String emptyBody;
  final ValueChanged<ClientItem>? onOpen;
  final ValueChanged<ClientItem>? onAccept;
  final ValueChanged<ClientItem>? onDecline;
  final ValueChanged<ClientItem>? onEndRelationship;
  final String? busyLeadId;

  const _ClientsList({
    required this.items,
    required this.controller,
    required this.isLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.emptyTitle,
    required this.emptyBody,
    this.onOpen,
    this.onAccept,
    this.onDecline,
    this.onEndRelationship,
    this.busyLeadId,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        children: [
          Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            emptyBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final client = items[i];
        final isRequest = onAccept != null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ClientCard(
            client: client,
            isLight: isLight,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            busy: busyLeadId != null && busyLeadId == client.leadId,
            onOpen: isRequest ? null : () => onOpen?.call(client),
            onAccept: onAccept == null ? null : () => onAccept!(client),
            onDecline: onDecline == null ? null : () => onDecline!(client),
            onEndRelationship:
                !isRequest &&
                    onEndRelationship != null &&
                    (client.leadId?.isNotEmpty ?? false)
                ? () => onEndRelationship!(client)
                : null,
          ),
        );
      },
    );
  }
}

class _ClientCard extends StatelessWidget {
  final ClientItem client;
  final bool isLight;
  final Color textPrimary;
  final Color textSecondary;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onEndRelationship;

  const _ClientCard({
    required this.client,
    required this.isLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.busy,
    this.onOpen,
    this.onAccept,
    this.onDecline,
    this.onEndRelationship,
  });

  @override
  Widget build(BuildContext context) {
    final request = onAccept != null;
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      button: !request,
      label: request ? 'Request from ${client.name}' : 'Client ${client.name}',
      child: PressableCard(
        borderRadius: VideoSessionUi.radius,
        onTap: request ? null : onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: VideoSessionUi.cardBox(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VideoSessionAvatar(
                    name: client.name,
                    imageUrl: client.avatar,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request ? 'Wants to connect' : client.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (!request && onEndRelationship != null) ...[
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      padding: EdgeInsets.zero,
                      enabled: !busy,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 22,
                        color: textSecondary,
                      ),
                      onSelected: (value) {
                        if (value == 'end') onEndRelationship!();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'end',
                          child: Text(
                            'End relationship',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right_rounded, color: textSecondary),
                  ] else if (!request)
                    Icon(Icons.chevron_right_rounded, color: textSecondary),
                ],
              ),
              if (request &&
                  client.requestMessage != null &&
                  client.requestMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  client.requestMessage!.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
              if (request) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: Semantics(
                          button: true,
                          label: 'Accept',
                          child: ElevatedButton(
                            onPressed: busy ? null : onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.videoSessionsAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Accept',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: Semantics(
                          button: true,
                          label: 'Decline',
                          child: OutlinedButton(
                            onPressed: busy ? null : onDecline,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(
                                color: VideoSessionUi.border(context),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Decline',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE8E8EA)
        : Colors.white.withValues(alpha: 0.08);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 72,
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

const _kEndReasons = <String>[
  'Client request',
  'Coaching completed',
  'Not a suitable match',
  'No longer available',
  'Other',
];

class _EndRelationshipSheet extends StatefulWidget {
  final String clientName;
  final VoidCallback onKeep;
  final Future<bool> Function(String reason) onConfirm;

  const _EndRelationshipSheet({
    required this.clientName,
    required this.onKeep,
    required this.onConfirm,
  });

  @override
  State<_EndRelationshipSheet> createState() => _EndRelationshipSheetState();
}

class _EndRelationshipSheetState extends State<_EndRelationshipSheet> {
  String _selectedReason = _kEndReasons.first;
  final _otherController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  String _resolvedReason() {
    if (_selectedReason == 'Other') {
      final other = _otherController.text.trim();
      return other.isEmpty ? 'Other' : other;
    }
    return _selectedReason;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onConfirm(_resolvedReason());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final error = Theme.of(context).colorScheme.error;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final busy = _submitting;
    final name = widget.clientName.trim().isEmpty
        ? 'this client'
        : widget.clientName;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'End relationship?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You’ll no longer be connected with $name. Your previous messages '
            'and shared history will remain available.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reason',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in _kEndReasons)
                ChoiceChip(
                  label: Text(reason),
                  selected: _selectedReason == reason,
                  onSelected: busy
                      ? null
                      : (_) => setState(() => _selectedReason = reason),
                ),
            ],
          ),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _otherController,
              enabled: !busy,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Add a short note',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: error,
              disabledBackgroundColor: error.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'End relationship',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
          ),
          TextButton(
            onPressed: busy ? null : widget.onKeep,
            child: Text(
              'Keep relationship',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
