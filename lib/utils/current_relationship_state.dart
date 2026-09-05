/// Derives the *current* Member↔Provider relationship from lead history.
///
/// Multiple leads may exist for a pair (requested → accepted → ended, then a
/// new requested lead, etc.). Active UI must ignore historical terminal rows.
enum CurrentRelationshipKind { none, pending, accepted }

class CurrentRelationship {
  final CurrentRelationshipKind kind;
  final String? leadId;

  const CurrentRelationship({required this.kind, this.leadId});

  bool get isPending => kind == CurrentRelationshipKind.pending;
  bool get isAccepted => kind == CurrentRelationshipKind.accepted;
  bool get isReconnectable => kind == CurrentRelationshipKind.none;

  /// CTA for Discover / Public Profile: Connect when no live relationship.
  bool get showConnect => isReconnectable;
  bool get showPending => isPending;
  bool get showMessage => isAccepted;
}

/// Active statuses that block a new request (matches create_lead_tx + unique index).
const Set<String> kLiveLeadStatuses = {'requested', 'accepted'};

/// Terminal / historical statuses — never treat as currently connected.
const Set<String> kHistoricalLeadStatuses = {'ended', 'declined', 'cancelled'};

bool isLiveLeadStatus(String? status) {
  final s = (status ?? '').toLowerCase().trim();
  return kLiveLeadStatuses.contains(s);
}

bool isHistoricalLeadStatus(String? status) {
  final s = (status ?? '').toLowerCase().trim();
  return kHistoricalLeadStatuses.contains(s);
}

/// Pick the current relationship for [providerId] from [leads] owned by [clientId].
///
/// Priority: **accepted** > **requested** > none.
/// Historical ended/declined/cancelled leads never win.
CurrentRelationship currentRelationshipForPair({
  required Iterable<Map<String, dynamic>> leads,
  required String clientId,
  required String providerId,
}) {
  String? acceptedId;
  String? requestedId;

  for (final lead in leads) {
    final c = lead['client_id'] as String?;
    final p = lead['provider_id'] as String?;
    if (c != clientId || p != providerId) continue;

    final status = (lead['status'] as String?)?.toLowerCase().trim() ?? '';
    final id = lead['id'] as String?;

    if (status == 'accepted') {
      acceptedId ??= id;
    } else if (status == 'requested') {
      requestedId ??= id;
    }
  }

  if (acceptedId != null) {
    return CurrentRelationship(
      kind: CurrentRelationshipKind.accepted,
      leadId: acceptedId,
    );
  }
  if (requestedId != null) {
    return CurrentRelationship(
      kind: CurrentRelationshipKind.pending,
      leadId: requestedId,
    );
  }
  return const CurrentRelationship(kind: CurrentRelationshipKind.none);
}

/// Same as [currentRelationshipForPair] for strongly typed lead rows.
CurrentRelationship currentRelationshipFromLeadModels({
  required Iterable<
    ({String id, String clientId, String providerId, String status})
  >
  leads,
  required String clientId,
  required String providerId,
}) {
  return currentRelationshipForPair(
    leads: leads.map(
      (l) => {
        'id': l.id,
        'client_id': l.clientId,
        'provider_id': l.providerId,
        'status': l.status,
      },
    ),
    clientId: clientId,
    providerId: providerId,
  );
}
