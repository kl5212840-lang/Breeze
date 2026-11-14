class AppUpdateVersion implements Comparable<AppUpdateVersion> {
  const AppUpdateVersion._(this.major, this.minor, this.patch, this.isPreview);

  static final _pattern = RegExp(
    r'^[vV]?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
    r'(-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final int major;
  final int minor;
  final int patch;
  final bool isPreview;

  static AppUpdateVersion? parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;
    final major = int.tryParse(match[1]!);
    final minor = int.tryParse(match[2]!);
    final patch = int.tryParse(match[3]!);
    if (major == null || minor == null || patch == null) return null;
    return AppUpdateVersion._(major, minor, patch, match[4] != null);
  }

  @override
  int compareTo(AppUpdateVersion other) {
    final byMajor = major.compareTo(other.major);
    if (byMajor != 0) return byMajor;
    final byMinor = minor.compareTo(other.minor);
    if (byMinor != 0) return byMinor;
    final byPatch = patch.compareTo(other.patch);
    if (byPatch != 0) return byPatch;
    // Only stable releases are offered. The current app may be a preview.
    return (isPreview ? 0 : 1).compareTo(other.isPreview ? 0 : 1);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
