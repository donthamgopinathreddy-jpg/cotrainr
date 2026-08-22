/// Semantic version comparison (major.minor.patch), not lexicographic strings.
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  const SemanticVersion(this.major, this.minor, this.patch);

  static SemanticVersion? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final core = trimmed.split('+').first.split('-').first;
    final parts = core.split('.');
    if (parts.isEmpty) return null;
    final nums = <int>[];
    for (var i = 0; i < 3; i++) {
      if (i < parts.length) {
        final n = int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), ''));
        if (n == null) return null;
        nums.add(n);
      } else {
        nums.add(0);
      }
    }
    return SemanticVersion(nums[0], nums[1], nums[2]);
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool isLessThan(SemanticVersion other) => compareTo(other) < 0;
  bool isGreaterThan(SemanticVersion other) => compareTo(other) > 0;
  bool isEqualTo(SemanticVersion other) => compareTo(other) == 0;
}

enum VersionCheckOutcome {
  upToDate,
  optionalUpdate,
  requiredUpdate,
  failOpen,
}

VersionCheckOutcome compareInstalledToConfig({
  required String installedVersion,
  required String minimumVersion,
  required String recommendedVersion,
}) {
  final installed = SemanticVersion.parse(installedVersion);
  final minimum = SemanticVersion.parse(minimumVersion);
  final recommended = SemanticVersion.parse(recommendedVersion);
  if (installed == null || minimum == null || recommended == null) {
    return VersionCheckOutcome.failOpen;
  }
  if (installed.isGreaterThan(recommended)) {
    return VersionCheckOutcome.upToDate;
  }
  if (installed.isLessThan(minimum)) {
    return VersionCheckOutcome.requiredUpdate;
  }
  if (installed.isLessThan(recommended)) {
    return VersionCheckOutcome.optionalUpdate;
  }
  return VersionCheckOutcome.upToDate;
}
