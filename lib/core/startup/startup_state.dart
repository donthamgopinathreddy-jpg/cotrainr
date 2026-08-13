/// Explicit cold-start / bootstrap phases for Cotrainr.
enum StartupPhase {
  /// Supabase + session + profile resolution in progress.
  initializing,

  /// No recoverable session.
  unauthenticated,

  /// Session + role resolved (online or safe offline cache).
  authenticated,

  /// Cannot proceed: no session and no network, or session without safe role.
  offline,

  /// Recoverable startup failure (init / server).
  error,
}

/// Resolved bootstrap snapshot used by splash UI and GoRouter.
class StartupState {
  const StartupState({
    required this.phase,
    this.role,
    this.userId,
    this.fullName,
    this.avatarUrl,
    this.destination = '/welcome',
    this.onboardingComplete = true,
    this.fromCache = false,
    this.showOfflineBanner = false,
    this.showSlowHint = false,
    this.message,
    this.retrying = false,
  });

  final StartupPhase phase;

  /// client | trainer | nutritionist when known.
  final String? role;
  final String? userId;
  final String? fullName;
  final String? avatarUrl;

  /// Authoritative next route after splash (e.g. /welcome, /home, /verification).
  final String destination;

  /// Providers with [ProviderVerificationStatus.notSubmitted] are incomplete.
  final bool onboardingComplete;

  final bool fromCache;
  final bool showOfflineBanner;
  final bool showSlowHint;
  final String? message;
  final bool retrying;

  bool get isReadyToRoute =>
      phase == StartupPhase.authenticated ||
      phase == StartupPhase.unauthenticated;

  bool get blocksAppEntry =>
      phase == StartupPhase.initializing ||
      phase == StartupPhase.offline ||
      phase == StartupPhase.error;

  bool get hasResolvedRole =>
      role == 'client' || role == 'trainer' || role == 'nutritionist';

  StartupState copyWith({
    StartupPhase? phase,
    String? role,
    String? userId,
    String? fullName,
    String? avatarUrl,
    String? destination,
    bool? onboardingComplete,
    bool? fromCache,
    bool? showOfflineBanner,
    bool? showSlowHint,
    String? message,
    bool? retrying,
    bool clearMessage = false,
  }) {
    return StartupState(
      phase: phase ?? this.phase,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      destination: destination ?? this.destination,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      fromCache: fromCache ?? this.fromCache,
      showOfflineBanner: showOfflineBanner ?? this.showOfflineBanner,
      showSlowHint: showSlowHint ?? this.showSlowHint,
      message: clearMessage ? null : (message ?? this.message),
      retrying: retrying ?? this.retrying,
    );
  }

  static const initial = StartupState(phase: StartupPhase.initializing);
}
