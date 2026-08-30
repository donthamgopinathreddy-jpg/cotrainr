import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/user_role.dart';
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
      // Profile creation is server-owned; re-read instead of inserting a
      // client-authored role from auth metadata.
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

  /// Canonical role, or null when the stored value is not recognised.
  /// Unknown roles fail closed: no role-specific capability is granted.
  final UserRole? role;
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
      role: UserRoleParser.parse(json['role']),
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      bio: json['bio'] as String?,
    );
  }

  /// Canonical database string, or null when the role is unknown.
  String? get roleValue => role?.dbValue;

  bool get isClient => role == UserRole.client;
  bool get isTrainer => role == UserRole.trainer;
  bool get isNutritionist => role == UserRole.nutritionist;
  bool get isProvider => role?.isProvider ?? false;
}
