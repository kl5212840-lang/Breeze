/// Stable destination codes for the reordered modern tab bar.
///
/// Older releases persisted tab indexes directly. Codes 10–12 distinguish a
/// choice made in the new order from those older values without rewriting a
/// user's settings during startup.
enum WelcomePageDestination {
  discover,
  bookshelf,
  more,
  downloads,
  oldHome,
  oldRanking,
}

WelcomePageDestination resolveWelcomePageDestination(
  int storedValue, {
  required bool oldPageRollbackEnabled,
}) {
  if (oldPageRollbackEnabled) {
    return switch (storedValue) {
      0 => WelcomePageDestination.oldHome,
      1 => WelcomePageDestination.oldRanking,
      2 || 11 => WelcomePageDestination.bookshelf,
      3 || 10 => WelcomePageDestination.discover,
      4 || 12 => WelcomePageDestination.more,
      13 => WelcomePageDestination.downloads,
      _ => WelcomePageDestination.oldHome,
    };
  }
  return switch (storedValue) {
    11 => WelcomePageDestination.bookshelf,
    2 || 12 => WelcomePageDestination.more,
    13 => WelcomePageDestination.downloads,
    // 0 was the old default bookshelf. Make that default Discover now;
    // old explicit Discover (1) remains Discover as well.
    _ => WelcomePageDestination.discover,
  };
}

int welcomePageTabIndex(
  WelcomePageDestination destination, {
  required bool oldPageRollbackEnabled,
}) {
  if (oldPageRollbackEnabled) {
    return switch (destination) {
      WelcomePageDestination.oldHome => 0,
      WelcomePageDestination.oldRanking => 1,
      WelcomePageDestination.bookshelf => 2,
      WelcomePageDestination.discover => 3,
      WelcomePageDestination.downloads => 4,
      WelcomePageDestination.more => 5,
    };
  }
  return switch (destination) {
    WelcomePageDestination.discover ||
    WelcomePageDestination.oldHome ||
    WelcomePageDestination.oldRanking => 0,
    WelcomePageDestination.bookshelf => 1,
    WelcomePageDestination.downloads => 2,
    WelcomePageDestination.more => 3,
  };
}

WelcomePageDestination destinationForTabIndex(
  int index, {
  required bool oldPageRollbackEnabled,
}) {
  if (oldPageRollbackEnabled) {
    return switch (index) {
      0 => WelcomePageDestination.oldHome,
      1 => WelcomePageDestination.oldRanking,
      2 => WelcomePageDestination.bookshelf,
      3 => WelcomePageDestination.discover,
      4 => WelcomePageDestination.downloads,
      5 => WelcomePageDestination.more,
      _ => WelcomePageDestination.oldHome,
    };
  }
  return switch (index) {
    1 => WelcomePageDestination.bookshelf,
    2 => WelcomePageDestination.downloads,
    3 => WelcomePageDestination.more,
    _ => WelcomePageDestination.discover,
  };
}

int storedWelcomePageValue(
  WelcomePageDestination destination, {
  required bool oldPageRollbackEnabled,
}) {
  if (oldPageRollbackEnabled) {
    return switch (destination) {
      WelcomePageDestination.oldHome => 0,
      WelcomePageDestination.oldRanking => 1,
      WelcomePageDestination.bookshelf => 2,
      WelcomePageDestination.discover => 3,
      WelcomePageDestination.more => 4,
      WelcomePageDestination.downloads => 13,
    };
  }
  return switch (destination) {
    WelcomePageDestination.bookshelf => 11,
    WelcomePageDestination.more => 12,
    WelcomePageDestination.downloads => 13,
    _ => 10,
  };
}
