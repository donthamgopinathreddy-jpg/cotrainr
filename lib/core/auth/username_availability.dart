/// User ID format + availability state. RPC/DB remain the authority.
enum UsernameAvailabilityStatus {
  empty,
  invalid,
  checking,
  available,
  taken,
  error,
}

abstract final class UsernameAvailability {
  static final format = RegExp(r'^[A-Za-z0-9_]{3,20}$');

  /// Trim, then strip a single leading `@` if present.
  static String normalize(String raw) {
    var value = raw.trim();
    if (value.startsWith('@')) {
      value = value.substring(1).trim();
    }
    return value;
  }

  static bool isValidFormat(String normalized) => format.hasMatch(normalized);

  static UsernameAvailabilityStatus statusFor({
    required String raw, required UsernameAvailabilityStatus? remote,
  }) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) return UsernameAvailabilityStatus.empty;
    if (!isValidFormat(normalized)) return UsernameAvailabilityStatus.invalid;
    return remote ?? UsernameAvailabilityStatus.checking;
  }

  static String? helperText(UsernameAvailabilityStatus status) {
    return switch (status) {
      UsernameAvailabilityStatus.empty => null,
      UsernameAvailabilityStatus.invalid =>
        'Use 3–20 letters, numbers or underscores.',
      UsernameAvailabilityStatus.checking => 'Checking User ID…',
      UsernameAvailabilityStatus.available => '✓ User ID available',
      UsernameAvailabilityStatus.taken => 'That User ID is already taken.',
      UsernameAvailabilityStatus.error =>
        'Unable to check User ID right now. Try again.',
    };
  }

  /// Fail closed: only `true` from the RPC counts as available.
  static UsernameAvailabilityStatus fromRpc(Object? result) {
    if (result == true) return UsernameAvailabilityStatus.available;
    if (result == false) return UsernameAvailabilityStatus.taken;
    return UsernameAvailabilityStatus.error;
  }

  static bool canAdvance(UsernameAvailabilityStatus status) =>
      status == UsernameAvailabilityStatus.available;
}
