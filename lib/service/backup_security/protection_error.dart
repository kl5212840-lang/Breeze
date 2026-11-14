/// Stable, non-sensitive codes; never include passwords, keys or native errors.
class BackupProtectionException implements Exception {
  const BackupProtectionException(this.code);
  final String code;

  @override
  String toString() => 'BackupProtectionException($code)';
}
