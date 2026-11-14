import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/navigation/welcome_page_destination.dart';

void main() {
  test('the previous default now opens Discover and bookshelf is centered', () {
    expect(
      resolveWelcomePageDestination(0, oldPageRollbackEnabled: false),
      WelcomePageDestination.discover,
    );
    expect(
      welcomePageTabIndex(
        WelcomePageDestination.bookshelf,
        oldPageRollbackEnabled: false,
      ),
      1,
    );
  });

  test('older explicit Discover and More selections remain on those pages', () {
    expect(
      resolveWelcomePageDestination(1, oldPageRollbackEnabled: false),
      WelcomePageDestination.discover,
    );
    expect(
      resolveWelcomePageDestination(2, oldPageRollbackEnabled: false),
      WelcomePageDestination.more,
    );
  });

  test('new bookshelf selection survives restart and legacy mode switch', () {
    final stored = storedWelcomePageValue(
      WelcomePageDestination.bookshelf,
      oldPageRollbackEnabled: false,
    );
    expect(stored, 11);
    expect(
      welcomePageTabIndex(
        resolveWelcomePageDestination(stored, oldPageRollbackEnabled: false),
        oldPageRollbackEnabled: false,
      ),
      1,
    );
    expect(
      welcomePageTabIndex(
        resolveWelcomePageDestination(stored, oldPageRollbackEnabled: true),
        oldPageRollbackEnabled: true,
      ),
      2,
    );
  });

  test(
    'download destination uses a stable code and preserves old More values',
    () {
      for (final old in [false, true]) {
        expect(
          storedWelcomePageValue(
            WelcomePageDestination.downloads,
            oldPageRollbackEnabled: old,
          ),
          13,
        );
        expect(
          resolveWelcomePageDestination(13, oldPageRollbackEnabled: old),
          WelcomePageDestination.downloads,
        );
        expect(
          welcomePageTabIndex(
            WelcomePageDestination.downloads,
            oldPageRollbackEnabled: old,
          ),
          old ? 4 : 2,
        );
        expect(
          resolveWelcomePageDestination(12, oldPageRollbackEnabled: old),
          WelcomePageDestination.more,
        );
        expect(
          resolveWelcomePageDestination(
            old ? 4 : 2,
            oldPageRollbackEnabled: old,
          ),
          WelcomePageDestination.more,
        );
      }
    },
  );

  test('old rollback tab order is not changed', () {
    expect(
      resolveWelcomePageDestination(0, oldPageRollbackEnabled: true),
      WelcomePageDestination.oldHome,
    );
    expect(
      resolveWelcomePageDestination(3, oldPageRollbackEnabled: true),
      WelcomePageDestination.discover,
    );
  });
}
