import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Safe, user-provided support email composition for MVP mailto flows.
enum FeedbackType {
  suggestion('Suggestion'),
  improvement('Improvement'),
  other('Other');

  const FeedbackType(this.label);
  final String label;
}

class SupportDiagnostics {
  const SupportDiagnostics({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.os,
  });

  final String version;
  final String buildNumber;
  final String platform;
  final String os;

  static Future<SupportDiagnostics> load() async {
    String version = 'unknown';
    String build = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {}

    return SupportDiagnostics(
      version: version,
      buildNumber: build,
      platform: platformLabel(),
      os: osLabel(),
    );
  }

  static String platformLabel() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return Platform.operatingSystem;
  }

  static String osLabel() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'Unknown';
    }
  }

  String get appLine => 'App: Cotrainr $version ($buildNumber)';
}

abstract final class SupportEmailComposer {
  static String feedbackSubject({
    required FeedbackType type,
    String? subject,
  }) {
    final custom = subject?.trim() ?? '';
    if (custom.isEmpty) {
      return 'Cotrainr Feedback — ${type.label}';
    }
    return 'Cotrainr Feedback — ${type.label} — $custom';
  }

  static String feedbackBody({
    required FeedbackType type,
    required String message,
    required SupportDiagnostics diagnostics,
  }) {
    return [
      'Feedback type: ${type.label}',
      '',
      'Message:',
      message.trim(),
      '',
      '---',
      'Sent from Cotrainr',
      'App version: ${diagnostics.version}',
      'Platform: ${diagnostics.platform}',
    ].join('\n');
  }

  static const problemSubject = 'Cotrainr Problem Report';

  static String problemBody({
    required String problem,
    String? context,
    required SupportDiagnostics diagnostics,
  }) {
    final doing = (context ?? '').trim();
    return [
      'Problem:',
      problem.trim(),
      '',
      'What I was doing:',
      doing.isEmpty ? 'Not provided' : doing,
      '',
      '---',
      'Diagnostic information',
      diagnostics.appLine,
      'Platform: ${diagnostics.platform}',
      'OS: ${diagnostics.os}',
    ].join('\n');
  }

  static bool isNonEmptyText(String? value) =>
      value != null && value.trim().isNotEmpty;
}
