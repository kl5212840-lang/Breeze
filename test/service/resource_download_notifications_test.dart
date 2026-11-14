import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/service/download/resource_download_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ResourceDownloadItem item(
    String id,
    ResourceDownloadState state, {
    String work = 'comic/source/work',
    int attempt = 1,
  }) => (
    work: work,
    item: id,
    title: 'Same title',
    episode: id,
    attempt: attempt,
    state: state,
  );

  const pending = ResourceDownloadState.pending;
  const complete = ResourceDownloadState.completed;
  const cancelled = ResourceDownloadState.cancelled;
  late List<ResourceDownloadItem> rows;
  late String mode;
  late List<(int, String)> notices;
  setUp(() {
    rows = [];
    mode = 'work';
    notices = [];
  });
  ResourceDownloadNotifications service() => ResourceDownloadNotifications(
    read: () async => rows,
    mode: () => mode,
    deliver: (id, name) async => notices.add((id, name)),
  );
  Future<void> sync(ResourceDownloadNotifications service) async {
    service.changed();
    await service.settle();
    await Future<void>.delayed(Duration.zero);
    await service.settle();
  }

  test(
    'same snapshot cancellation and completion never imply whole work success',
    () async {
      final tracker = service()..enableDelivery();
      rows = [item('one', pending), item('two', pending)];
      await sync(tracker);
      rows = [item('one', complete), item('two', cancelled)];
      await sync(tracker);
      expect(notices, isEmpty);
    },
  );

  test('a newly queued sibling invalidates a persisted work outbox', () async {
    final tracker = service();
    rows = [item('one', pending)];
    await sync(tracker);
    rows = [item('one', complete)];
    await sync(tracker);
    rows = [...rows, item('two', pending)];
    tracker.enableDelivery();
    await sync(tracker);
    expect(notices, isEmpty);
    rows = [rows.first, item('two', complete)];
    await sync(tracker);
    expect(notices, hasLength(1));
  });

  test(
    'malformed persisted rows reset without announcing completed history',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ResourceDownloadNotifications.storageKey,
        '{"version":1,"pending":5,"outbox":{},"blocked":[]}',
      );
      rows = [item('old', complete), item('one', pending)];
      final tracker = service()..enableDelivery();
      await sync(tracker);
      expect(notices, isEmpty);
      rows = [rows.first, item('one', complete)];
      await sync(tracker);
      expect(notices, hasLength(1));
    },
  );

  test(
    'old completed records are quiet; same work batches merge and retry survives restart',
    () async {
      var tracker = service()..enableDelivery();
      rows = [item('old', complete)];
      await sync(tracker);
      rows = [...rows, item('one', pending)];
      await sync(tracker);
      rows = [...rows, item('two', pending)];
      await sync(tracker);
      rows = [
        item('old', complete),
        item('one', complete),
        item('two', pending),
      ];
      await sync(tracker);
      expect(notices, isEmpty);
      tracker = service()..enableDelivery();
      rows = [
        item('old', complete),
        item('one', complete),
        item('two', complete, attempt: 2),
      ];
      await sync(tracker);
      await sync(tracker);
      expect(notices.map((n) => n.$2), ['Same title']);
    },
  );

  test(
    'cancelling or deleting a failed sibling does not generate completion',
    () async {
      final tracker = service()..enableDelivery();
      rows = [item('one', pending), item('two', pending)];
      await sync(tracker);
      rows = [item('one', complete), item('two', pending)];
      await sync(tracker);
      rows = [item('one', complete), item('two', cancelled)];
      await sync(tracker);
      rows = [item('one', complete)];
      await sync(tracker);
      expect(notices, isEmpty);
    },
  );

  test(
    'same titles in different sources stay independent, including video',
    () async {
      final tracker = service()..enableDelivery();
      rows = [
        item('one', pending),
        item('video', pending, work: 'video/other/module/work'),
      ];
      await sync(tracker);
      rows = [
        item('one', pending),
        item('video', complete, work: 'video/other/module/work'),
      ];
      await sync(tracker);
      expect(notices, hasLength(1));
      rows = [item('one', complete), rows.last];
      await sync(tracker);
      expect(notices.map((n) => n.$1).toSet(), hasLength(2));
    },
  );

  test(
    'off consumes completed episodes and initialized outbox delivers once',
    () async {
      final tracker = service();
      mode = 'off';
      rows = [item('off', pending)];
      await sync(tracker);
      rows = [item('off', complete)];
      await sync(tracker);
      mode = 'episode';
      rows = [...rows, item('on', pending)];
      await sync(tracker);
      rows = [rows.first, item('on', complete)];
      await sync(tracker);
      expect(notices, isEmpty);
      final restarted = service()..enableDelivery();
      await sync(restarted);
      await sync(restarted);
      expect(notices.map((n) => n.$2), ['on']);
    },
  );
}
