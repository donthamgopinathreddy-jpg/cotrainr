import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LaunchUtils {
  static const String website = 'https://www.cotrainr.com';
  static const String supportEmail = 'support@cotrainr.com';
  static const String noReplyEmail = 'noreply@cotrainr.com';

  static Future<void> openWebsite(
    BuildContext context, {
    String? path,
  }) async {
    final uri = Uri.parse(website).replace(path: path ?? '/');
    await _launch(context, uri);
  }

  /// Opens an admin-provided Google Maps (or https) URL externally.
  /// Returns false if [url] is missing/invalid or launch fails.
  static Future<bool> openMapUrl(
    BuildContext context,
    String? url, {
    bool showFailure = true,
  }) async {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !(uri.isScheme('https') || uri.isScheme('http')) ||
        uri.host.isEmpty) {
      if (showFailure && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map link is unavailable.')),
        );
      }
      return false;
    }
    return _launch(context, uri, showGenericFailure: showFailure);
  }

  /// Opens the device mail composer. Returns `true` only if launch succeeded.
  /// Does not imply the email was sent or received.
  static Future<bool> sendEmail(
    BuildContext context, {
    required String to,
    String? subject,
    String? body,
    bool showFailureHelp = true,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject,
        if (body != null && body.trim().isNotEmpty) 'body': body,
      },
    );
    final ok = await _launch(context, uri, showGenericFailure: false);
    if (!ok && showFailureHelp && context.mounted) {
      await showEmailLaunchFailure(context, email: to);
    }
    return ok;
  }

  static Future<void> showEmailLaunchFailure(
    BuildContext context, {
    String email = supportEmail,
  }) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Couldn't open your email app. Contact $email",
        ),
        action: SnackBarAction(
          label: 'Copy email',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: email));
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  static Future<bool> _launch(
    BuildContext context,
    Uri uri, {
    bool showGenericFailure = true,
  }) async {
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        if (showGenericFailure && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open this link. Please try again.'),
            ),
          );
        }
        return false;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && showGenericFailure && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please try again.'),
          ),
        );
      }
      return ok;
    } catch (_) {
      if (showGenericFailure && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
          ),
        );
      }
      return false;
    }
  }
}
