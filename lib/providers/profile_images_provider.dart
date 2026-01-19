import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileImagesState {
  final String? profileImagePath;
  final String? coverImagePath;

  ProfileImagesState({
    this.profileImagePath,
    this.coverImagePath,
  });

  ProfileImagesState copyWith({
    String? profileImagePath,
    String? coverImagePath,
  }) {
    return ProfileImagesState(
      profileImagePath: profileImagePath ?? this.profileImagePath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }
}

class ProfileImagesNotifier extends StateNotifier<ProfileImagesState> {
  ProfileImagesNotifier() : super(ProfileImagesState());

  void updateProfileImage(String? path) {
    state = state.copyWith(profileImagePath: path);
  }

  void updateCoverImage(String? path) {
    state = state.copyWith(coverImagePath: path);
  }
}

final profileImagesProvider =
    StateNotifierProvider<ProfileImagesNotifier, ProfileImagesState>(
  (ref) => ProfileImagesNotifier(),
);
