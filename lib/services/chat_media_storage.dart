import 'package:supabase_flutter/supabase_flutter.dart';

/// Private chat attachment storage. New uploads use [bucket]; historical
/// messages may still point at public `posts` URLs.
class ChatMediaStorage {
  ChatMediaStorage._();

  static const bucket = 'chat-attachments';
  static const storedPrefix = 'chat://';
  static const signedUrlTtlSeconds = 6 * 60 * 60;

  static bool isPrivateRef(String value) => value.startsWith(storedPrefix);

  static bool isLegacyPublicPostsUrl(String value) {
    return value.contains('/object/public/posts/') ||
        value.contains('/storage/v1/object/public/posts/');
  }

  static String storedRefForPath(String objectPath) =>
      '$storedPrefix$objectPath';

  static String? objectPathFromRef(String value) {
    if (!isPrivateRef(value)) return null;
    final path = value.substring(storedPrefix.length).trim();
    return path.isEmpty ? null : path;
  }

  static Future<String> resolveDisplayUrl(
    SupabaseClient client,
    String stored,
  ) async {
    final path = objectPathFromRef(stored);
    if (path == null) return stored;
    return client.storage.from(bucket).createSignedUrl(
          path,
          signedUrlTtlSeconds,
        );
  }

  static Future<Map<String, dynamic>> resolveMessageMedia(
    SupabaseClient client,
    Map<String, dynamic> message,
  ) async {
    final url = message['media_url'] as String?;
    if (url == null || url.isEmpty || !isPrivateRef(url)) return message;
    final display = await resolveDisplayUrl(client, url);
    return {...message, 'media_url': display};
  }
}
