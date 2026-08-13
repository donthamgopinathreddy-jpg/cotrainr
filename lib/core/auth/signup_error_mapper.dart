import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_error_mapper.dart';

/// User-safe signup / complete-profile errors (never raw backend text).
class SignupErrorMapper {
  SignupErrorMapper._();

  static const usernameTaken = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'This User ID is already taken.',
    detail: 'Please choose another.',
  );

  static const invalidUsername = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'User ID must be 3–20 characters.',
    detail: 'Use letters, numbers, and underscore only.',
  );

  static const usernameCheckFailed = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Unable to check User ID right now.',
    detail: 'Try again.',
  );

  static const invalidEmail = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Please enter a valid email address.',
  );

  static const emailConflict = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'An account already exists with this email.',
    detail: 'Sign in instead',
  );

  static const passwordRejected = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Password does not meet requirements.',
  );

  static const passwordMismatch = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Passwords do not match.',
  );

  static const profileFailed = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Couldn’t create your profile.',
    detail: 'Please try again.',
  );

  static const providerFailed = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Couldn’t set up your provider account.',
    detail: 'Please try again.',
  );

  static const legalRequired = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Please agree to the Terms of Service and Privacy Policy.',
  );

  static const invalidRole = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Please choose a valid role.',
  );

  static const missingRequired = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Please complete all required onboarding fields.',
  );

  static AuthUserMessage map(Object error) {
    if (error is TimeoutException) return AuthErrorMapper.timeout;
    if (error is SocketException || error is HandshakeException) {
      return AuthErrorMapper.network;
    }

    final text = error.toString().toLowerCase();

    if (text.contains('username already exists') ||
        (text.contains('duplicate') && text.contains('username')) ||
        text.contains('user id is already taken')) {
      return usernameTaken;
    }
    if (text.contains('username must be') ||
        text.contains('alphanumeric and underscore')) {
      return invalidUsername;
    }
    if (text.contains('invalid role')) {
      return invalidRole;
    }
    if (text.contains('date of birth') ||
        text.contains('gender is required') ||
        text.contains('height is required') ||
        text.contains('weight is required') ||
        text.contains('fitness goal') ||
        text.contains('specialty is required') ||
        text.contains('missing required')) {
      return missingRequired;
    }
    if (text.contains('user already registered') ||
        text.contains('already been registered') ||
        text.contains('email address is already') ||
        text.contains('already registered')) {
      return emailConflict;
    }
    if (text.contains('password')) {
      return passwordRejected;
    }
    if (text.contains('legal acceptance') || text.contains('terms')) {
      return legalRequired;
    }
    if (text.contains('database error saving new user') ||
        text.contains('profile')) {
      return profileFailed;
    }
    if (text.contains('provider')) {
      return providerFailed;
    }
    if (text.contains('rate') || text.contains('too many')) {
      return AuthErrorMapper.rateLimited;
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('failed host lookup')) {
      return AuthErrorMapper.network;
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return AuthErrorMapper.timeout;
    }
    if (text.contains('503') ||
        text.contains('502') ||
        text.contains('unavailable')) {
      return AuthErrorMapper.serviceUnavailable;
    }

    if (error is AuthException) {
      return AuthErrorMapper.map(error);
    }

    return AuthErrorMapper.unknown;
  }
}
