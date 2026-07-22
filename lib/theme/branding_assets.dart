/// Bundled local branding assets. Startup splash must never depend on network.
class BrandingAssets {
  BrandingAssets._();

  // --- Vector masters (always prefer these for logo / decor) ---
  static const String logoSvg = 'assets/branding/vector/cotrainr_logo.svg';
  static const String logoWhiteSvg =
      'assets/branding/vector/cotrainr_logo_white.svg';
  static const String orangeSmokeSvg =
      'assets/branding/vector/orange_smoke.svg';
  static const String orangeParticlesSvg =
      'assets/branding/vector/orange_particles.svg';
  static const String orangeGradientSvg =
      'assets/branding/vector/orange_gradient.svg';
  static const String orangeOverlaysSvg =
      'assets/branding/vector/orange_overlays.svg';
  static const String lightGlowSvg = 'assets/branding/vector/light_glow.svg';
  static const String abstractLinesSvg =
      'assets/branding/vector/abstract_lines.svg';
  static const String cornerOverlaySvg =
      'assets/branding/vector/corner_overlay.svg';

  // --- Photographic / raster ---
  static const String logoBlackFull =
      'assets/branding/cotrainr_logo_black_full.png';
  static const String runnerAthlete =
      'assets/branding/cotrainr_runner_athlete.png';
  static const String runnerSplash =
      'assets/branding/cotrainr_runner_splash_clean.png';
  static const String runnerSplashOriginal =
      'assets/branding/cotrainr_runner_splash.png';
  static const String orangeFullLogo =
      'assets/branding/cotrainr_orange_full_logo.png';
  static const String welcomeLogoWhite =
      'assets/branding/cotrainr_welcome_logo_white.png';
  static const String nativeSplashLogo =
      'assets/branding/cotrainr_native_splash_logo.png';
  static const String loginHeaderLogo =
      'assets/branding/cotrainr_login_header_logo.png';
  static const String registerHeaderLogo =
      'assets/branding/cotrainr_register_header_logo.png';
  static const String authBackground =
      'assets/branding/cotrainr_auth_background.png';

  static const String appIcon1024 =
      'assets/branding/icons/cotrainr_app_icon_1024.png';
  static const String appIconForeground =
      'assets/branding/icons/cotrainr_symbol_foreground.png';

  // Legacy aliases
  static const String logo = appIcon1024;
  static const String logoWhite = 'assets/branding/cotrainr_logo_white.png';
  static const String wordmark = 'assets/branding/cotrainr_wordmark.png';
  static const String splashRunner = runnerAthlete;
  static const String appIcon = 'assets/branding/cotrainr_app_icon.png';
  static const String splashLockup = logoBlackFull;
  static const String welcomeFull = orangeFullLogo;
}
