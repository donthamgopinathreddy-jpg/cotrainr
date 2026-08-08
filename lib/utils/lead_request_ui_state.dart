/// UI state for provider connection-request notifications.
enum LeadRequestUiState {
  actionable,
  accepted,
  declined,
  cancelled,
  unknown,
}

LeadRequestUiState leadRequestUiStateFromStatus(String? status) {
  switch ((status ?? '').toLowerCase().trim()) {
    case 'requested':
      return LeadRequestUiState.actionable;
    case 'accepted':
      return LeadRequestUiState.accepted;
    case 'declined':
      return LeadRequestUiState.declined;
    case 'cancelled':
      return LeadRequestUiState.cancelled;
    default:
      return LeadRequestUiState.unknown;
  }
}

bool leadRequestShowsActions(LeadRequestUiState state) {
  return state == LeadRequestUiState.actionable;
}
