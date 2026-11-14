import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_work_pins.dart';

DownloadCenterItem _video(
  String id, {
  String source = 'source-a',
  String? work,
}) => DownloadCenterItem(
  key: 'video:$source:$id',
  source: source,
  title: 'Same title',
  priority: 3,
  at: 100,
  video: {
    if (work != null) ...{
      'publicWorkIdentity': work,
      'publicWorkTitle': 'Same title',
      'publicModuleNamespace': 'series',
    },
  },
);

class _ControlledPreferences extends InMemorySharedPreferencesStore {
  _ControlledPreferences() : super.withData({});
  Future<bool> Function()? nextWrite;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final intercept = nextWrite;
    nextWrite = null;
    if (intercept != null && !await intercept()) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform previous;

  setUp(() {
    previous = SharedPreferencesStorePlatform.instance;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = previous;
  });

  test('forget clears the whole rank for the exact deleted work', () async {
    final first = _video('1', work: 'work');
    final second = _video('2', work: 'work');
    final other = _video('1', source: 'source-b', work: 'work');
    await DownloadWorkPins.setPinnedItems([first, second], true);
    await DownloadWorkPins.setPinnedItems([other], true);
    await DownloadWorkPins.forget(first.key);
    final pins = await DownloadWorkPins.read();
    expect(DownloadWorkPins.rankFor(first, pins), isNull);
    expect(DownloadWorkPins.rankFor(second, pins), isNull);
    expect(DownloadWorkPins.rankFor(other, pins), isNotNull);
  });

  test(
    'episode deletion clears only the last member of its captured pin',
    () async {
      final first = _video('1', work: 'work');
      final second = _video('2', work: 'work');
      final other = _video('1', source: 'source-b', work: 'work');
      await DownloadWorkPins.setPinnedItems([first, second], true);
      await DownloadWorkPins.setPinnedItems([other], true);
      final rank = (await DownloadWorkPins.read())[first.key]!;
      await DownloadWorkPins.reconcile(
        () => [second],
        removedPin: (alias: first.key, rank: rank),
      );
      expect(
        DownloadWorkPins.rankFor(second, await DownloadWorkPins.read()),
        rank,
      );
      await DownloadWorkPins.reconcile(
        () => [],
        removedPin: (alias: second.key, rank: rank),
      );
      final pins = await DownloadWorkPins.read();
      expect(DownloadWorkPins.rankFor(first, pins), isNull);
      expect(DownloadWorkPins.rankFor(other, pins), isNotNull);
    },
  );

  test(
    'single video pins survive work identity enrichment and metadata gaps',
    () async {
      final single = _video('1');
      final first = _video('1', work: 'work');
      final second = _video('2', work: 'work');
      final other = _video('1', source: 'source-b', work: 'work');
      await DownloadWorkPins.setPinnedItems([single], true);
      final rank = DownloadWorkPins.rankFor(
        single,
        await DownloadWorkPins.read(),
      );

      await DownloadWorkPins.reconcile(() => [first, second, other]);
      var pins = await DownloadWorkPins.read();
      expect(DownloadWorkPins.rankFor(first, pins), rank);
      expect(DownloadWorkPins.rankFor(second, pins), rank);
      expect(DownloadWorkPins.rankFor(other, pins), isNull);

      final secondWithoutMetadata = _video('2');
      await DownloadWorkPins.reconcile(() => [secondWithoutMetadata, other]);
      pins = await DownloadWorkPins.read();
      expect(DownloadWorkPins.rankFor(secondWithoutMetadata, pins), rank);
      expect(DownloadWorkPins.rankFor(second, pins), rank);
      await DownloadWorkPins.setPinnedItems([secondWithoutMetadata], false);
      expect(await DownloadWorkPins.read(), isEmpty);
    },
  );

  test(
    'converging episode pins keep the newest rank and stable default order',
    () async {
      final first = _video('1');
      final second = _video('2');
      final unrelatedA = _video('3');
      final unrelatedB = _video('4');
      await DownloadWorkPins.setPinnedItems([first], true);
      await DownloadWorkPins.setPinnedItems([second], true);
      final before = await DownloadWorkPins.read();
      final newest = DownloadWorkPins.rankFor(second, before)!;
      expect(newest, greaterThan(DownloadWorkPins.rankFor(first, before)!));

      final knownFirst = _video('1', work: 'work');
      final knownSecond = _video('2', work: 'work');
      await DownloadWorkPins.reconcile(
        () => [unrelatedB, knownFirst, unrelatedA, knownSecond],
      );
      final pins = await DownloadWorkPins.read();
      expect(pins.values.toSet(), {newest});
      final rows = [
        for (final item in [unrelatedB, knownFirst, unrelatedA])
          DownloadCenterDisplayItem(item),
      ];
      expect(DownloadWorkPins.arrange(rows, pins), [rows[1], rows[0], rows[2]]);
    },
  );

  test(
    'rejected and thrown preference writes restore the cached state',
    () async {
      final store = _ControlledPreferences();
      SharedPreferencesStorePlatform.instance = store;
      final first = _video('1');
      final second = _video('2');
      store.nextWrite = () async => false;
      await expectLater(
        DownloadWorkPins.setPinnedItems([first], true),
        throwsStateError,
      );
      expect(await DownloadWorkPins.read(), isEmpty);

      await DownloadWorkPins.setPinnedItems([first], true);
      final before = await DownloadWorkPins.read();
      store.nextWrite = () async => throw PlatformException(code: 'test');
      await expectLater(
        DownloadWorkPins.setPinnedItems([second], true),
        throwsA(isA<PlatformException>()),
      );
      expect(await DownloadWorkPins.read(), before);
    },
  );

  test(
    'queued reconciliation reads inventory after a pending pin write',
    () async {
      final store = _ControlledPreferences();
      SharedPreferencesStorePlatform.instance = store;
      final item = _video('1');
      final started = Completer<void>();
      final release = Completer<bool>();
      store.nextWrite = () {
        started.complete();
        return release.future;
      };
      final writing = DownloadWorkPins.setPinnedItems([item], true);
      await started.future;
      var all = <DownloadCenterItem>[];
      final reconciling = DownloadWorkPins.reconcile(() => all);
      all = [item];
      release.complete(true);
      await Future.wait([writing, reconciling]);
      expect(
        DownloadWorkPins.rankFor(item, await DownloadWorkPins.read()),
        isNotNull,
      );

      await DownloadWorkPins.reconcile(() => null);
      expect(
        DownloadWorkPins.rankFor(item, await DownloadWorkPins.read()),
        isNotNull,
      );
      await DownloadWorkPins.reconcile(() => []);
      expect(await DownloadWorkPins.read(), isEmpty);
    },
  );
}
