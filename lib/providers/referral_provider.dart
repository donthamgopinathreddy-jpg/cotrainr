import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/referral_repository.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository();
});

final referralCodeProvider = FutureProvider<String?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  final repo = ref.read(referralRepositoryProvider);
  return repo.getOrCreateReferralCode();
});

final referralsCountProvider = FutureProvider<int>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return 0;
  final repo = ref.read(referralRepositoryProvider);
  return repo.getReferralsCount();
});

final referralRewardsXpProvider = FutureProvider<int>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return 0;
  final repo = ref.read(referralRepositoryProvider);
  return repo.getReferralRewardsXp();
});
