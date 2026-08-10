/// Cotrainr Pass ID format helpers (CT + 8 digits).
library;

final RegExp cotrainrPassIdPattern = RegExp(r'^CT[0-9]{8}$');

bool isValidCotrainrPassId(String? value) {
  if (value == null) return false;
  return cotrainrPassIdPattern.hasMatch(value.trim());
}

String? normalizeCotrainrPassId(String? value) {
  final v = value?.trim();
  if (v == null || !isValidCotrainrPassId(v)) return null;
  return v;
}
