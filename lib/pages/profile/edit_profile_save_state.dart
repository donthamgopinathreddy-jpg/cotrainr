/// Pure Save-gate rules for Edit Profile (testable without Supabase).
bool editProfileCanSave({
  required bool dirty,
  required bool valid,
  required bool saving,
}) =>
    dirty && valid && !saving;

bool editProfileFormLooksValid({
  required String firstName,
  required String lastName,
  required String email,
  required String phone,
  required String dob,
  required String heightRaw,
  required String weightRaw,
  required String goalWeight,
}) {
  if (firstName.trim().isEmpty) return false;
  if (lastName.trim().isEmpty) return false;
  final emailTrim = email.trim();
  if (emailTrim.isEmpty) return false;
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailTrim)) return false;
  final phoneTrim = phone.trim();
  if (phoneTrim.isNotEmpty && phoneTrim.length < 8) return false;
  if (dob.trim().isEmpty) return false;
  final parsedDob = DateTime.tryParse(dob.trim());
  if (parsedDob != null && parsedDob.isAfter(DateTime.now())) return false;
  final height = double.tryParse(heightRaw.trim());
  if (height == null || height <= 0) return false;
  final weight = double.tryParse(weightRaw.trim());
  if (weight == null || weight <= 0) return false;
  final goal = goalWeight.trim();
  if (goal.isNotEmpty) {
    final g = double.tryParse(goal);
    if (g == null || g <= 0) return false;
  }
  return true;
}
