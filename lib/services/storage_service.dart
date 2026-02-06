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
      final fileName = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = 'avatars/$fileName';

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
      final fileName = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = 'covers/$fileName';

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
}
