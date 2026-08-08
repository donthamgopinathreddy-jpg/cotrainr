import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/utils/lead_request_ui_state.dart';

void main() {
  group('leadRequestUiStateFromStatus', () {
    test('maps requested to actionable', () {
      expect(
        leadRequestUiStateFromStatus('requested'),
        LeadRequestUiState.actionable,
      );
      expect(leadRequestShowsActions(LeadRequestUiState.actionable), isTrue);
    });

    test('maps resolved statuses', () {
      expect(
        leadRequestUiStateFromStatus('accepted'),
        LeadRequestUiState.accepted,
      );
      expect(
        leadRequestUiStateFromStatus('declined'),
        LeadRequestUiState.declined,
      );
      expect(
        leadRequestUiStateFromStatus('cancelled'),
        LeadRequestUiState.cancelled,
      );
      expect(leadRequestShowsActions(LeadRequestUiState.accepted), isFalse);
      expect(leadRequestShowsActions(LeadRequestUiState.declined), isFalse);
      expect(leadRequestShowsActions(LeadRequestUiState.cancelled), isFalse);
    });

    test('unknown for empty/null', () {
      expect(leadRequestUiStateFromStatus(null), LeadRequestUiState.unknown);
      expect(leadRequestUiStateFromStatus(''), LeadRequestUiState.unknown);
      expect(leadRequestShowsActions(LeadRequestUiState.unknown), isFalse);
    });
  });
}
