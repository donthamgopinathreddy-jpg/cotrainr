import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/startup/go_router_auth_refresh.dart';
import '../core/startup/network_probe.dart';
import '../core/startup/startup_failure.dart';
import '../core/startup/startup_profile_cache.dart';
import '../core/startup/startup_router_bridge.dart';
import '../core/startup/startup_state.dart';
import '../core/startup/supabase_bootstrap.dart';
import '../repositories/verification_repository.dart';
import '../router/app_router.dart';
import 'profile_role_provider.dart';

/// Minimum brand time on the Flutter splash (not a forced 3.5s wait).
const kSplashMinDisplay = Duration(milliseconds: 1000);

/// Show slow-network copy after this elapsed bootstrap time.
const kSplashSlowHintAfter = Duration(seconds: 3);

/// Hard timeout for profile / refresh network work during bootstrap.
const kStartupNetworkTimeout = Duration(seconds: 15);

final startupBootstrapProvider =
    StateNotifierProvider<StartupBootstrapNotifier, StartupState>((ref) {
  return StartupBootstrapNotifier(ref);
});

class StartupBootstrapNotifier extends StateNotifier<StartupState> {
  StartupBootstrapNotifier(this._ref) : super(StartupState.initial) {
    unawaited(bootstrap());
  }

  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;
  Timer? _slowHintTimer;
  DateTime? _bootstrapStartedAt;
  bool _bootstrapping = false;
  int _generation = 0;
  bool _skipMinDisplay = false;

  /// Pending deep-link destination that must survive splash routing.
  String? _pendingDeepLinkRoute;

  void setPendingDeepLinkRoute(String? route) {
    _pendingDeepLinkRoute = route;
    StartupRouterBridge.setPendingDeepLinkRoute(route);
  }

  String? get pendingDeepLinkRoute => _pendingDeepLinkRoute;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  void _emit(StartupState next) {
    if (!mounted) return;
    state = next;
    StartupRouterBridge.update(next);
    _log(
      '[STARTUP] emit phase=${next.phase.name} '
      'role=${next.role ?? '-'} '
      'onboarding=${next.onboardingComplete} '
      'destination=${next.destination} '
      'retrying=${next.retrying}',
    );
    goRouterAuthRefresh.notifyStartupChanged();
    _log('[ROUTER] refresh notified');
  }

  Future<void> bootstrap({
    bool isRetry = false,
    bool skipMinDisplay = false,
  }) async {
    if (_bootstrapping) {
      _log(
        '[STARTUP] bootstrap skipped (already running) '
        'skipMinDisplay=$skipMinDisplay isRetry=$isRetry',
      );
      return;
    }
    _bootstrapping = true;
    final gen = ++_generation;
    _skipMinDisplay = skipMinDisplay;
    _log(
      '[STARTUP] bootstrap started gen=$gen '
      'skipMinDisplay=$skipMinDisplay isRetry=$isRetry',
    );

    _slowHintTimer?.cancel();
    _bootstrapStartedAt = DateTime.now();

    _emit(StartupState(
      phase: StartupPhase.initializing,
      retrying: isRetry,
      showSlowHint: false,
    ));

    _slowHintTimer = Timer(kSplashSlowHintAfter, () {
      if (!mounted || gen != _generation) return;
      if (state.phase == StartupPhase.initializing) {
        _emit(state.copyWith(showSlowHint: true));
      }
    });

    try {
      final ok = await SupabaseBootstrap.ensureInitialized();
      if (!mounted || gen != _generation) return;
      if (!ok) {
        await _waitMinDisplay();
        if (!mounted || gen != _generation) return;
        _emit(const StartupState(
          phase: StartupPhase.error,
          message:
              'Couldn’t start Cotrainr. Check your connection and try again.',
        ));
        return;
      }

      _ensureAuthListener();
      goRouterAuthRefresh.bindAuthIfReady();

      // Warm local prefs (also used by profile cache).
      await SharedPreferences.getInstance();

      final client = Supabase.instance.client;
      var session = client.auth.currentSession;
      _log(
        '[STARTUP] session available=${session != null} '
        'userId=${session?.user.id ?? '-'}',
      );

      if (session != null && session.isExpired) {
        try {
          final refreshed = await client.auth
              .refreshSession()
              .timeout(kStartupNetworkTimeout);
          session = refreshed.session ?? client.auth.currentSession;
        } catch (e) {
          final kind = classifyStartupFailure(e);
          if (kind == StartupFailureKind.authInvalid) {
            await _clearInvalidSession();
            await _waitMinDisplay();
            if (!mounted || gen != _generation) return;
            _emit(const StartupState(
              phase: StartupPhase.unauthenticated,
              destination: '/welcome',
            ));
            return;
          }
          // Network/server: keep persisted session and continue with cache.
          session = client.auth.currentSession;
          if (session == null) {
            await _waitMinDisplay();
            if (!mounted || gen != _generation) return;
            _emit(StartupState(
              phase: kind == StartupFailureKind.network
                  ? StartupPhase.offline
                  : StartupPhase.error,
              message: kind == StartupFailureKind.network
                  ? 'You’re offline. We couldn’t finish loading your account.'
                  : 'Couldn’t connect. Check your connection and try again.',
            ));
            return;
          }
        }
      }

      if (session == null) {
        await StartupProfileCache.clear();
        final deep = _pendingDeepLinkRoute;
        // Fresh install / logged-out with no network → intentional offline UI.
        if (deep == null) {
          final online = await probeNetworkReachability();
          if (!mounted || gen != _generation) return;
          if (!online) {
            await _waitMinDisplay();
            if (!mounted || gen != _generation) return;
            _emit(const StartupState(
              phase: StartupPhase.offline,
              message:
                  'No internet connection. Connect to the internet to finish setting up Cotrainr.',
            ));
            return;
          }
        }
        await _waitMinDisplay();
        if (!mounted || gen != _generation) return;
        _emit(StartupState(
          phase: StartupPhase.unauthenticated,
          destination: deep ?? '/welcome',
        ));
        return;
      }

      await _resolveAuthenticatedUser(
        session: session,
        generation: gen,
      );
    } catch (e, st) {
      _log('[STARTUP] failed type=${e.runtimeType}');
      debugPrint('[StartupBootstrap] failed: $e\n$st');
      if (!mounted || gen != _generation) return;
      await _waitMinDisplay();
      if (!mounted || gen != _generation) return;
      final kind = classifyStartupFailure(e);
      _emit(StartupState(
        phase: kind == StartupFailureKind.network
            ? StartupPhase.offline
            : StartupPhase.error,
        message: kind == StartupFailureKind.network
            ? 'No internet connection. Connect to the internet to finish setting up Cotrainr.'
            : 'Couldn’t start Cotrainr. Check your connection and try again.',
      ));
    } finally {
      if (gen == _generation) {
        _bootstrapping = false;
        _slowHintTimer?.cancel();
        // Never leave animated splash / Login in endless initializing.
        if (mounted && state.phase == StartupPhase.initializing) {
          _log('[STARTUP] safety net: still initializing → error');
          _emit(const StartupState(
            phase: StartupPhase.error,
            message:
                'Couldn’t finish loading your account. Check your connection and try again.',
          ));
        }
      }
    }
  }

