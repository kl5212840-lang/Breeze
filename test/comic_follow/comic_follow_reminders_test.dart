import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/comic_follow/comic_follow_navigation.dart';
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';
import 'package:zephyr/widgets/toast.dart';

class _ReminderPreferences extends InMemorySharedPreferencesStore {
  _ReminderPreferences(super.data) : super.withData();
  bool reject = false;
  Completer<void>? receiptRelease;
  final receiptStarted = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject) return false;
    final release = receiptRelease;
    if (release != null &&
        key.endsWith(ComicFollowReminderController.seenKey)) {
      receiptRelease = null;
      receiptStarted.complete();
      await release.future;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'default is badge only; badge and silent produce no transient notifications',
    () async {
      final events = <ToastEvent>[];
      final controller = ComicFollowReminderController(emit: events.add);
      addTearDown(controller.dispose);
      expect(
        controller.showsBadge,
        isFalse,
        reason: 'unloaded silent preferences must not flash a badge',
      );
      await controller.load();
      expect(controller.mode.value, ComicFollowReminderMode.badge);
      expect(controller.showsBadge, isTrue);
      await controller.notifyUpdates({'fixture:1': 12});
      expect(events, isEmpty);
      await controller.setMode(ComicFollowReminderMode.silent);
      await controller.notifyUpdates({'fixture:1': 13});
      expect(events, isEmpty);
      expect(controller.showsBadge, isFalse);
      final reloaded = ComicFollowReminderController(emit: events.add);
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.mode.value, ComicFollowReminderMode.silent);
      expect(
        PortablePreferences.owns(ComicFollowReminderController.modeKey),
        isFalse,
      );
      expect(
        PortablePreferences.owns(ComicFollowReminderController.seenKey),
        isFalse,
      );
    },
  );

  test(
    'in-app mode merges a batch into one clickable notice and deduplicates receipts after reload',
    () async {
      final events = <ToastEvent>[];
      final controller = ComicFollowReminderController(emit: events.add);
      addTearDown(controller.dispose);
      await controller.setMode(ComicFollowReminderMode.inApp);
      await controller.notifyUpdates({'fixture:1': 12, 'fixture:2': 8});
      expect(events, hasLength(1));
      expect(events.single.onTap, isNotNull);
      expect(events.single.actionLabel, isNotEmpty);
      var opened = 0;
      final owner = Object();
      ComicFollowNavigation.attach(owner, () async {
        opened++;
        return true;
      });
      await events.single.onTap!();
      ComicFollowNavigation.detach(owner);
      expect(opened, 1);
      await controller.notifyUpdates({'fixture:1': 12, 'fixture:2': 8});
      await controller.notifyUpdates({'fixture:1': 10});
      await controller.notifyUpdates({'fixture:1': 12});
      expect(events, hasLength(1));
      final reloaded = ComicFollowReminderController(emit: events.add);
      addTearDown(reloaded.dispose);
      await reloaded.notifyUpdates({'fixture:1': 12});
      expect(events, hasLength(1));
      await reloaded.notifyUpdates({'fixture:1': 13});
      expect(events, hasLength(2));
    },
  );

  test(
    'enabling notices does not announce an old update that badge mode already observed',
    () async {
      final events = <ToastEvent>[];
      final controller = ComicFollowReminderController(emit: events.add);
      addTearDown(controller.dispose);
      await controller.notifyUpdates({'fixture:1': 12});
      await controller.setMode(ComicFollowReminderMode.inApp);
      await controller.notifyUpdates({'fixture:1': 12});
      expect(events, isEmpty);
      await controller.notifyUpdates({'fixture:1': 13});
      expect(events, hasLength(1));
    },
  );

  test(
    'failed durable writes neither change reminder mode nor announce a receipt as saved',
    () async {
      final events = <ToastEvent>[];
      final controller = ComicFollowReminderController(emit: events.add);
      addTearDown(controller.dispose);
      await controller.setMode(ComicFollowReminderMode.inApp);
      final previous = SharedPreferencesStorePlatform.instance;
      final failing = _ReminderPreferences(await previous.getAll())
        ..reject = true;
      SharedPreferencesStorePlatform.instance = failing;
      try {
        await expectLater(
          controller.setMode(ComicFollowReminderMode.silent),
          throwsStateError,
        );
        expect(controller.mode.value, ComicFollowReminderMode.inApp);
        expect(controller.showsBadge, isTrue);
        await expectLater(
          controller.notifyUpdates({'fixture:1': 12}),
          throwsStateError,
        );
        expect(events, isEmpty);
        failing.reject = false;
        await controller.notifyUpdates({'fixture:1': 12});
        expect(
          events,
          hasLength(1),
          reason:
              'failed receipt writes must not suppress a later valid attempt',
        );
      } finally {
        SharedPreferencesStorePlatform.instance = previous;
      }
    },
  );

  test(
    'only current unread updates count while a receipt is being saved',
    () async {
      final events = <ToastEvent>[];
      final controller = ComicFollowReminderController(emit: events.add);
      addTearDown(controller.dispose);
      await controller.setMode(ComicFollowReminderMode.inApp);
      final previous = SharedPreferencesStorePlatform.instance;
      final release = Completer<void>();
      final delayed = _ReminderPreferences(await previous.getAll())
        ..receiptRelease = release;
      SharedPreferencesStorePlatform.instance = delayed;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previous;
      });
      var firstUnread = true;
      var laterUnread = false;
      final first = controller.notifyUpdates({
        'fixture:1': 12,
        'fixture:2': 8,
      }, canDeliver: (key, _) => key == 'fixture:2' || firstUnread);
      await delayed.receiptStarted.future;
      final queued = controller.notifyUpdates({
        'fixture:3': 6,
      }, canDeliver: (_, _) => laterUnread);
      firstUnread = false;
      release.complete();
      await first;
      await queued;
      expect(events, hasLength(1));
      expect(events.single.message, t.comicFollow.updatedComicsSingle);
      laterUnread = true;
      await controller.notifyUpdates({
        'fixture:3': 6,
      }, canDeliver: (_, _) => laterUnread);
      expect(events, hasLength(2));
    },
  );

  test(
    'old navigation owners cannot detach the active follow callback',
    () async {
      final old = Object(), current = Object();
      var opened = 0;
      ComicFollowNavigation.attach(old, () async => false);
      ComicFollowNavigation.attach(current, () async {
        opened++;
        return true;
      });
      ComicFollowNavigation.detach(old);
      expect(await ComicFollowNavigation.open(), isTrue);
      expect(opened, 1);
      ComicFollowNavigation.detach(current);
      expect(await ComicFollowNavigation.open(), isFalse);
    },
  );
}
