import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_role_service.dart';

final profileRoleServiceProvider = Provider<ProfileRoleService>((ref) {
  return ProfileRoleService();
});

class CurrentUserNotifier extends AsyncNotifier<CurrentUser?> {
  @override
  Future<CurrentUser?> build() async {
    final service = ref.read(profileRoleServiceProvider);
    final profile = await service.getCurrentUserProfile();
    
    if (profile == null) {
      await service.ensureProfileExists();
      final retry = await service.getCurrentUserProfile();
      if (retry == null) return null;
      return CurrentUser.fromJson(retry);
    }
    
    return CurrentUser.fromJson(profile);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(profileRoleServiceProvider);
      final profile = await service.getCurrentUserProfile();
      if (profile == null) return null;
      return CurrentUser.fromJson(profile);
    });
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, CurrentUser?>(() {
  return CurrentUserNotifier();
});

class CurrentUser {
  final String id;
  final String role;
  final String? fullName;
  final String? avatarUrl;
  final String? city;
  final String? bio;

  CurrentUser({
    required this.id,
    required this.role,
    this.fullName,
    this.avatarUrl,
    this.city,
    this.bio,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      bio: json['bio'] as String?,
    );
  }

  bool get isClient => role == 'client';
  bool get isTrainer => role == 'trainer';
  bool get isNutritionist => role == 'nutritionist';
  bool get isProvider => isTrainer || isNutritionist;
}
