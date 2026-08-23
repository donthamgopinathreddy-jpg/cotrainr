import 'subscription_plans.dart';
import '../repositories/subscriptions_repository.dart';

/// UI states for the Member Pass "Your Plan" section.
/// Distinct from Cotrainr Pass identity (Pass ID / verification).
enum MemberPlanUiState {
  loading,
  free,
  active,
  trial,
  cancelledActive,
  expired,
  pastDue,
  pending,
  error,
}

/// Presentation model derived from [SubscriptionRow] — never invents plan data.
class MemberPlanView {
  final MemberPlanUiState state;
  final String planDisplayName;
  final String statusLabel;
  final String? detailLine;
  final String ctaLabel;

  const MemberPlanView({
    required this.state,
    required this.planDisplayName,
    required this.statusLabel,
    required this.ctaLabel,
    this.detailLine,
  });

  static const loading = MemberPlanView(
    state: MemberPlanUiState.loading,
    planDisplayName: '',
    statusLabel: '',
    ctaLabel: '',
  );

  static const error = MemberPlanView(
    state: MemberPlanUiState.error,
    planDisplayName: '',
    statusLabel: 'Unable to load plan',
    ctaLabel: 'Retry',
  );

  bool get isLoading => state == MemberPlanUiState.loading;
  bool get isError => state == MemberPlanUiState.error;
  bool get isPaidFeeling =>
      state == MemberPlanUiState.active ||
      state == MemberPlanUiState.trial ||
      state == MemberPlanUiState.cancelledActive;

  /// Maps canonical [SubscriptionRow] (or null = no row → Free).
  static MemberPlanView fromSubscription(SubscriptionRow? row) {
    if (row == null) {
      return const MemberPlanView(
        state: MemberPlanUiState.free,
        planDisplayName: 'Free',
        statusLabel: 'Current plan',
        ctaLabel: 'View plans',
      );
    }

    final planId = row.plan.toLowerCase().trim();
    final display = SubscriptionPlans.displayName(planId);
    final status = row.status.toLowerCase().trim();
    final expiredByDate =
        row.expiresAt != null && !row.expiresAt!.isAfter(DateTime.now());

    if (planId == SubscriptionPlans.free || planId.isEmpty) {
      return MemberPlanView(
        state: MemberPlanUiState.free,
        planDisplayName: display,
        statusLabel: 'Current plan',
        ctaLabel: 'View plans',
      );
    }

    if (expiredByDate || status == 'expired') {
      return MemberPlanView(
        state: MemberPlanUiState.expired,
        planDisplayName: display,
        statusLabel: 'Expired',
        detailLine: row.expiresAt != null
            ? 'Expired ${_formatDate(row.expiresAt!)}'
            : null,
        ctaLabel: 'Renew',
      );
    }

    if (status == 'past_due') {
      return MemberPlanView(
        state: MemberPlanUiState.pastDue,
        planDisplayName: display,
        statusLabel: 'Billing issue',
        detailLine: row.expiresAt != null
            ? 'Access until ${_formatDate(row.expiresAt!)}'
            : null,
        ctaLabel: 'Manage plan',
      );
    }

    if (status == 'pending' || status == 'incomplete') {
      return MemberPlanView(
        state: MemberPlanUiState.pending,
        planDisplayName: display,
        statusLabel: 'Pending',
        ctaLabel: 'Manage plan',
      );
    }

    if (status == 'cancelled' || status == 'canceled') {
      return MemberPlanView(
        state: MemberPlanUiState.cancelledActive,
        planDisplayName: display,
        statusLabel: 'Cancelled',
        detailLine: row.expiresAt != null
            ? 'Active until ${_formatDate(row.expiresAt!)}'
            : null,
        ctaLabel: 'Manage plan',
      );
    }

    if (status == 'trialing') {
      return MemberPlanView(
        state: MemberPlanUiState.trial,
        planDisplayName: display,
        statusLabel: 'Trial',
        detailLine: row.expiresAt != null
            ? 'Trial ends ${_formatDate(row.expiresAt!)}'
            : null,
        ctaLabel: 'Manage plan',
      );
    }

    if (status == 'active') {
      return MemberPlanView(
        state: MemberPlanUiState.active,
        planDisplayName: display,
        statusLabel: 'Active',
        detailLine: row.expiresAt != null
            ? 'Renews ${_formatDate(row.expiresAt!)}'
            : null,
        ctaLabel: 'Manage plan',
      );
    }

    // Unknown non-free status — show plan + raw status; do not invent Active.
    return MemberPlanView(
      state: MemberPlanUiState.active,
      planDisplayName: display,
      statusLabel: status.isEmpty ? 'Active' : _titleCase(status),
      detailLine: row.expiresAt != null
          ? 'Renews ${_formatDate(row.expiresAt!)}'
          : null,
      ctaLabel: 'Manage plan',
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
