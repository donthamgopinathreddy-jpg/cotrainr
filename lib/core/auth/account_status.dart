/// Moderation state of a Cotrainr account.
///
/// Mirrors `public.profiles.account_status` (`active` | `suspended` | `banned`)
/// and the server-side `public.effective_account_status(uuid)` semantics: an
/// expired suspension counts as active.
enum AccountStatus {
  active,
  suspended,
  banned;

  bool get isRestricted => this != active;
}

class AccountRestriction {
  const AccountRestriction({
    required this.status,
    this.suspendedUntil,
  });

  final AccountStatus status;
  final DateTime? suspendedUntil;

  bool get isRestricted => status.isRestricted;

  /// Copy shown to the user. Deliberately omits internal moderation notes.
  String get title => switch (status) {
        AccountStatus.banned => 'Account closed',
        AccountStatus.suspended => 'Account temporarily restricted',
        AccountStatus.active => '',
      };

  String get message => switch (status) {
        AccountStatus.banned =>
          'This account no longer has access to Cotrainr. If you think this is a '
              'mistake, contact support.',
        AccountStatus.suspended => suspendedUntil == null
            ? 'Your account is temporarily restricted. Contact support if you '
                'need help.'
            : 'Your account is temporarily restricted until '
                '${_formatDate(suspendedUntil!)}. Contact support if you need help.',
        AccountStatus.active => '',
      };

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

abstract final class AccountStatusParser {
  /// Resolves the effective restriction from a `get_my_profile` row.
  ///
  /// A missing/unknown value is treated as active: `account_status` is NOT NULL
  /// with default `active` server-side, and this must never lock out a user
  /// because of an unexpected string.
  static AccountRestriction fromProfile(Map<String, dynamic>? profile) {
    if (profile == null) {
      return const AccountRestriction(status: AccountStatus.active);
    }
    final raw = profile['account_status']?.toString().trim().toLowerCase();
    final until = _parseDate(profile['suspended_until']);

    switch (raw) {
      case 'banned':
        return AccountRestriction(
          status: AccountStatus.banned,
          suspendedUntil: until,
        );
      case 'suspended':
        // Expired suspension = active (matches effective_account_status).
        if (until != null && !until.isAfter(DateTime.now().toUtc())) {
          return const AccountRestriction(status: AccountStatus.active);
        }
        return AccountRestriction(
          status: AccountStatus.suspended,
          suspendedUntil: until,
        );
      default:
        return const AccountRestriction(status: AccountStatus.active);
    }
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}
