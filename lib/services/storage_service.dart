import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

/// Service for uploading files to Supabase Storage
class StorageService {
  final SupabaseClient _supabase;

  StorageService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Upload avatar image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String?> uploadAvatar(File imageFile) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Generate unique filename
      final extension = path.extension(imageFile.path);
      // Store in user-specific folder: {userId}/avatar.{ext}
      final filePath = '$_currentUserId/avatar$extension';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage using uploadBinary for bytes
      await _supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(
          upsert: true, // Replace if exists
          contentType: 'image/jpeg',
        ),
      );

      // Get public URL
      final url = _supabase.storage.from('avatars').getPublicUrl(filePath);
      return url;
    } catch (e) {
      print('Error uploading avatar: $e');
      rethrow;
    }
  }

  /// Upload cover image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String?> uploadCoverImage(File imageFile) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Generate unique filename
      final extension = path.extension(imageFile.path);
      // Store in user-specific folder: {userId}/cover.{ext}
      final filePath = '$_currentUserId/cover$extension';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage using uploadBinary for bytes
      await _supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(
          upsert: true, // Replace if exists
          contentType: 'image/jpeg',
        ),
      );

      // Get public URL
      final url = _supabase.storage.from('avatars').getPublicUrl(filePath);
      return url;
    } catch (e) {
      print('Error uploading cover image: $e');
      rethrow;
    }
  }

  /// Delete old avatar if exists
  Future<void> deleteOldAvatar(String? oldUrl) async {
    if (oldUrl == null || oldUrl.isEmpty) return;

    try {
      // Extract file path from URL
      final uri = Uri.parse(oldUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 3) {
        // Format: /storage/v1/object/public/bucket/path
        final bucket = pathSegments[2];
        final filePath = pathSegments.sublist(3).join('/');
        
        await _supabase.storage.from(bucket).remove([filePath]);
      }
    } catch (e) {
      print('Error deleting old avatar: $e');
      // Don't throw - deletion is best effort
    }
  }

  /// Delete old cover image if exists
  Future<void> deleteOldCoverImage(String? oldUrl) async {
    if (oldUrl == null || oldUrl.isEmpty) return;

    try {
      // Extract file path from URL
      final uri = Uri.parse(oldUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 3) {
        // Format: /storage/v1/object/public/bucket/path
        final bucket = pathSegments[2];
        final filePath = pathSegments.sublist(3).join('/');
        
        await _supabase.storage.from(bucket).remove([filePath]);
      }
    } catch (e) {
      print('Error deleting old cover image: $e');
      // Don't throw - deletion is best effort
    }
  }

  /// Upload post media (image or video) to Supabase Storage
  /// Returns the public URL of the uploaded media
  Future<String?> uploadPostMedia(File mediaFile, {required bool isVideo}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Generate unique filename
      final extension = path.extension(mediaFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      // Store in user-specific folder: {userId}/{timestamp}.{ext}
      final filePath = '$_currentUserId/$fileName';

      // Read file bytes
      final bytes = await mediaFile.readAsBytes();

      // Determine content type
      final contentType = isVideo ? 'video/mp4' : 'image/jpeg';

      // Upload to Supabase Storage
      // Use 'posts' bucket (you may need to create this bucket in Supabase)
      await _supabase.storage.from('posts').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
        ),
      );

      // Get public URL
      final url = _supabase.storage.from('posts').getPublicUrl(filePath);
      return url;
    } catch (e) {
      print('Error uploading post media: $e');
      rethrow;
    }
  }
}
