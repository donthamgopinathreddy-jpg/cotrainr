/// Client-side validation for event registration fields (not profile writes).
abstract final class EventRegistrationValidation {
  static String? nameError(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    return null;
  }

  static String? phoneError(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';
    final digits = v.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.replaceAll('+', '').length < 7) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? emailError(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  static String sanitizedRegistrationError(String? code) {
    return switch (code) {
      'full' => 'This event is full.',
      'deadline_passed' => 'Registration for this event has closed.',
      'registration_disabled' => 'Registration is not available.',
      'ended' => 'This event has ended.',
      'not_found' => 'Event not found.',
      'invalid_email' || 'validation' => 'Please check your details and try again.',
      'unauthorized' => 'Please sign in and try again.',
      'network' => 'Something went wrong. Please try again.',
      _ => 'Could not complete registration. Please try again.',
    };
  }
}
