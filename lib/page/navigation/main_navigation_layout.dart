enum MainNavigationShortcut { follow, downloads }

enum MainNavigationPosition { left, right, more }

/// Content identity stays stable when the visible navigation order changes.
enum MainNavigationDestination { discover, bookshelf, follow, downloads, more }

class MainNavigationLayout {
  const MainNavigationLayout._(this.follow, this.downloads);

  static const defaults = MainNavigationLayout._(
    MainNavigationPosition.right,
    MainNavigationPosition.right,
  );

  factory MainNavigationLayout.decode(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return defaults;
    return MainNavigationLayout._(
      _decodePosition(parts.first),
      _decodePosition(parts.last),
    );
  }

  final MainNavigationPosition follow, downloads;

  String get encoded =>
      follow == defaults.follow && downloads == defaults.downloads
      ? ''
      : '${follow.name},${downloads.name}';

  MainNavigationPosition positionOf(MainNavigationShortcut shortcut) =>
      switch (shortcut) {
        MainNavigationShortcut.follow => follow,
        MainNavigationShortcut.downloads => downloads,
      };

  MainNavigationLayout withPosition(
    MainNavigationShortcut shortcut,
    MainNavigationPosition position,
  ) => switch (shortcut) {
    MainNavigationShortcut.follow => MainNavigationLayout._(
      position,
      downloads,
    ),
    MainNavigationShortcut.downloads => MainNavigationLayout._(
      follow,
      position,
    ),
  };

  List<MainNavigationDestination> get destinations => [
    MainNavigationDestination.discover,
    if (follow == MainNavigationPosition.left) MainNavigationDestination.follow,
    if (downloads == MainNavigationPosition.left)
      MainNavigationDestination.downloads,
    MainNavigationDestination.bookshelf,
    if (follow == MainNavigationPosition.right)
      MainNavigationDestination.follow,
    if (downloads == MainNavigationPosition.right)
      MainNavigationDestination.downloads,
    MainNavigationDestination.more,
  ];

  bool contains(MainNavigationDestination destination) => switch (destination) {
    MainNavigationDestination.follow => follow != MainNavigationPosition.more,
    MainNavigationDestination.downloads =>
      downloads != MainNavigationPosition.more,
    _ => true,
  };

  static MainNavigationPosition _decodePosition(String value) =>
      switch (value) {
        'left' => MainNavigationPosition.left,
        'more' => MainNavigationPosition.more,
        _ => MainNavigationPosition.right,
      };
}

String normalizeMainNavigationSlots(Object? value) =>
    MainNavigationLayout.decode(value is String ? value : '').encoded;
