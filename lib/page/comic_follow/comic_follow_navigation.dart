/// Main navigation supplies the actual route owner. Follow notices never keep
/// a BuildContext from a check or create another navigator/window themselves.
abstract final class ComicFollowNavigation {
  static Object? _owner;
  static Future<bool> Function()? _open;

  static void attach(Object owner, Future<bool> Function() open) {
    _owner = owner;
    _open = open;
  }

  static void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _open = null;
  }

  static Future<bool> open() async => await _open?.call() ?? false;
}