  Future<void> retry() async {
    if (state.retrying || _bootstrapping) return;
    setPendingDeepLinkRoute(null);
    await bootstrap(isRetry: true);
  }

  Future<void> _resolveAuthenticatedUser({
    required Session session,
    required int generation,
  }) async {
    final userId = session.user.id;
    final service = _ref.read(profileRoleServiceProvider);
    Object? profileError;
    Map<String, dynamic>? profile;

    _log('[STARTUP] requesting profile');
    try {
      profile = await service
          .getCurrentUserProfile()
          .timeout(kStartupNetworkTimeout);
      if (profile == null) {
        _log('[STARTUP] profile null — ensureProfileExists');
        await service
            .ensureProfileExists()
            .timeout(kStartupNetworkTimeout);
        profile = await service
            .getCurrentUserProfile()
            .timeout(kStartupNetworkTimeout);
      }
    } catch (e) {
      profileError = e;
      profile = null;
      _log(
        '[STARTUP] profile request failed type=${e.runtimeType} '
        'kind=${classifyStartupFailure(e).name}',
      );
    }

    if (!mounted || generation != _generation) return;

    if (profile != null) {
      _log('[STARTUP] profile received');
    } else {
      _log('[STARTUP] profile missing after request');
    }

    if (profileError != null &&
        classifyStartupFailure(profileError) ==
            StartupFailureKind.authInvalid) {
      await _clearInvalidSession();
      await _waitMinDisplay();
      if (!mounted || generation != _generation) return;
      _emit(const StartupState(
        phase: StartupPhase.unauthenticated,
        destination: '/welcome',
      ));
      return;
    }

    String? role;
    String? fullName;
    String? avatarUrl;
    var fromCache = false;
    var offlineBanner = false;
    var onboardingComplete = true;

    if (profile != null) {
      role = (profile['role'] as String?)?.toLowerCase();
      fullName = profile['full_name'] as String?;
      avatarUrl = profile['avatar_url'] as String?;
      if (role != null && role.isNotEmpty) {
        await StartupProfileCache.save(
          userId: userId,
          role: role,
          fullName: fullName,
          avatarUrl: avatarUrl,
        );
      }

      if (role == 'trainer' || role == 'nutritionist') {
        onboardingComplete = await _providerOnboardingComplete();
        _log(
          '[STARTUP] provider onboardingComplete=$onboardingComplete',
        );
      }
    } else {
      final cached = await StartupProfileCache.read(userId);
      final metaRole =
          session.user.userMetadata?['role']?.toString().toLowerCase();
      if (cached != null) {
        role = cached.role;
        fullName = cached.fullName;
        avatarUrl = cached.avatarUrl;
        fromCache = true;
        offlineBanner = profileError != null &&
            classifyStartupFailure(profileError) ==
                StartupFailureKind.network;
        // Offline: do not force verification gate without live status.
        onboardingComplete = true;
        _log('[STARTUP] using cached role=$role');
      } else if (metaRole == 'client' ||
          metaRole == 'trainer' ||
          metaRole == 'nutritionist') {
        role = metaRole;
        fromCache = true;
        offlineBanner = true;
        onboardingComplete = true;
        _log('[STARTUP] using metadata role=$role');
      } else {
        await _waitMinDisplay();
        if (!mounted || generation != _generation) return;
        final isNet = profileError != null &&
            classifyStartupFailure(profileError) ==
                StartupFailureKind.network;
        _emit(StartupState(
          phase: isNet ? StartupPhase.offline : StartupPhase.error,
          message: isNet
              ? 'You’re offline. We couldn’t finish loading your account.'
              : 'Couldn’t finish loading your account. Try again.',
        ));
        return;
      }
    }

    _log('[STARTUP] role=${role ?? '-'}');

    if (role == null ||
        (role != 'client' && role != 'trainer' && role != 'nutritionist')) {
      await _waitMinDisplay();
      if (!mounted || generation != _generation) return;
      _emit(const StartupState(
        phase: StartupPhase.error,
        message: 'Couldn’t load your account. Try again.',
      ));
      return;
    }

    final deep = _pendingDeepLinkRoute;
    final destination = deep ??
        (!onboardingComplete
            ? '/verification'
            : '/home');
    _log('[STARTUP] destination=$destination');

    await _waitMinDisplay();
    if (!mounted || generation != _generation) return;

    _emit(StartupState(
      phase: StartupPhase.authenticated,
      role: role,
      userId: userId,
      fullName: fullName,
      avatarUrl: avatarUrl,
      destination: destination,
      onboardingComplete: onboardingComplete,
      fromCache: fromCache,
      showOfflineBanner: offlineBanner,
    ));

    // Seed / refresh in-memory profile provider without blocking route.
    unawaited(_ref.read(currentUserProvider.notifier).refresh());
  }

