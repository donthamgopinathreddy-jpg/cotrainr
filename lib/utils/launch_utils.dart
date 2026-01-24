import 'package:flutter/material.dart';
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

  static Future<void> sendEmail(
    BuildContext context, {
    required String to,
    String? subject,
    String? body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject,
        if (body != null && body.trim().isNotEmpty) 'body': body,
      },
    );
    await _launch(context, uri);
  }

  static Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open this link. Please try again.'),
            ),
          );
        }
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
          ),
        );
      }
    }
  }
}

