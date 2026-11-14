import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/donwload_task/service/download_center_projection.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_completion_notice.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

import '../test_helper.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  Completer<void>? writeGate;
  Completer<void>? writeStarted;
  bool rejectNext = false, throwNext = false;
  int writes = 0;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes++;
    final gate = writeGate;
    writeGate = null;
    final reject = rejectNext, throwing = throwNext;
    rejectNext = throwNext = false;
    if (writeStarted?.isCompleted == false) writeStarted!.complete();
    await gate?.future;
    if (throwing) throw StateError('Synthetic preference failure');
    if (reject) return false;
    return super.setValue(type, key, value);
  }
}

DownloadCenterItem comic({
  String id = 'comic',
  int at = 1000,
  int updatedAt = 1000,
  List<String> chapters = const ['chapter-1'],
  bool skipped = false,
}) => projectDownloadCenter(tasks: [], videos: [], comics: [
  DownloadComicResource(createTestDownload('source:$id')
    ..source = 'source' ..comicId = id
    ..title = 'Private title must not be persisted'
    ..downloadedAt = DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)
    ..updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true)
    ..chapters = jsonEncode([
      for (final key in chapters)
        {'id': 'shared-storage', 'logicalKey': key, 'taskChapterId': 'request-$key',
          'storageChapterId': 'shared-storage', 'name': 'Chapter $key', 'order': 1,
          'images': [{'path': '$key.jpg', if (skipped) 'extern': {'downloadSkipped': true}}]},
    ])),
]).single;

List<DownloadCenterItem> videoRows({int at = 1000, String status = 'saved', bool removed = false, bool external = false, String key = 'transfer-1', int? attempt}) {
  final id = VideoLocalResources.identity('video-source', Uri.parse('https://hanime1.me/watch?v=11'), '720p');
  return projectDownloadCenter(tasks: [], comics: [], videos: [{
    'key': key, 'resourceId': id, 'source': 'video-source',
    'url': 'https://hanime1.me/watch?v=11', 'quality': '720p', 'title': 'Video',
    'status': status, 'local': !external, 'external': external,
    'fileRemoved': removed, 'bytes': 24, 'at': at, 'completedAt': at,
    if (attempt != null) 'attempt': attempt,
  }]);
}

DownloadCenterItem video({int at = 1000, String status = 'saved', bool external = false, String key = 'transfer-1', int? attempt}) =>
    videoRows(at: at, status: status, external: external, key: key, attempt: attempt).single;

DownloadTask failedTask({int id = 51, int attempt = 1, String chapter = 'chapter-1', String state = 'failed', String phase = 'retryWaiting'}) => DownloadTask()
  ..id = id ..comicId = 'comic' ..comicName = 'Comic'
  ..isDownloading = state == 'running'
  ..taskInfo = DownloadTaskJson(
    from: 'source', comicId: 'comic', comicName: 'Comic',
    stateCode: state, phaseCode: phase, attempt: attempt,
    lastErrorCode: 'network', lastErrorMessage: 'PRIVATE_ERROR_MUST_NOT_PERSIST',
    chapterRef: DownloadChapterTaskRef(chapterId: chapter),
  );