  Future<bool> _providerOnboardingComplete() async {
    try {
      final status = await VerificationRepository()
          .getProviderVerificationStatus()
          .timeout(kStartupNetworkTimeout);
      // Existing SoT: notSubmitted means continue at /verification.
      return status != ProviderVerificationStatus.notSubmitted;
    } catch (e) {
      // Network failure while online path partially worked: don't block home
      // with a false incomplete flag; prefer home + soft profile CTA.
      if (classifyStartupFailure(e) == StartupFailureKind.network) {
        return true;
      }
      return true;
    }
  }

  void _ensureAuthListener() {
    if (_authSub != null) return;
    if (!SupabaseBootstrap.isInitialized) return;
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final event = authState.event;
      _log(
        '[AUTH] ${event.name} '
        'hasSession=${authState.session != null}',
      );
      if (event == AuthChangeEvent.signedOut) {
        unawaited(StartupProfileCache.clear());
        if (!mounted) return;
        // Don't interrupt an in-flight bootstrap retry with a flicker.
        if (_bootstrapping) return;
        _emit(const StartupState(
          phase: StartupPhase.unauthenticated,
          destination: '/welcome',
        ));
        return;
      }
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.userUpdated ||
          event == AuthChangeEvent.passwordRecovery) {
        // Re-resolve after OAuth / recovery. tokenRefreshed alone must not
        // re-run full cold-start bootstrap (avoids splash loops on resume).
        if (_bootstrapping) {
          _log('[AUTH] bootstrap already running — skip re-entry');
          return;
        }
        if (event == AuthChangeEvent.passwordRecovery) {
          setPendingDeepLinkRoute('/auth/reset-password');
          // Recovery sessions must never fall through splash → /auth/continue.
          appRouter.go('/auth/reset-password');
        }
        unawaited(bootstrap(skipMinDisplay: true));
      }
    });
  }

  Future<void> _clearInvalidSession() async {
    try {
      await StartupProfileCache.clear();
      if (SupabaseBootstrap.isInitialized) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}
  }

  Future<void> _waitMinDisplay() async {
    if (_skipMinDisplay) return;
    final started = _bootstrapStartedAt;
    if (started == null) return;
    final elapsed = DateTime.now().difference(started);
    if (elapsed < kSplashMinDisplay) {
      await Future<void>.delayed(kSplashMinDisplay - elapsed);
    }
  }

  @override
  void dispose() {
    _slowHintTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

/// Convenience: CurrentUser-shaped view from bootstrap when available.
CurrentUser? currentUserFromStartup(StartupState state) {
  if (state.phase != StartupPhase.authenticated) return null;
  if (state.userId == null || state.role == null) return null;
  return CurrentUser(
    id: state.userId!,
    role: state.role!,
    fullName: state.fullName,
    avatarUrl: state.avatarUrl,
  );
}
