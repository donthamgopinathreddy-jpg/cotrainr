import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cotrainr/core/startup/startup_failure.dart';
import 'package:cotrainr/core/startup/startup_state.dart';
import 'package:cotrainr/providers/startup_bootstrap_provider.dart';

void main() {
  group('StartupState (legacy helpers still compile)', () {
    test('authenticated client has home destination', () {
      const state = StartupState(
        phase: StartupPhase.authenticated,
        role: 'client',
        userId: 'u1',
        destination: '/home',
        onboardingComplete: true,
      );
      expect(state.hasResolvedRole, isTrue);
      final user = currentUserFromStartup(state);
      expect(user?.isClient, isTrue);
    });

    test('unknown role is not resolved', () {
      const state = StartupState(
        phase: StartupPhase.authenticated,
        role: 'partner_owner',
        destination: '/home',
      );
      expect(state.hasResolvedRole, isFalse);
    });
  });

  group('classifyStartupFailure', () {
    test('socket and timeout are network', () {
      expect(
        classifyStartupFailure(const SocketException('fail')),
        StartupFailureKind.network,
      );
      expect(
        classifyStartupFailure(TimeoutException('slow')),
        StartupFailureKind.network,
      );
    });

    test('refresh token messages are authInvalid', () {
      expect(
        classifyStartupFailure(
          Exception('AuthApiException: Invalid Refresh Token'),
        ),
        StartupFailureKind.authInvalid,
      );
    });
  });
}