DownloadCenterItem withFailures(List<DownloadTask> tasks, {bool completedResource = true, int at = 1000}) =>
    projectDownloadCenter(tasks: tasks, videos: [], comics: [
      if (completedResource) comic(at: at).resource!,
    ]).single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform previous;
  setUp(() {
    previous = SharedPreferencesStorePlatform.instance;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
  });
  DownloadCompletionNotice notice({int maximumEntries = 2048}) {
    final service = DownloadCompletionNotice(maximumEntries: maximumEntries);
    addTearDown(service.changes.dispose);
    return service;
  }

  test('existing completed resources start unseen, persist exact acknowledgments and exclude portable backups', () async {
    final service = notice(), item = comic();
    expect(service.isUnseen(item), isFalse);
    await service.initialize();
    expect(service.isUnseen(item), isTrue);
    await service.markSeen(item);
    expect(service.isUnseen(item), isFalse);
    final restored = notice();
    await restored.initialize();
    expect(restored.isUnseen(item), isFalse);
    final saved = (await SharedPreferences.getInstance()).getString(DownloadCompletionNotice.storageKey)!;
    expect(saved, isNot(contains('Private title')));
    expect(saved, isNot(contains('source:comic')));
    expect(PortablePreferences.owns(DownloadCompletionNotice.storageKey), isFalse);
    expect((await PortablePreferences.capture(persist: false)).entries, isEmpty);
  });

  test('new chapters and re-download completion relight, while refresh or chapter reordering does not', () async {
    final service = notice();
    await service.initialize();
    final original = comic(chapters: ['first', 'second']);
    await service.markSeen(original);
    expect(service.isUnseen(comic(updatedAt: 9999, chapters: ['second', 'first'])), isFalse);
    expect(service.isUnseen(comic(at: 2000, chapters: ['first', 'second'])), isTrue);
    expect(service.isUnseen(comic(chapters: ['first', 'second', 'third'])), isTrue);
  });

  test('legacy completion without trusted time uses stable chapter content without inventing a timestamp', () async {
    final service = notice();
    await service.initialize();
    final old = comic(at: 0);
    expect(service.isUnseen(old), isTrue);
    await service.markSeen(old);
    expect(service.isUnseen(comic(at: 0, updatedAt: 9000)), isFalse);
    expect(service.isUnseen(comic(at: 0, chapters: ['chapter-1', 'chapter-2'])), isTrue);
    final stored = jsonDecode((await SharedPreferences.getInstance()).getString(DownloadCompletionNotice.storageKey)!) as Map;
    final token = ((stored['seen'] as Map).values.single as List).single as Map;
    expect(token.containsKey('completedAt'), isFalse);
  });

  test('late old snapshots neither swallow a new unseen completion nor regress a newer acknowledgment', () async {
    final service = notice();
    await service.initialize();
    final old = comic(), newer = comic(at: 2000, chapters: ['chapter-1', 'chapter-2']);
    await service.markSeen(old);
    expect(service.isUnseen(newer), isTrue);
    await service.markSeen(newer);
    await service.markSeen(old);
    expect(service.isUnseen(newer), isFalse);
    expect(service.isUnseen(old), isFalse);
    expect(service.isUnseen(comic(at: 3000, chapters: ['chapter-1', 'chapter-2', 'chapter-3'])), isTrue);
    final restarted = notice();
    await restarted.initialize();
    expect(restarted.isUnseen(newer), isFalse);
    final newestFirst = comic(id: 'late-old', at: 2000);
    final lateOld = comic(id: 'late-old');
    await service.markSeen(newestFirst);
    await service.markSeen(lateOld);
    expect(service.isUnseen(newestFirst), isFalse);
    expect(service.isUnseen(lateOld), isFalse);
  });

  test('serialized clicks wait for persistence and capture each snapshot before awaiting', () async {
    final store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    final service = notice();
    await service.initialize();
    final gate = Completer<void>();
    store.writeGate = gate;
    store.writeStarted = Completer<void>();
    final pending = <Future<void>>[];
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      await Future.wait(pending);
    });
    final old = video(), newer = video(at: 2000);
    pending.add(service.markSeen(old));
    await store.writeStarted!.future;
    pending.add(service.markSeen(newer));
    old.video!['completedAt'] = 3000; // Mutating the caller cannot expand its write.
    expect(store.writes, 1);
    expect(service.isUnseen(video()), isTrue);
    expect(service.isUnseen(newer), isTrue);
    gate.complete();
    await Future.wait(pending);
    expect(service.isUnseen(video()), isFalse);
    expect(service.isUnseen(newer), isFalse);
    expect(service.isUnseen(old), isTrue);
  });

  test('failed preference writes preserve the dot, previous acknowledgments and retryability', () async {
    final store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    final service = notice();
    await service.initialize();
    final first = comic(), second = comic(id: 'another');
    await service.markSeen(first);
    final revision = service.changes.value;
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString(DownloadCompletionNotice.storageKey);
    store.rejectNext = true;
    await expectLater(service.markSeen(second), throwsStateError);
    expect(service.changes.value, revision);
    expect(service.isUnseen(second), isTrue);
    expect(service.isUnseen(first), isFalse);
    expect(prefs.getString(DownloadCompletionNotice.storageKey), before);
    store.throwNext = true;
    await expectLater(service.markSeen(second), throwsStateError);
    expect(service.isUnseen(second), isTrue);
    await service.markSeen(second);
    expect(service.isUnseen(second), isFalse);
  });

  test('only managed saved resources qualify, never task completion, removed files or external exports', () async {
    final service = notice();
    await service.initialize();
    for (final state in ['queued', 'running', 'failed', 'cancelled', 'completed']) {
      final task = DownloadTask()
        ..comicId = 'comic' ..isCompleted = state == 'completed'
        ..taskInfo = DownloadTaskJson(from: 'source', comicId: 'comic', comicName: 'Comic',
          stateCode: state, phaseCode: state == 'completed' ? 'fileRemoved' : '',
          chapterRef: const DownloadChapterTaskRef(chapterId: 'chapter-1'));
      final rows = projectDownloadCenter(tasks: [task], comics: [], videos: []);
      if (state == 'completed') {
        expect(rows, isEmpty); // Deleted completed tasks cannot create a card.
      } else {
        expect(service.isUnseen(rows.single), isFalse);
        await service.markSeen(rows.single);
      }
    }
    expect(service.isUnseen(comic(chapters: [])), isFalse);
    expect(service.isUnseen(comic(skipped: true)), isFalse);
    expect(service.isUnseen(video(status: 'downloading')), isFalse);
    expect(videoRows(removed: true), isEmpty);
    expect(service.isUnseen(video(external: true)), isFalse);
    expect(service.isUnseen(video()), isTrue);
    await service.markSeen(video());
    expect(service.isUnseen(video()), isFalse);
    expect(service.isUnseen(video(at: 2000)), isTrue);
  });

  test('a few hundred acknowledged resources remain read under the default bounded history', () async {
    final service = notice();
    await service.initialize();
    for (var i = 0; i < 300; i++) {
      await service.markSeen(comic(id: 'comic-$i'));
    }
    final restarted = notice();
    await restarted.initialize();
    expect(restarted.isUnseen(comic(id: 'comic-0')), isFalse);
    expect(restarted.isUnseen(comic(id: 'comic-299')), isFalse);
    expect(restarted.isUnseen(comic(id: 'comic-300')), isTrue);
    final raw = jsonDecode((await SharedPreferences.getInstance()).getString(DownloadCompletionNotice.storageKey)!) as Map;
    expect((raw['seen'] as Map).length, 300);
  });

  test('unseen failure wins over completion and one acknowledgment clears both without changing retry state', () async {
    final service = notice();
    await service.initialize();
    final task = failedTask();
    final item = withFailures([task]);
    final before = task.dbTaskInfoStr;
    expect(service.kind(item), DownloadNoticeKind.failed);
    expect(service.isUnseen(item), isTrue);
    await service.markSeen(item);
    expect(service.kind(item), DownloadNoticeKind.none);
    expect(service.kind(comic()), DownloadNoticeKind.none);
    expect(task.dbTaskInfoStr, before);
    expect(task.taskInfo!.stateCode, 'failed');
    final saved = (await SharedPreferences.getInstance()).getString(DownloadCompletionNotice.storageKey)!;
    expect(saved, isNot(contains('PRIVATE_ERROR_MUST_NOT_PERSIST')));
    final restarted = notice();
    await restarted.initialize();
    expect(restarted.kind(item), DownloadNoticeKind.none);
  });

  test('new failed attempt relights red, stale clicks cannot consume it, and successful retry becomes green', () async {
    final service = notice();
    await service.initialize();
    final old = withFailures([failedTask()], completedResource: false);
    expect(service.kind(old), DownloadNoticeKind.failed);
    await service.markSeen(old);
    expect(service.kind(old), DownloadNoticeKind.none);
    for (final state in ['queued', 'running', 'paused', 'cancelled']) {
      expect(service.kind(withFailures([failedTask(state: state)], completedResource: false)), DownloadNoticeKind.none);
    }
    final second = withFailures([failedTask(attempt: 2)], completedResource: false);
    expect(service.kind(second), DownloadNoticeKind.failed);
    await service.markSeen(old);
    expect(service.kind(second), DownloadNoticeKind.failed);
    await service.markSeen(second);
    await service.markSeen(old);
    expect(service.kind(second), DownloadNoticeKind.none);
    final successful = withFailures([failedTask(attempt: 2, state: 'completed', phase: 'completed')], at: 2000);
    expect(service.kind(successful), DownloadNoticeKind.completed);
    await service.markSeen(successful);
    expect(service.kind(successful), DownloadNoticeKind.none);
  });

  test('resolved failures do not relight the remaining acknowledged failed chapters', () async {
    final service = notice();
    await service.initialize();
    final one = failedTask(id: 51, chapter: 'one');
    final two = failedTask(id: 52, chapter: 'two');
    await service.markSeen(withFailures([one, two], completedResource: false));
    expect(service.kind(withFailures([two], completedResource: false)), DownloadNoticeKind.none);
    expect(service.kind(withFailures([one, failedTask(id: 52, chapter: 'two', attempt: 2)], completedResource: false)), DownloadNoticeKind.failed);
    expect(service.kind(withFailures([failedTask(id: 53, chapter: 'three')], completedResource: false)), DownloadNoticeKind.failed);
    expect(service.kind(withFailures([failedTask(phase: 'cancelling')], completedResource: false)), DownloadNoticeKind.none);
    expect(
      projectDownloadCenter(
        tasks: [failedTask(phase: 'fileRemoved')], comics: [], videos: [],
      ),
      isEmpty,
    );
  });

  test('video failures use actual transfer key time and attempt, while pause cancel and interruption are not failures', () async {
    final service = notice();
    await service.initialize();
    final old = video(status: 'failed', attempt: 1);
    expect(service.kind(old), DownloadNoticeKind.failed);
    await service.markSeen(old);
    expect(service.kind(video(status: 'failed', attempt: 1)), DownloadNoticeKind.none);
    final repeated = video(status: 'failed', attempt: 2);
    expect(service.kind(repeated), DownloadNoticeKind.failed);
    await service.markSeen(old);
    expect(service.kind(repeated), DownloadNoticeKind.failed);
    expect(service.kind(video(status: 'failed', key: 'transfer-2')), DownloadNoticeKind.failed);
    expect(service.kind(video(status: 'failed', at: 2000, attempt: 1)), DownloadNoticeKind.failed);
    for (final status in ['preparing', 'downloading', 'saving', 'paused', 'cancelled', 'interrupted']) {
      expect(service.kind(video(status: status)), DownloadNoticeKind.none);
    }
    expect(service.kind(video(at: 2000)), DownloadNoticeKind.completed);
  });

  test('a rejected joint red and green acknowledgment leaves both unseen for retry', () async {
    final store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    final service = notice();
    await service.initialize();
    final item = withFailures([failedTask()]);
    final revision = service.changes.value;
    store.rejectNext = true;
    await expectLater(service.markSeen(item), throwsStateError);
    expect(service.kind(item), DownloadNoticeKind.failed);
    expect(service.kind(comic()), DownloadNoticeKind.completed);
    expect(service.changes.value, revision);
    await service.markSeen(item);
    expect(service.kind(item), DownloadNoticeKind.none);
    expect(service.kind(comic()), DownloadNoticeKind.none);
  });

  test('an in-flight acknowledgment captures the old failure attempt before the task retries', () async {
    final store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    final service = notice();
    await service.initialize();
    final gate = Completer<void>();
    store.writeGate = gate;
    store.writeStarted = Completer<void>();
    final task = failedTask();
    final snapshot = withFailures([task]);
    final acknowledgment = service.markSeen(snapshot);
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      await acknowledgment;
    });
    await store.writeStarted!.future;
    task.taskInfo = task.taskInfo!.copyWith(attempt: 2, lastErrorCode: 'new-failure');
    expect(service.kind(snapshot), DownloadNoticeKind.failed);
    gate.complete();
    await acknowledgment;
    expect(service.kind(snapshot), DownloadNoticeKind.failed);
    expect(service.kind(comic()), DownloadNoticeKind.none);
    await service.markSeen(snapshot);
    expect(service.kind(snapshot), DownloadNoticeKind.none);
  });

  test('configured history and per-resource completion history remain bounded', () async {
    final service = notice(maximumEntries: 2);
    await service.initialize();
    for (var i = 1; i <= 7; i++) {
      await service.markSeen(comic(at: i * 1000));
    }
    final prefs = await SharedPreferences.getInstance();
    var raw = jsonDecode(prefs.getString(DownloadCompletionNotice.storageKey)!) as Map;
    expect(((raw['seen'] as Map).values.single as List).length, 4);
    expect(service.isUnseen(comic(at: 7000)), isFalse);
    await service.markSeen(comic(id: 'second'));
    await service.markSeen(comic(id: 'third'));
    raw = jsonDecode(prefs.getString(DownloadCompletionNotice.storageKey)!) as Map;
    expect((raw['seen'] as Map).length, 2);
    expect(service.isUnseen(comic(id: 'third')), isFalse);
  });
}
