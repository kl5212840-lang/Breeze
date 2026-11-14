import 'package:zephyr/service/download/resource_download_notifications.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cbor/cbor.dart' as cbor;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:worker_manager/worker_manager.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart' show ObservableStore;
import 'package:zephyr/page/comic_info/widgets/episode_download_controller.dart';
import 'package:zephyr/page/comic_read/method/get_local_info.dart';
import 'package:zephyr/page/download/adapters/download_chapter_adapter.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/download/comic_download_route.dart';
import 'package:zephyr/service/download/comic_download_task.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/service/download/download_cancel_signal.dart';
import 'package:zephyr/service/download/download_chapter_removal.dart';
import 'package:zephyr/service/download/download_progress_reporter.dart';
import 'package:zephyr/service/download/download_retry.dart';
import 'package:zephyr/service/download/download_queue_manager.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/image_download.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/type/enum.dart';

import '../download_fixture.dart';
import '../test_helper.dart';

const _payload = DownloadTaskJson(
  from: 'chapter-integrity-fixture',
  comicId: 'work',
  comicName: 'Work',
  stateCode: 'running',
  attempt: 1,
  chapterRef: DownloadChapterTaskRef(
    logicalKey: 'selected',
    chapterId: 'catalog-id',
    requestId: 'request-id',
    storageChapterId: 'shared-storage',
    title: 'Selected',
    order: 2,
  ),
);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1sAAAAASUVORK5CYII=',
);

final _invalidImageBody = Uint8List.fromList(utf8.encode('upstream error'));

Uint8List _coloredPng(int red, int green, int blue) => image.encodePng(
  image.Image(width: 1, height: 1)..setPixelRgb(0, 0, red, green, blue),
);

enum _AlternatePageFailure {
  missing('HTTP 404'),
  invalidImage('HTTP 200 with a text body');

  const _AlternatePageFailure(this.description);

  final String description;
}

Map<String, dynamic> _normalDetail(List<Map<String, dynamic>> chapters) => {
  'comicInfo': {
    'id': _payload.comicId,
    'title': _payload.comicName,
    'titleMeta': [],
    'description': '',
    'cover': {'id': '', 'url': '', 'name': ''},
    'metadata': [],
  },
  'eps': chapters,
  'recommend': [],
};

class _Reporter extends DownloadProgressReporter {
  @override
  Future<void> sendNotification(String title, String body) async {}
}

class _LifecycleConnectivity extends DownloadConnectivityFixture {
  bool wifiOnRefresh = false;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      wifiOnRefresh ? [ConnectivityResult.wifi] : super.checkConnectivity();
}

class _PluginApi extends RustLibApi {
  Map<String, dynamic> chapterResponse = {};
  final chapterResponses = <String, Map<String, dynamic>>{};
  final downloadRouteResponses = <String, Map<String, dynamic>>{};
  final downloadRouteRequests = <Map<String, dynamic>?>[];
  List<Map<String, dynamic>> detailChapters = [];
  final detailRequests = <Map<String, dynamic>>[];
  Object? detailError;
  String expectedRequestId = _payload.chapterRef.requestId;
  final imageRequests = <String>[];
  Object? firstChapterError;
  int chapterRequests = 0;
  final firstImageStatus = <String, int>{};
  final imageStatus = <String, int>{};
  final firstImageEmpty = <String>{};
  final imageBodies = <String, Uint8List>{};
  String? heldImageUrl;
  Completer<void>? imageEntered;
  Completer<void>? releaseImage;
  Completer<void>? imageResponseReturned;
  Completer<void>? cancellationEntered;
  Completer<void>? releaseCancellation;
  final readGroups = <String, String>{};
  Completer<void>? chapterEntered;
  Completer<void>? releaseChapter;
  Completer<void>? detailEntered;
  Completer<void>? releaseDetail;
  bool failCommitPath = false;

  @override
  String crateApiSimpleEncodePath({required String path}) {
    if (failCommitPath && path == _payload.from) {
      throw const FileSystemException(
        'Could not resolve the chapter storage root',
      );
    }
    // The real encoder produces bounded file names even for namespaced pages.
    return 'fixture-${sha256.convert(utf8.encode(path))}';
  }

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('chapter-integrity-fixture');

  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async =>
      true;

  @override
  Future<QjsCancelTasksByGroupResult> crateApiQjsQjsCancelTasksByGroup({
    required String runtimeName,
    required String taskGroupKey,
  }) async {
    if (cancellationEntered?.isCompleted == false) {
      cancellationEntered!.complete();
    }
    await releaseCancellation?.future;
    return const QjsCancelTasksByGroupResult(
      cancelled: 0,
      notFound: 1,
      failedRuntimeGroups: [],
    );
  }

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    if (fnPath != 'init') readGroups[fnPath] = taskGroupKey;
    if (fnPath == 'getComicDetail') {
      detailRequests.add(jsonDecode(argsJson) as Map<String, dynamic>);
      detailEntered?.complete();
      await releaseDetail?.future;
      final error = detailError;
      if (error != null) throw error;
    }
    final chapterArgs = fnPath == 'getChapter'
        ? jsonDecode(argsJson) as Map<String, dynamic>
        : null;
    final chapterRequest = chapterArgs?['chapterId'] as String? ?? '';
    final response = switch (fnPath) {
      'init' => {'ok': true},
      'isJm' => false,
      'getComicDetail' => {'normal': _normalDetail(detailChapters)},
      'getDownloadConcurrency' => {'concurrency': 1},
      'getChapter' => _chapterResponse(chapterRequest, chapterArgs!),
      _ => throw StateError('Unexpected plugin function $fnPath'),
    };
    if (fnPath == 'getChapter') {
      expect(
        chapterRequest == expectedRequestId ||
            chapterResponses.containsKey(chapterRequest),
        isTrue,
      );
      chapterRequests++;
      chapterEntered?.complete();
      await releaseChapter?.future;
      final error = firstChapterError;
      if (chapterRequests == 1 && error != null) throw error;
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(response)));
  }

  Map<String, dynamic> _chapterResponse(
    String chapterRequest,
    Map<String, dynamic> args,
  ) {
    if (downloadRouteResponses.isEmpty) {
      return chapterResponses[chapterRequest] ?? chapterResponse;
    }
    final value = args['downloadRoute'];
    final request = value is Map ? Map<String, dynamic>.from(value) : null;
    downloadRouteRequests.add(request);
    final excluded = request?['excluded'] as List? ?? const [];
    for (final route in downloadRouteResponses.entries) {
      if (!excluded.contains(route.key)) return route.value;
    }
    throw AnyhowException('{"type":"comic_download_route_unavailable"}');
  }

  @override
  Future<Uint8List> crateApiQjsQjsFetchImage({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    final url = jsonDecode(argsJson)['url'] as String;
    final isFirstRequest = !imageRequests.contains(url);
    final status = isFirstRequest ? firstImageStatus[url] : null;
    final bytes = isFirstRequest && firstImageEmpty.contains(url)
        ? Uint8List(0)
        : imageBodies[url] ?? Uint8List(0);
    imageRequests.add(url);
    if (isFirstRequest && url == heldImageUrl) {
      imageEntered?.complete();
      await releaseImage?.future;
      imageResponseReturned?.complete();
    }
    return Uint8List.fromList(
      cbor.cbor.encode(
        cbor.CborValue({
          'version': 1,
          'bytes': bytes,
          'statusCode':
              status ??
              imageStatus[url] ??
              (url.endsWith('404.png') ? 404 : 200),
          'responseBodyLength': bytes.length,
        }),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected fixture API ${invocation.memberName}');
}

Map<String, dynamic> _page(String name, {String host = 'fixture.invalid'}) => {
  'id': name,
  'path': name,
  'url': 'https://$host/$name',
};

Map<String, dynamic> _routedChapter(String key, List<String> names) => {
  'comicId': _payload.comicId,
  'chapterId': _payload.chapterRef.requestId,
  'data': {
    'chapter': {
      'id': _payload.chapterRef.logicalKey,
      'logicalKey': _payload.chapterRef.logicalKey,
      'requestId': _payload.chapterRef.requestId,
      'storageChapterId': _payload.chapterRef.storageChapterId,
      'pages': [
        for (final name in names) _page(name, host: 'cdn-$key.example'),
      ],
      'extern': {
        'downloadRoute': {
          'version': 1,
          'key': key,
          'apiHost': '$key.example',
          'imageHost': 'cdn-$key.example',
        },
      },
    },
  },
};

void main() {
  test('legacy or malformed stored chapter completion stays unknown', () {
    final legacy = {'id': 'chapter', 'name': 'Chapter', 'order': 1};
    for (final fields in [
      legacy,
      {...legacy, 'completedAt': 'invalid'},
    ]) {
      final chapter = UnifiedComicDownloadStoredChapter.fromMap(fields);
      expect(chapter.completedAt, isNull);
      expect(chapter.toMap(), isNot(contains('completedAt')));
    }
  });

  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final connectivity = _LifecycleConnectivity();
  final api = _PluginApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
    await workerManager.init(isolatesCount: 1);
  });
  tearDownAll(() async {
    await connectivity.close();
    await workerManager.dispose();
    RustLib.dispose();
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  tearDown(() {
    objectbox.downloadTaskBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
    api.imageRequests.clear();
    api.firstChapterError = null;
    api.chapterRequests = 0;
    api.chapterResponses.clear();
    api.downloadRouteResponses.clear();
    api.downloadRouteRequests.clear();
    api.firstImageStatus.clear();
    api.imageStatus.clear();
    api.firstImageEmpty.clear();
    api.imageBodies.clear();
    api.heldImageUrl = null;
    api.imageEntered = null;
    api.releaseImage = null;
    api.imageResponseReturned = null;
    api.cancellationEntered = null;
    api.releaseCancellation = null;
    api.readGroups.clear();
    api.chapterEntered = null;
    api.releaseChapter = null;
    api.detailChapters = [];
    api.detailRequests.clear();
    api.detailError = null;
    api.expectedRequestId = _payload.chapterRef.requestId;
    api.detailEntered = null;
    api.releaseDetail = null;
    api.failCommitPath = false;
  });

  int startTask([DownloadTaskJson payload = _payload]) =>
      objectbox.downloadTaskBox.put(
        DownloadTask()
          ..isDownloading = true
          ..taskInfo = payload,
      );

  Future<void> run(
    int id, [
    DownloadTaskJson payload = _payload,
    DownloadProgressReporter? reporter,
  ]) async {
    try {
      await unifiedDownloadTask(reporter ?? _Reporter(), payload, taskId: id);
    } finally {
      await const DownloadTaskRepository().flushTaskWrites(payload.taskKey);
    }
  }

  DownloadAssetStore storedPage(String path) => DownloadAssetStore(
    from: _payload.from,
    path: path,
    cartoonId: _payload.comicId,
    chapterId: _payload.chapterRef.chapterId,
    storageChapterId: _payload.chapterRef.storageChapterId,
    pictureType: PictureType.page,
  );

  Future<File> seedPage(
    String path,
    List<int> bytes, {
    bool legacy = false,
  }) async {
    final store = storedPage(path);
    final candidate = legacy
        ? (await store.downloadCandidates()).firstWhere(
            (item) => item.location == DownloadAssetLocation.legacyDownload,
          )
        : await store.canonicalDownloadCandidate();
    final file = File(candidate.path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    return file;
  }

  Future<void> seedReusablePage(String path) async {
    await seedPage(path, [1]);
  }

  Future<File?> savedPageWithBytes(Uint8List bytes) async {
    final bucket = File(
      await storedPage('fixture').canonicalDownloadPath(),
    ).parent;
    if (!await bucket.exists()) return null;
    final expected = sha256.convert(bytes);
    await for (final entry in bucket.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is File &&
          sha256.convert(await entry.readAsBytes()) == expected) {
        return entry;
      }
    }
    return null;
  }

  void setContinuousRetry(bool enabled) {
    final settings = objectbox.userSettingBox.get(1)!;
    final previous = settings.globalSetting;
    settings.globalSetting = previous.copyWith(
      retryDownloadUntilSuccess: enabled,
    );
    objectbox.userSettingBox.put(settings);
    addTearDown(() {
      settings.globalSetting = previous;
      objectbox.userSettingBox.put(settings);
    });
  }

  ({
    List<String> names,
    List<String> aUrls,
    List<String> bUrls,
    Uint8List aFirstBytes,
    List<Uint8List> bBytes,
  })
  configureRoutedPages(
    String prefix,
    int shade, {
    _AlternatePageFailure? alternateFailure,
    bool continuousRetry = false,
  }) {
    setContinuousRetry(continuousRetry);
    final names = ['$prefix-1.png', '$prefix-2.png'];
    final aUrls = [for (final name in names) 'https://cdn-a.example/$name'];
    final bUrls = [for (final name in names) 'https://cdn-b.example/$name'];
    final aFirstBytes = _coloredPng(shade, 15, 30);
    final bBytes = [_coloredPng(20, shade, 40), _coloredPng(10, 15, shade)];
    api.downloadRouteResponses.addAll({
      'a': _routedChapter('a', names),
      'b': _routedChapter('b', names),
    });
    api.imageBodies.addAll({
      aUrls.first: aFirstBytes,
      bUrls.first: bBytes.first,
      if (alternateFailure == null) bUrls.last: bBytes.last,
      if (alternateFailure == _AlternatePageFailure.invalidImage)
        bUrls.last: _invalidImageBody,
    });
    api.imageStatus[aUrls.last] = 503;
    if (alternateFailure == _AlternatePageFailure.missing) {
      api.imageStatus[bUrls.last] = 404;
    }
    return (
      names: names,
      aUrls: aUrls,
      bUrls: bUrls,
      aFirstBytes: aFirstBytes,
      bBytes: bBytes,
    );
  }

  const alternateDeadline = Duration(seconds: 9);
  ({
    int taskId,
    Completer<void> entered,
    Completer<void> release,
    Future<Object?> outcome,
  })
  startRoutedRun(String heldUrl) {
    api.heldImageUrl = heldUrl;
    final entered = api.imageEntered = Completer<void>();
    final release = api.releaseImage = Completer<void>();
    final taskId = startTask();
    final outcome = run(
      taskId,
    ).then<Object?>((_) => null, onError: (Object error) => error);
    return (
      taskId: taskId,
      entered: entered,
      release: release,
      outcome: outcome,
    );
  }

  Future<void> waitForAlternate(
    Completer<void> entered,
    Future<Object?> outcome,
  ) async {
    await Future.any<void>([
      entered.future,
      outcome.then<void>((_) {}),
    ]).timeout(alternateDeadline);
    expect(
      entered.isCompleted,
      isTrue,
      reason: 'The real route-A page failure must request route B.',
    );
  }

  Future<void> settleRoutedRun(
    Completer<void> entered,
    Completer<void> release,
    Future<Object?> outcome,
  ) async {
    if (!entered.isCompleted) {
      triggerDownloadCancelSignal(_payload.taskKey, preserveFiles: true);
    }
    if (!release.isCompleted) release.complete();
    try {
      await outcome.timeout(alternateDeadline);
    } finally {
      clearDownloadCancelSignal(_payload.taskKey);
    }
  }

  void expectRouteFallback() {
    expect(api.downloadRouteRequests.take(2), [
      {'version': 1, 'excluded': []},
      {
        'version': 1,
        'excluded': ['a'],
      },
    ]);
  }

  void expectNoPublication(int taskId) {
    expect(objectbox.unifiedDownloadBox.getAll(), isEmpty);
    expect(objectbox.comicLinkBox.getAll(), isEmpty);
    expect(objectbox.downloadTaskBox.get(taskId)!.isCompleted, isFalse);
  }

  test(
    'a first-save download stops when all album routes are exhausted',
    () async {
      setContinuousRetry(true);
      api.detailError = AnyhowException(
        '{"type":"comic_download_route_unavailable"}',
      );
      final taskId = startTask();
      await expectLater(
        run(taskId),
        throwsA(isA<ComicDownloadRouteUnavailable>()),
      );
      expect(api.detailRequests.single['extern'], {
        'comicDownload': true,
        'chapterId': _payload.chapterRef.requestId,
      });
      expect(api.chapterRequests, 0);
      expect(api.imageRequests, isEmpty);
      expectNoPublication(taskId);
    },
  );

  test('a chapter needing sign-in does not retry or publish', () async {
    setContinuousRetry(true);
    api.firstChapterError = AnyhowException(
      '{"type":"unauthorized","message":"Sign in to continue"}',
    );
    api.chapterResponse = {
      'chapter': {'epId': 'selected', 'docs': []},
    };
    final taskId = startTask();
    await expectLater(
      run(taskId),
      throwsA(isA<PluginLoginRequiredException>()),
    );
    expect(api.chapterRequests, 1);
    expectNoPublication(taskId);
  });

  test('a forbidden page does not retry or masquerade as missing', () async {
    setContinuousRetry(true);
    final page = _page('forbidden.png');
    final url = page['url'] as String;
    api.firstImageStatus[url] = 403;
    api.chapterResponse = {
      'chapter': {
        'epId': 'selected',
        'docs': [page],
      },
    };
    final taskId = startTask();
    await expectLater(run(taskId), throwsA(isA<DownloadImageJobException>()));
    expect(api.imageRequests, [url]);
    expectNoPublication(taskId);
  });

  for (final (status, reason) in [
    (429, ComicDownloadRetryReason.rateLimited),
    (503, ComicDownloadRetryReason.sourceUnavailable),
    (408, ComicDownloadRetryReason.timeout),
    (404, null),
    (401, null),
  ]) {
    test('fixed routed page HTTP $status never switches lines', () async {
      final fixture = configureRoutedPages(
        'fixed-$status',
        130,
        continuousRetry: true,
      );
      final routed = api.downloadRouteResponses['a']!;
      final chapter = (routed['data'] as Map)['chapter'] as Map;
      (chapter['extern'] as Map)['downloadRoute']['canSwitch'] = false;
      api.imageStatus[fixture.aUrls.last] = status;
      final taskId = startTask();
      await expectLater(
        run(taskId),
        throwsA(
          reason == null
              ? isA<ComicDownloadRouteUnavailable>()
              : isA<ComicDownloadRetryDeferred>().having(
                  (error) => error.reason,
                  'reason',
                  reason,
                ),
        ),
      );
      expect(api.downloadRouteRequests, hasLength(1));
      expect(api.imageRequests.where(fixture.bUrls.contains), isEmpty);
      expectNoPublication(taskId);
    });
  }

  test('a temporary automatic route exhaustion returns to the queue', () async {
    final fixture = configureRoutedPages(
      'automatic-exhausted',
      130,
      continuousRetry: true,
    );
    api.downloadRouteResponses.remove('b');
    final taskId = startTask();
    await expectLater(
      run(taskId),
      throwsA(
        isA<ComicDownloadRetryDeferred>().having(
          (error) => error.reason,
          'reason',
          ComicDownloadRetryReason.sourceUnavailable,
        ),
      ),
    );
    expect(api.downloadRouteRequests, hasLength(2));
    expect(await savedPageWithBytes(fixture.aFirstBytes), isNotNull);
    expectNoPublication(taskId);
  });

  test('source-declared terminal HTTP 503 does not defer', () async {
    setContinuousRetry(true);
    api.firstChapterError = AnyhowException(
      '{"type":"comic_detail_error","reason":"sourceUnavailable",'
      '"httpStatus":503,"retryable":false}',
    );
    final taskId = startTask();
    await expectLater(
      run(taskId),
      throwsA(isA<ComicDownloadRouteUnavailable>()),
    );
    expect(api.chapterRequests, 1);
    expectNoPublication(taskId);
  });

  test('a forbidden optional cover is skipped without retrying', () async {
    const url = 'https://fixture.invalid/cover-forbidden.png';
    api.firstImageStatus[url] = 403;
    expect(
      await downloadCoverAsset(
        from: _payload.from,
        url: url,
        path: 'cover-forbidden.png',
        cartoonId: _payload.comicId,
        qjsName: _payload.from,
        qjsTaskGroupKey: _payload.taskKey,
        shouldRetryUntilSuccess: () => true,
      ),
      '404',
    );
    expect(api.imageRequests, [url]);
  });

  test('a temporary image outage still retries the same page', () async {
    final page = _page('temporary.png');
    final url = page['url'] as String;
    api.firstImageStatus[url] = 503;
    api.imageBodies[url] = _png;
    api.chapterResponse = {
      'chapter': {
        'epId': 'selected',
        'docs': [page],
      },
    };
    final taskId = startTask();
    await run(taskId);
    expect(api.imageRequests, [url, url]);
    expect(api.detailRequests.single['extern'], {
      'comicDownload': true,
      'chapterId': _payload.chapterRef.requestId,
    });
    for (final call in [
      'getComicDetail',
      'getChapter',
      'getDownloadConcurrency',
    ]) {
      expect(api.readGroups[call], _payload.taskKey);
    }
    expect(objectbox.downloadTaskBox.get(taskId)!.isCompleted, isTrue);
  });

  test(
    'routed chapter restarts same-named pages on an alternate without mixing old bytes',
    () async {
      final fixture = configureRoutedPages(
        'route-complete',
        120,
        continuousRetry: true,
      );
      final legacy = await seedPage(fixture.names.first, _png, legacy: true);
      final (:taskId, :entered, :release, :outcome) = startRoutedRun(
        fixture.bUrls.last,
      );
      late File originalPartial;
      try {
        await waitForAlternate(entered, outcome);
        expectRouteFallback();
        expect(api.imageRequests.where((url) => url == fixture.aUrls.first), [
          fixture.aUrls.first,
        ]);
        expect(api.imageRequests, contains(fixture.aUrls.last));
        expect(
          api.imageRequests.where((url) => fixture.bUrls.contains(url)),
          fixture.bUrls,
        );
        final savedOriginal = await savedPageWithBytes(fixture.aFirstBytes);
        expect(savedOriginal, isNotNull, reason: 'A wrote its first page.');
        originalPartial = savedOriginal!;
        final alternatePartial = await savedPageWithBytes(fixture.bBytes.first);
        expect(alternatePartial, isNotNull);
        expect(originalPartial.path, isNot(alternatePartial!.path));
        expect(await legacy.readAsBytes(), _png);
        expectNoPublication(taskId);
      } finally {
        await settleRoutedRun(entered, release, outcome);
      }
      expect(await outcome, isNull);
      expect(api.downloadRouteRequests, hasLength(2));

      final committed = objectbox.unifiedDownloadBox.getAll().single;
      final chapter = resolveStoredDownloadChapters(committed).single;
      final task = objectbox.downloadTaskBox.get(taskId)!;
      expect(task.isCompleted, isTrue);
      expect(task.taskInfo!.completedImages, fixture.bBytes.length);
      expect(task.taskInfo!.reusedImages, 0);
      expect(chapter.logicalKey, _payload.chapterRef.logicalKey);
      expect(chapter.storageChapterId, _payload.chapterRef.storageChapterId);
      expect(chapter.downloadApiHost, 'b.example');
      expect(chapter.downloadImageHost, 'cdn-b.example');
      expect(chapter.completedAt, isNotNull);
      expect(
        chapter.completedAt!.millisecondsSinceEpoch,
        committed.downloadedAt.millisecondsSinceEpoch,
      );
      expect(
        resolveStoredDownloadChaptersFromJson(
          chaptersJson: '[]',
          detailJson: committed.detailJson,
        ).single.completedAt,
        chapter.completedAt,
      );
      expect(committed.chapters, isNot(contains('https://cdn-b.example/')));
      expect(chapter.images.map((page) => page.id), fixture.names);
      expect(chapter.images.map((page) => page.path).toSet(), hasLength(2));
      expect(
        chapter.images.map((page) => page.path),
        everyElement(isNot(isIn(fixture.names))),
      );
      expect(
        chapter.images.every((page) => page.extern['downloadSkipped'] != true),
        isTrue,
      );
      expect(objectbox.comicLinkBox.getAll(), hasLength(1));

      final details = EpisodeDownloadController()
        ..attach(
          from: _payload.from,
          comicId: _payload.comicId,
          comicTitle: _payload.comicName,
          allowDownload: true,
        );
      addTearDown(details.dispose);
      expect(
        details.isDownloaded(
          const DownloadChapterAdapter().fromTaskRef(_payload.chapterRef),
        ),
        isTrue,
      );
      final offline = await getPluginInfoFromLocal(
        _payload.from,
        _payload.comicId,
        _payload.chapterRef.order,
        chapterKey: _payload.chapterRef.logicalKey,
      );
      expect(
        offline.docs.map((doc) => doc.path),
        chapter.images.map((page) => page.path),
      );
      expect(offline.docs.map((doc) => doc.fileServer), everyElement(isEmpty));
      for (var index = 0; index < offline.docs.length; index++) {
        final path = await storedPage(
          offline.docs[index].path,
        ).canonicalDownloadPath();
        expect(path, isNot(originalPartial.path));
        final bytes = await File(path).readAsBytes();
        expect(bytes, fixture.bBytes[index]);
        expect(image.decodePng(bytes), isNotNull);
      }
    },
  );

  for (final (index, failure) in _AlternatePageFailure.values.indexed) {
    test(
      'routed chapter keeps the legacy index and partial when B returns ${failure.description}',
      () async {
        final fixture = configureRoutedPages(
          'route-incomplete-${failure.name}',
          153 + index,
          alternateFailure: failure,
        );
        final legacyPath = 'route-incomplete-${failure.name}-previous.png';
        final previousFile = await seedPage(legacyPath, _png, legacy: true);
        final stored = {
          'id': _payload.chapterRef.storageChapterId,
          'logicalKey': _payload.chapterRef.logicalKey,
          'taskChapterId': _payload.chapterRef.requestId,
          'storageChapterId': _payload.chapterRef.storageChapterId,
          'name': _payload.chapterRef.title,
          'order': _payload.chapterRef.order,
          'completedAt': '2026-10-01T05:00:00.000Z',
          'images': [
            {'path': legacyPath, 'id': 'previous-page'},
          ],
        };
        final previous =
            createTestDownload(
                buildDownloadTaskKey(_payload.from, _payload.comicId),
              )
              ..source = _payload.from
              ..comicId = _payload.comicId
              ..chapters = jsonEncode([stored])
              ..detailJson = jsonEncode({
                ..._normalDetail([]),
                'extern': {
                  'downloadChapters': [stored],
                },
              });
        final previousId = objectbox.unifiedDownloadBox.put(previous);
        final (:taskId, :entered, :release, :outcome) = startRoutedRun(
          fixture.bUrls.last,
        );
        late File originalPartial;
        try {
          await waitForAlternate(entered, outcome);
          expectRouteFallback();
          final savedOriginal = await savedPageWithBytes(fixture.aFirstBytes);
          expect(savedOriginal, isNotNull, reason: 'A wrote its first page.');
          originalPartial = savedOriginal!;
          expect(await previousFile.readAsBytes(), _png);
          final visible = objectbox.unifiedDownloadBox.get(previousId)!;
          expect(visible.chapters, previous.chapters);
          expect(visible.detailJson, previous.detailJson);
          expect(objectbox.downloadTaskBox.get(taskId)!.isCompleted, isFalse);
        } finally {
          await settleRoutedRun(entered, release, outcome);
        }
        expect(await outcome, isA<ComicDownloadRouteUnavailable>());
        expect(api.downloadRouteRequests.length, lessThanOrEqualTo(3));
        expect(await originalPartial.readAsBytes(), fixture.aFirstBytes);
        expect(await previousFile.readAsBytes(), _png);
        expect(await savedPageWithBytes(_invalidImageBody), isNull);
        final visible = objectbox.unifiedDownloadBox.get(previousId)!;
        expect(visible.chapters, previous.chapters);
        expect(visible.detailJson, previous.detailJson);
        expect(
          resolveStoredDownloadChapters(visible).single.completedAt,
          DateTime.utc(2026, 10, 1, 5),
        );
        expect(objectbox.downloadTaskBox.get(taskId)!.isCompleted, isFalse);
        expect(objectbox.comicLinkBox.getAll(), isEmpty);
        final offline = await getPluginInfoFromLocal(
          _payload.from,
          _payload.comicId,
          _payload.chapterRef.order,
          chapterKey: _payload.chapterRef.logicalKey,
        );
        expect(offline.docs.single.path, legacyPath);
        final candidate = await storedPage(
          offline.docs.single.path,
        ).findExistingDownload();
        expect(candidate?.path, previousFile.path);
      },
    );
  }

  test(
    'routed chapter cancellation fences a late alternate response',
    () async {
      final fixture = configureRoutedPages('route-cancelled', 178);
      final returned = api.imageResponseReturned = Completer<void>();
      final (:taskId, :entered, :release, :outcome) = startRoutedRun(
        fixture.bUrls.last,
      );
      try {
        await waitForAlternate(entered, outcome);
        expectRouteFallback();
        triggerDownloadCancelSignal(_payload.taskKey, preserveFiles: true);
        expect(
          await outcome.timeout(alternateDeadline),
          isA<DownloadTaskCancelledException>(),
        );
        expect(returned.isCompleted, isFalse);

        release.complete();
        await returned.future.timeout(alternateDeadline);
        expect(await savedPageWithBytes(fixture.aFirstBytes), isNotNull);
        expect(await savedPageWithBytes(fixture.bBytes.first), isNotNull);
        expect(await savedPageWithBytes(fixture.bBytes.last), isNull);
        expectNoPublication(taskId);
        expect(api.downloadRouteRequests, hasLength(2));
      } finally {
        await settleRoutedRun(entered, release, outcome);
      }
    },
  );

  test('routed chapter resumes the exact alternate plan after pause', () async {
    final fixture = configureRoutedPages('route-resumed', 194);
    final queue = DownloadQueueManager.instance;
    final box = objectbox.downloadTaskBox;
    final settings = objectbox.userSettingBox.get(1)!;
    final previous = settings.globalSetting;
    settings.globalSetting = previous.copyWith(downloadCompletionNotice: 'off');
    objectbox.userSettingBox.put(settings);
    addTearDown(() {
      settings.globalSetting = previous;
      objectbox.userSettingBox.put(settings);
    });

    api.heldImageUrl = fixture.bUrls.last;
    final entered = api.imageEntered = Completer<void>();
    final release = api.releaseImage = Completer<void>();
    final returned = api.imageResponseReturned = Completer<void>();
    final taskId = box.put(
      DownloadTask()
        ..comicId = _payload.comicId
        ..comicName = _payload.comicName
        ..taskInfo = _payload.copyWith(stateCode: 'queued', attempt: 0),
    );
    DownloadTask row() => box.get(taskId)!;
    final completed = Completer<void>();
    final progress = queue.progressStream.listen((event) {
      if (event.isCompleted && !completed.isCompleted) completed.complete();
    });
    addTearDown(progress.cancel);

    queue.watchTasks();
    try {
      await entered.future.timeout(alternateDeadline);
      expectRouteFallback();
      final original = await savedPageWithBytes(fixture.bBytes.first);
      expect(original, isNotNull, reason: 'The first B page was on disk.');
      expect(row().taskInfo!.attempt, 1);
      expect(queue.pauseTasks([row()]), 1);
      final paused = row().taskInfo!;
      expect(paused.stateCode, 'paused');
      expect(paused.phaseCode, 'userPaused');
      final retained = await Future.wait(
        paused.imagePaths.map(
          (path) => storedPage(path).canonicalDownloadPath(),
        ),
      );
      expect(retained, contains(original!.path));
      expectNoPublication(taskId);

      await queue.resumeTasks([row()]).timeout(alternateDeadline);
      await completed.future.timeout(alternateDeadline);
      expect(returned.isCompleted, isFalse);
      expect(api.imageRequests.where((url) => url == fixture.aUrls.last), [
        fixture.aUrls.last,
        fixture.aUrls.last,
      ]);
      expect(api.imageRequests.where(fixture.bUrls.contains), [
        fixture.bUrls.first,
        fixture.bUrls.last,
        fixture.bUrls.last,
      ]);
      expect(api.downloadRouteRequests, [
        {'version': 1, 'excluded': []},
        {
          'version': 1,
          'excluded': ['a'],
        },
        {'version': 1, 'excluded': []},
        {
          'version': 1,
          'excluded': ['a'],
        },
      ]);
      final task = row();
      expect(task.isCompleted, isTrue);
      expect(task.taskInfo!.attempt, 2);
      expect(task.taskInfo!.completedImages, 2);
      expect(task.taskInfo!.reusedImages, 1);
      final record = objectbox.unifiedDownloadBox.getAll().single;
      final chapter = resolveStoredDownloadChapters(record).single;
      final reused = await storedPage(
        chapter.images.first.path,
      ).canonicalDownloadPath();
      expect(reused, original.path);
      expect(await File(reused).readAsBytes(), fixture.bBytes.first);
    } finally {
      queue.stopWatchingTasks();
      final pending = queue.pendingComicWorkerStop(
        from: _payload.from,
        comicId: _payload.comicId,
      );
      if (pending != null && row().isDownloading) queue.pauseTasks([row()]);
      release.complete();
      if (entered.isCompleted) await returned.future.timeout(alternateDeadline);
      if (pending != null) await pending.timeout(alternateDeadline);
    }
  });

  test('routed chapter rejects an alternate with only an echoed ID', () async {
    final fixture = configureRoutedPages('route-echoed', 209);
    final alternate = api.downloadRouteResponses['b']!;
    final data = alternate['data'] as Map<String, dynamic>;
    final chapter = data['chapter'] as Map<String, dynamic>;
    chapter.remove('id');
    chapter.remove('logicalKey');

    final taskId = startTask();
    await expectLater(run(taskId), throwsA(isA<Exception>()));
    expectRouteFallback();
    expect(api.imageRequests.where(fixture.bUrls.contains), isEmpty);
    expect(await savedPageWithBytes(fixture.aFirstBytes), isNotNull);
    expectNoPublication(taskId);
  });

  test('routed chapter exhaustion stops with continuous retry on', () async {
    setContinuousRetry(true);
    api.firstChapterError = AnyhowException(
      '[bundle:chapter-integrity-fixture] Error: '
      '{"type":"comic_download_route_unavailable"}\n'
      '    at getChapter (bundle.cjs:1:1)',
    );
    final page = _page('unexpected-retry-after-route-exhaustion.png');
    api.chapterResponse = {
      'chapter': {
        'epId': _payload.chapterRef.logicalKey,
        'docs': [page],
      },
    };
    api.imageBodies[page['url'] as String] = _png;

    final taskId = startTask();
    await expectLater(
      run(taskId),
      throwsA(isA<ComicDownloadRouteUnavailable>()),
    );
    expect(api.chapterRequests, 1);
    expect(api.imageRequests, isEmpty);
    expectNoPublication(taskId);
  });

  test(
    'stop and delete settles only the selected unfinished attempts',
    () async {
      final fixture = configureRoutedPages('route-stop-delete', 235);
      final queue = DownloadQueueManager.instance;
      final box = objectbox.downloadTaskBox;
      final published = await seedPage('published-before-redownload.png', _png);
      final queuedPage = await seedPage('selected-queued-page.png', _png);
      final pausedPage = await seedPage('selected-paused-page.png', _png);
      final siblingPage = await seedPage('untouched-sibling-page.png', _png);
      final replacedPage = await seedPage('replaced-attempt-page.png', _png);
      final prior =
          createTestDownload(
              buildDownloadTaskKey(_payload.from, _payload.comicId),
            )
            ..source = _payload.from
            ..comicId = _payload.comicId
            ..detailJson = jsonEncode(_normalDetail([]))
            ..chapters = jsonEncode([
              {
                'id': _payload.chapterRef.storageChapterId,
                'logicalKey': _payload.chapterRef.logicalKey,
                'storageChapterId': _payload.chapterRef.storageChapterId,
                'name': _payload.chapterRef.title,
                'order': _payload.chapterRef.order,
                'images': [
                  {
                    'id': 'published-page',
                    'path': 'published-before-redownload.png',
                  },
                ],
              },
            ]);
      final priorId = objectbox.unifiedDownloadBox.put(prior);
      int seed(String key, String path, {bool paused = false}) => box.put(
        DownloadTask()
          ..comicId = _payload.comicId
          ..comicName = _payload.comicName
          ..taskInfo = _payload.copyWith(
            stateCode: paused ? 'paused' : 'queued',
            phaseCode: paused ? 'userPaused' : 'retry',
            attempt: 0,
            chapterRef: _payload.chapterRef.copyWith(logicalKey: key),
            imagePaths: [path],
          ),
      );

      final activeId = seed('selected', 'published-before-redownload.png');
      final queuedId = seed('queued', 'selected-queued-page.png');
      final pausedId = seed('paused', 'selected-paused-page.png', paused: true);
      final siblingId = seed('sibling', 'untouched-sibling-page.png');
      final replacedId = seed(
        'replaced',
        'replaced-attempt-page.png',
        paused: true,
      );
      final stale = box.get(replacedId)!;
      box.put(
        box.get(replacedId)!..taskInfo = stale.taskInfo!.copyWith(attempt: 1),
      );
      final sibling = box.get(siblingId)!;

      api.heldImageUrl = fixture.bUrls.last;
      final entered = api.imageEntered = Completer<void>();
      final release = api.releaseImage = Completer<void>();
      final returned = api.imageResponseReturned = Completer<void>();
      final cancellation = api.cancellationEntered = Completer<void>();
      final releaseCancellation = api.releaseCancellation = Completer<void>();
      Future<ComicTaskDeletionReceipt>? deleting;
      queue.watchTasks();
      try {
        await entered.future.timeout(alternateDeadline);
        queue.stopWatchingTasks();
        final active = box.get(activeId)!;
        expect(active.isDownloading, isTrue);
        expect(active.taskInfo!.attempt, 1);
        expect(await savedPageWithBytes(fixture.bBytes.first), isNotNull);
        deleting = queue.stopAndDeleteTasks([
          active,
          box.get(queuedId)!,
          box.get(pausedId)!,
          stale,
        ]);
        await cancellation.future.timeout(alternateDeadline);
        for (final id in [activeId, queuedId, pausedId]) {
          final stopping = box.get(id)!;
          expect(stopping.taskInfo!.phaseCode, downloadTaskDeletionPhase);
          expect(queue.canResumeTask(stopping), isFalse);
        }
        expect(await savedPageWithBytes(fixture.bBytes.first), isNotNull);
        expect(await queuedPage.exists(), isTrue);

        releaseCancellation.complete();
        final receipt = await deleting.timeout(alternateDeadline);
        expect(receipt.removed, {activeId, queuedId, pausedId});
        expect(receipt.skipped, {replacedId});
        expect(receipt.failures, isEmpty);
        expect(box.get(activeId), isNull);
        expect(box.get(queuedId), isNull);
        expect(box.get(pausedId), isNull);
        expect(box.get(siblingId)!.dbTaskInfoStr, sibling.dbTaskInfoStr);
        expect(box.get(replacedId)!.taskInfo!.attempt, 1);
        expect(await queuedPage.exists(), isFalse);
        expect(await pausedPage.exists(), isFalse);
        expect(await siblingPage.exists(), isTrue);
        expect(await replacedPage.exists(), isTrue);
        expect(await published.readAsBytes(), _png);
        expect(
          objectbox.unifiedDownloadBox.get(priorId)!.chapters,
          prior.chapters,
        );
        expect(await savedPageWithBytes(fixture.aFirstBytes), isNull);
        expect(await savedPageWithBytes(fixture.bBytes.first), isNull);

        expect(returned.isCompleted, isFalse);
        release.complete();
        await returned.future.timeout(alternateDeadline);
        expect(await savedPageWithBytes(fixture.bBytes.last), isNull);
        expect(box.get(activeId), isNull);
        expect(
          objectbox.unifiedDownloadBox.get(priorId)!.chapters,
          prior.chapters,
        );
      } finally {
        queue.stopWatchingTasks();
        if (!releaseCancellation.isCompleted) releaseCancellation.complete();
        if (!release.isCompleted) release.complete();
        if (deleting != null) await deleting.timeout(alternateDeadline);
        if (entered.isCompleted) {
          await returned.future.timeout(alternateDeadline);
        }
        await queue
            .pendingComicWorkerStop(
              from: _payload.from,
              comicId: _payload.comicId,
            )
            ?.timeout(alternateDeadline);
      }
    },
  );

  test(
    'cancel settles a non-UUID chapter while the native call is pending',
    () async {
      final entered = api.chapterEntered = Completer<void>();
      final release = api.releaseChapter = Completer<void>();
      api.chapterResponse = {
        'chapter': {
          'epId': 'selected',
          'docs': [_page('late.png')],
        },
      };
      final taskId = startTask();
      final result = run(
        taskId,
      ).then<Object?>((_) => null, onError: (Object error) => error);
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        expect(api.readGroups['getChapter'], _payload.taskKey);
        triggerDownloadCancelSignal(_payload.taskKey);
        expect(
          await result.timeout(const Duration(seconds: 2)),
          isA<DownloadTaskCancelledException>(),
        );
        expect(api.imageRequests, isEmpty);
        expectNoPublication(taskId);
      } finally {
        release.complete();
        await result;
        clearDownloadCancelSignal(_payload.taskKey);
      }
    },
  );

  test('a pending completion notice does not hold the next chapter', () async {
    final queue = DownloadQueueManager.instance;
    final settings = objectbox.userSettingBox.get(1)!;
    final previousSettings = settings.globalSetting;
    settings.globalSetting = previousSettings.copyWith(
      downloadCompletionNotice: 'episode',
    );
    objectbox.userSettingBox.put(settings);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final noticeStarted = Completer<void>();
    final secondNoticeStarted = Completer<void>();
    final releaseNotice = Completer<void>();
    final notificationIds = <int>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'show') {
        notificationIds.add(call.arguments['id'] as int);
        if (!noticeStarted.isCompleted) {
          noticeStarted.complete();
          await releaseNotice.future;
        } else if (!secondNoticeStarted.isCompleted) {
          secondNoticeStarted.complete();
        }
      }
      return null;
    });
    api.chapterResponse = {
      'data': {
        'chapterId': 'request-id',
        'chapter': {
          'id': 'catalog-id',
          'docs': [_page('cached-notice.png')],
        },
      },
    };
    await seedReusablePage('cached-notice.png');
    final ids = [
      for (final logicalKey in ['selected', 'other'])
        objectbox.downloadTaskBox.put(
          DownloadTask()
            ..comicId = _payload.comicId
            ..comicName = _payload.comicName
            ..taskInfo = _payload.copyWith(
              stateCode: 'queued',
              chapterRef: _payload.chapterRef.copyWith(logicalKey: logicalKey),
            ),
        ),
    ];
    final complete = queue.progressStream
        .where((progress) => progress.isCompleted)
        .take(2)
        .toList();
    ResourceDownloadNotifications.instance.enableDelivery();
    queue.watchTasks();
    try {
      await noticeStarted.future.timeout(const Duration(seconds: 3));
      await complete.timeout(const Duration(seconds: 2));
      await secondNoticeStarted.future.timeout(const Duration(seconds: 2));
      expect(notificationIds.toSet(), hasLength(2));
      expect(
        ids.map(objectbox.downloadTaskBox.get).map((row) => row!.isCompleted),
        [true, true],
      );
    } finally {
      releaseNotice.complete();
      await complete.timeout(const Duration(seconds: 3));
      queue.stopWatchingTasks();
      messenger.setMockMethodCallHandler(channel, null);
      settings.globalSetting = previousSettings;
      objectbox.userSettingBox.put(settings);
    }
  });

  test('retrying a source pause sends only the new work notice', () async {
    final queue = DownloadQueueManager.instance;
    final registry = PluginRegistryService.I;
    final now = DateTime.utc(2026);
    await registry.init();
    await registry.upsert(
      PluginInfo(
        uuid: _payload.from,
        version: '1.0.0',
        originScript: 'fixture bundle',
        insertedAt: now,
        updatedAt: now,
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: false,
      ),
    );
    final settings = objectbox.userSettingBox.get(1)!;
    final previousSettings = settings.globalSetting;
    settings.globalSetting = previousSettings.copyWith(
      downloadCompletionNotice: 'work',
    );
    objectbox.userSettingBox.put(settings);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final delivered = Completer<void>();
    var notices = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'show') {
        notices++;
        if (!delivered.isCompleted) delivered.complete();
      }
      return null;
    });
    api.chapterResponse = {
      'data': {
        'chapterId': 'request-id',
        'chapter': {
          'id': 'catalog-id',
          'docs': [_page('paused-notice.png')],
        },
      },
    };
    await seedReusablePage('paused-notice.png');
    queue.addTask(_payload.copyWith(stateCode: 'queued', attempt: 0));
    final taskId = objectbox.downloadTaskBox.getAll().single.id;
    try {
      await registry.setEnabled(_payload.from, false, initialize: false);
      expect(
        objectbox.downloadTaskBox.get(taskId)!.taskInfo!.stateCode,
        'paused',
      );
      await registry.setEnabled(_payload.from, true, initialize: false);
      await queue.retryTask(taskId);
      final completed = queue.progressStream.firstWhere(
        (progress) => progress.isCompleted,
      );
      ResourceDownloadNotifications.instance.enableDelivery();
      queue.watchTasks();
      await completed.timeout(const Duration(seconds: 5));
      await delivered.future.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(notices, 1);
    } finally {
      queue.stopWatchingTasks();
      messenger.setMockMethodCallHandler(channel, null);
      settings.globalSetting = previousSettings;
      objectbox.userSettingBox.put(settings);
    }
  });

  test('an empty plugin chapter cannot publish an offline resource', () async {
    api.chapterResponse = {
      'data': {
        'chapter': {'id': 'selected', 'pages': []},
      },
    };
    final taskId = startTask();
    await expectLater(run(taskId), throwsFormatException);
    expectNoPublication(taskId);
    expect(api.imageRequests, isEmpty);
  });

  test('a chapter of missing pages cannot be marked complete', () async {
    api.chapterResponse = {
      'chapter': {
        'epId': 'selected',
        'docs': [_page('404.png'), _page('another-404.png')],
      },
    };
    final taskId = startTask();
    await expectLater(run(taskId), throwsA(isA<DownloadImageJobException>()));
    expectNoPublication(taskId);
    expect(api.imageRequests, hasLength(1));
  });

  test('an empty success must recover before publishing the chapter', () async {
    await seedReusablePage('reused.png');
    final page = _page('temporary-empty.png');
    final url = page['url'] as String;
    api.firstImageEmpty.add(url);
    api.imageBodies[url] = _png;
    api.chapterResponse = {
      'chapter': {
        'epId': 'selected',
        'docs': [_page('reused.png'), page],
      },
    };
    final taskId = startTask();
    await run(taskId);

    expect(api.imageRequests, [url, url]);
    final record = objectbox.unifiedDownloadBox.getAll().single;
    final chapter = resolveStoredDownloadChapters(record).single;
    expect(chapter.images.map((image) => image.extern['downloadSkipped']), [
      null,
      null,
    ]);
    expect(objectbox.downloadTaskBox.get(taskId)!.isCompleted, isTrue);
    expect(objectbox.comicLinkBox.getAll(), hasLength(1));
  });

  test('persistent empty pages keep a partial chapter unpublished', () async {
    setContinuousRetry(true);
    final saved = _page('saved.png');
    final empty = _page('persistent-empty.png');
    final savedUrl = saved['url'] as String;
    final emptyUrl = empty['url'] as String;
    api.imageBodies[savedUrl] = _png;
    api.chapterResponse = {
      'chapter': {
        'epId': 'selected',
        'docs': [saved, empty],
      },
    };
    final taskId = startTask();
    await expectLater(
      run(taskId).timeout(const Duration(seconds: 8)),
      throwsA(isA<DownloadImageJobException>()),
    );
    expectNoPublication(taskId);
    expect(api.imageRequests.where((url) => url == emptyUrl), hasLength(4));

    api.imageBodies[emptyUrl] = _png;
    final nextAttempt = _payload.copyWith(attempt: _payload.attempt + 1);
    final task = objectbox.downloadTaskBox.get(taskId)!..taskInfo = nextAttempt;
    objectbox.downloadTaskBox.put(task);
    await run(taskId, nextAttempt);

    expect(api.imageRequests.where((url) => url == savedUrl), [savedUrl]);
    final record = objectbox.unifiedDownloadBox.getAll().single;
    expect(resolveStoredDownloadChapters(record).single.images, hasLength(2));
    expect(objectbox.downloadTaskBox.get(taskId)!.isCompleted, isTrue);
    expect(objectbox.comicLinkBox.getAll(), hasLength(1));
  });

  test(
    'account change pauses the owned attempt before late image publication',
    () async {
      final queue = DownloadQueueManager.instance;
      final held = _page('old-account.png');
      api.heldImageUrl = held['url'] as String;
      api.imageBodies[api.heldImageUrl!] = _png;
      final entered = api.imageEntered = Completer<void>();
      final release = api.releaseImage = Completer<void>();
      api.chapterResponse = {
        'chapter': {
          'epId': 'selected',
          'docs': [held],
        },
      };
      final taskId = objectbox.downloadTaskBox.put(
        DownloadTask()
          ..comicId = _payload.comicId
          ..comicName = _payload.comicName
          ..taskInfo = _payload.copyWith(stateCode: 'queued', attempt: 0),
      );
      int? owner;
      try {
        queue.watchTasks();
        await entered.future.timeout(const Duration(seconds: 5));
        owner = pluginSessionWriteFence.beginSessionChange(_payload.from);
        final paused = objectbox.downloadTaskBox.get(taskId)!;
        expect(paused.isDownloading, isFalse);
        expect(paused.taskInfo!.stateCode, 'paused');
        expect(paused.taskInfo!.phaseCode, 'sessionChanged');
        release.complete();
        await queue
            .pendingComicWorkerStop(
              from: _payload.from,
              comicId: _payload.comicId,
            )
            ?.timeout(const Duration(seconds: 5));
        expectNoPublication(taskId);
        expect(
          objectbox.downloadTaskBox.get(taskId)!.taskInfo!.stateCode,
          'paused',
        );
      } finally {
        queue.stopWatchingTasks();
        if (!release.isCompleted) release.complete();
        if (owner != null) pluginSessionWriteFence.seal(_payload.from, owner);
      }
    },
  );

  test('resuming after a background outage reuses saved pages once', () async {
    const deadline = Duration(seconds: 5);
    final queue = DownloadQueueManager.instance;
    final saved = _page('saved-before-background.png');
    final held = _page('in-flight-at-background.png');
    final savedUrl = saved['url'] as String;
    final heldUrl = held['url'] as String;
    api.imageBodies.addAll({savedUrl: _png, heldUrl: _png});
    api.heldImageUrl = heldUrl;
    final entered = api.imageEntered = Completer<void>();
    final release = api.releaseImage = Completer<void>();
    api.chapterResponse = {
      'chapter': {
        'epId': 'selected',
        'docs': [saved, held],
      },
    };
    final taskId = objectbox.downloadTaskBox.put(
      DownloadTask()
        ..comicId = _payload.comicId
        ..comicName = _payload.comicName
        ..taskInfo = _payload.copyWith(stateCode: 'queued', attempt: 0),
    );
    final complete = Completer<void>();
    var completions = 0;
    final progress = queue.progressStream.listen((event) {
      if (!event.isCompleted) return;
      completions++;
      if (!complete.isCompleted) complete.complete();
    });
    Future<void> waitForQueueToSettle() async {
      final end = DateTime.now().add(deadline);
      while (queue.isProcessing && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(queue.isProcessing, isFalse);
    }

    try {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      queue.watchTasks();
      await entered.future.timeout(deadline);
      expect(api.imageRequests, [savedUrl, heldUrl]);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      connectivity.set(ConnectivityResult.none);
      await waitForQueueToSettle();
      final waiting = objectbox.downloadTaskBox.get(taskId)!;
      expect(waiting.taskInfo!.phaseCode, 'waitingNetwork');
      expect(waiting.taskInfo!.attempt, 1);
      expectNoPublication(taskId);

      // iOS may miss the transport event while suspended. The foreground
      // connectivity read alone must be enough to start the next attempt.
      connectivity.wifiOnRefresh = true;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await complete.future.timeout(deadline);
      release.complete();
      await waitForQueueToSettle();

      expect(api.imageRequests, [savedUrl, heldUrl, heldUrl]);
      expect(completions, 1);
      expect(objectbox.downloadTaskBox.get(taskId)!.taskInfo!.attempt, 2);
      final record = objectbox.unifiedDownloadBox.getAll().single;
      expect(resolveStoredDownloadChapters(record).single.images, hasLength(2));
      expect(objectbox.comicLinkBox.getAll(), hasLength(1));
    } finally {
      queue.stopWatchingTasks();
      if (!release.isCompleted) release.complete();
      connectivity.wifiOnRefresh = false;
      connectivity.set(ConnectivityResult.wifi);
      await progress.cancel();
    }
  });

  test(
    'iOS backgrounding queues the active chapter and resumes without repeating saved pages',
    () async {
      const deadline = Duration(seconds: 5);
      final queue = DownloadQueueManager.instance;
      final saved = _page('saved-before-ios-background.png');
      final held = _page('in-flight-at-ios-background.png');
      final savedUrl = saved['url'] as String;
      final heldUrl = held['url'] as String;
      api.imageBodies.addAll({savedUrl: _png, heldUrl: _png});
      api.heldImageUrl = heldUrl;
      final entered = api.imageEntered = Completer<void>();
      final release = api.releaseImage = Completer<void>();
      api.chapterResponse = {
        'chapter': {
          'epId': 'selected',
          'docs': [saved, held],
        },
      };
      final taskId = objectbox.downloadTaskBox.put(
        DownloadTask()
          ..comicId = _payload.comicId
          ..comicName = _payload.comicName
          ..taskInfo = _payload.copyWith(stateCode: 'queued', attempt: 0),
      );
      final complete = Completer<void>();
      var completions = 0;
      final progress = queue.progressStream.listen((event) {
        if (!event.isCompleted) return;
        completions++;
        if (!complete.isCompleted) complete.complete();
      });
      Future<void> waitForQueueToSettle() async {
        final end = DateTime.now().add(deadline);
        while (queue.isProcessing && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(queue.isProcessing, isFalse);
      }

      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        queue.watchTasks();
        await entered.future.timeout(deadline);
        expect(api.imageRequests, [savedUrl, heldUrl]);

        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await waitForQueueToSettle();
        final waiting = objectbox.downloadTaskBox.get(taskId)!;
        expect(waiting.taskInfo!.phaseCode, 'waitingForeground');
        expect(waiting.taskInfo!.stateCode, 'queued');
        expect(api.imageRequests, [savedUrl, heldUrl]);
        expect(waiting.taskInfo!.attempt, 1);
        expectNoPublication(taskId);

        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await complete.future.timeout(deadline);
        release.complete();
        await waitForQueueToSettle();

        expect(api.imageRequests, [savedUrl, heldUrl, heldUrl]);
        expect(completions, 1);
        expect(objectbox.downloadTaskBox.get(taskId)!.taskInfo!.attempt, 2);
        final record = objectbox.unifiedDownloadBox.getAll().single;
        expect(
          resolveStoredDownloadChapters(record).single.images,
          hasLength(2),
        );
        expect(objectbox.comicLinkBox.getAll(), hasLength(1));
      } finally {
        queue.stopWatchingTasks();
        if (!release.isCompleted) release.complete();
        debugDefaultTargetPlatformOverride = null;
        await progress.cancel();
      }
    },
  );

  test(
    'pausing selected chapters settles all rows before stopping the worker',
    () async {
      const deadline = Duration(seconds: 5);
      final queue = DownloadQueueManager.instance;
      final box = objectbox.downloadTaskBox;
      final saved = _page('saved-before-pause.png');
      final held = _page('in-flight-at-pause.png');
      final next = _page('next-chapter.png');
      final savedUrl = saved['url'] as String;
      final heldUrl = held['url'] as String;
      final nextUrl = next['url'] as String;
      api.imageBodies.addAll({savedUrl: _png, heldUrl: _png, nextUrl: _png});
      api.heldImageUrl = heldUrl;
      final imageEntered = api.imageEntered = Completer<void>();
      final releaseImage = api.releaseImage = Completer<void>();
      final cancellationEntered = api.cancellationEntered = Completer<void>();
      final releaseCancellation = api.releaseCancellation = Completer<void>();
      api.chapterResponse = {
        'chapter': {
          'epId': 'catalog-id',
          'docs': [saved, held],
        },
      };
      api.chapterResponses['request-next'] = {
        'chapter': {
          'epId': 'catalog-next',
          'docs': [next],
        },
      };
      final settings = objectbox.userSettingBox.get(1)!;
      final previous = settings.globalSetting;
      settings.globalSetting = previous.copyWith(
        downloadCompletionNotice: 'work',
      );
      objectbox.userSettingBox.put(settings);
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final delivered = Completer<void>();
      var notices = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'show') {
          notices++;
          if (!delivered.isCompleted) delivered.complete();
        }
        return null;
      });

      final ids = [
        for (final key in ['selected', 'next', 'remain-paused', 'untouched'])
          box.put(
            DownloadTask()
              ..comicId = _payload.comicId
              ..comicName = _payload.comicName
              ..taskInfo = _payload.copyWith(
                stateCode: 'queued',
                attempt: 0,
                chapterRef: key == 'selected'
                    ? _payload.chapterRef
                    : DownloadChapterTaskRef(
                        logicalKey: key,
                        chapterId: 'catalog-$key',
                        requestId: 'request-$key',
                        storageChapterId: 'storage-$key',
                        title: key,
                        order: 3,
                      ),
              ),
          ),
      ];
      DownloadTask row(int id) => box.get(id)!;
      final completed = queue.progressStream
          .where((event) => event.isCompleted)
          .take(2)
          .toList();

      ResourceDownloadNotifications.instance.enableDelivery();
      queue.watchTasks();
      try {
        await imageEntered.future.timeout(deadline);
        expect(row(ids.first).isDownloading, isTrue);
        expect(queue.pauseTasks(ids.take(3).map(row)), 3);
        await cancellationEntered.future.timeout(deadline);
        expect(ids.take(3).map((id) => row(id).taskInfo!.phaseCode), [
          'userPaused',
          'userPaused',
          'userPaused',
        ]);
        expect(row(ids.last).taskInfo!.stateCode, 'queued');
        expect(queue.pauseTasks([row(ids.last)]), 1);

        final resumed = queue.resumeTasks(ids.take(2).map(row));
        await Future<void>.delayed(Duration.zero);
        expect(row(ids.first).taskInfo!.stateCode, 'paused');
        expect(row(ids[1]).taskInfo!.stateCode, 'paused');
        expect(api.imageRequests, [savedUrl, heldUrl]);
        releaseCancellation.complete();
        await resumed.timeout(deadline);
        await completed.timeout(deadline);
        await ResourceDownloadNotifications.instance.settle();

        expect(api.imageRequests, [savedUrl, heldUrl, heldUrl, nextUrl]);
        expect(notices, 0);
        expect(ids.map((id) => row(id).taskInfo!.stateCode), [
          'completed',
          'completed',
          'paused',
          'paused',
        ]);
        expect(ids.map((id) => row(id).taskInfo!.attempt), [2, 1, 0, 0]);
        final record = objectbox.unifiedDownloadBox.getAll().single;
        expect(resolveStoredDownloadChapters(record), hasLength(2));
        expect(objectbox.comicLinkBox.getAll(), hasLength(1));
      } finally {
        queue.stopWatchingTasks();
        if (!releaseCancellation.isCompleted) releaseCancellation.complete();
        releaseImage.complete();
        messenger.setMockMethodCallHandler(channel, null);
        settings.globalSetting = previous;
        objectbox.userSettingBox.put(settings);
      }
    },
  );

  test('pause and resume ignore a newer attempt from the same row', () async {
    final queue = DownloadQueueManager.instance;
    final box = objectbox.downloadTaskBox;
    final id = startTask();
    final active = box.get(id)!;
    box.put(active..taskInfo = _payload.copyWith(attempt: 2));
    expect(
      queue.pauseTasks([
        DownloadTask()
          ..id = id
          ..isDownloading = true
          ..taskInfo = _payload,
      ]),
      0,
    );
    expect(box.get(id)!.taskInfo!.attempt, 2);
    expect(queue.pauseTasks([box.get(id)!]), 1);

    final paused = box.get(id)!;
    box.put(
      box.get(id)!
        ..taskInfo = paused.taskInfo!.copyWith(
          attempt: 3,
          completedImages: 1,
          totalImages: 2,
          imagePaths: ['saved.png'],
        ),
    );
    await queue.resumeTasks([paused]);
    expect(box.get(id)!.taskInfo!.stateCode, 'paused');
    expect(box.get(id)!.taskInfo!.attempt, 3);

    await queue.resumeTasks([box.get(id)!]);
    final continued = box.get(id)!.taskInfo!;
    expect(continued.stateCode, 'queued');
    expect(continued.attempt, 3);
    expect(continued.completedImages, 1);
    expect(continued.totalImages, 2);
    expect(continued.imagePaths, ['saved.png']);
  });

  test(
    'deleting a just-paused chapter waits and removes saved pages',
    () async {
      const deadline = Duration(seconds: 5);
      final queue = DownloadQueueManager.instance;
      final box = objectbox.downloadTaskBox;
      final saved = _page('saved-before-removal.png');
      final held = _page('in-flight-at-removal.png');
      final savedUrl = saved['url'] as String;
      final heldUrl = held['url'] as String;
      api.imageBodies.addAll({savedUrl: _png, heldUrl: _png});
      api.heldImageUrl = heldUrl;
      final imageEntered = api.imageEntered = Completer<void>();
      final releaseImage = api.releaseImage = Completer<void>();
      final cancellationEntered = api.cancellationEntered = Completer<void>();
      final releaseCancellation = api.releaseCancellation = Completer<void>();
      api.chapterResponse = {
        'chapter': {
          'epId': 'catalog-id',
          'docs': [saved, held],
        },
      };
      final file = File(
        await DownloadAssetStore(
          from: _payload.from,
          path: saved['path'] as String,
          cartoonId: _payload.comicId,
          chapterId: _payload.chapterRef.chapterId,
          storageChapterId: _payload.chapterRef.storageChapterId,
          pictureType: PictureType.page,
        ).canonicalDownloadPath(),
      );
      final taskId = box.put(
        DownloadTask()
          ..comicId = _payload.comicId
          ..comicName = _payload.comicName
          ..taskInfo = _payload.copyWith(stateCode: 'queued', attempt: 0),
      );
      queue.watchTasks();
      try {
        await imageEntered.future.timeout(deadline);
        final active = box.get(taskId)!;
        expect(active.taskInfo!.imagePaths, isEmpty);
        expect(file.existsSync(), isTrue);
        expect(queue.pauseTasks([active]), 1);
        final paused = box.get(taskId)!.taskInfo!;
        expect(paused.phaseCode, 'userPaused');
        expect(paused.imagePaths, [saved['path'], held['path']]);
        expect(file.existsSync(), isTrue);
        await cancellationEntered.future.timeout(deadline);

        final token = bindChapterDownloadRemoval(
          from: _payload.from,
          comicId: _payload.comicId,
          chapterKey: _payload.chapterKey,
        );
        var settled = false;
        final deletion = const ChapterDownloadRemoval().remove(token).then((_) {
          settled = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final settledBeforeWorkerRelease = settled;
        releaseCancellation.complete();
        await deletion.timeout(deadline);

        expect(settledBeforeWorkerRelease, isFalse);
        expect(box.get(taskId), isNull);
        expect(file.existsSync(), isFalse);
        expect(api.imageRequests, [savedUrl, heldUrl]);
      } finally {
        queue.stopWatchingTasks();
        if (!releaseCancellation.isCompleted) releaseCancellation.complete();
        releaseImage.complete();
      }
    },
  );

  test(
    'an existing cancelled chapter can restart without reviving deleted work',
    () async {
      final queue = DownloadQueueManager.instance;
      final box = objectbox.downloadTaskBox;
      DownloadTask cancelled(String key, {String phase = 'cancelled'}) {
        final task = DownloadTask()
          ..comicId = _payload.comicId
          ..isCompleted = true
          ..taskInfo = _payload.copyWith(
            stateCode: 'cancelled',
            phaseCode: phase,
            chapterRef: _payload.chapterRef.copyWith(logicalKey: key),
            completedImages: 1,
            totalImages: 3,
            imagePaths: ['removed-by-cancel.png'],
          );
        box.put(task);
        return task;
      }

      final restart = cancelled('can-restart');
      final deleted = cancelled('deleted');
      final removing = cancelled('file-removed', phase: 'fileRemoved');
      final old = cancelled('has-new-job');
      final offline = cancelled('already-downloaded');
      final replacement = DownloadTask()
        ..comicId = _payload.comicId
        ..taskInfo = old.taskInfo!.copyWith(stateCode: 'queued', phaseCode: '');
      box.put(replacement);
      box.remove(deleted.id);
      objectbox.unifiedDownloadBox.put(
        createTestDownload(
            buildDownloadTaskKey(_payload.from, _payload.comicId),
          )
          ..source = _payload.from
          ..comicId = _payload.comicId
          ..chapters = jsonEncode([
            {
              'id': 'already-downloaded',
              'images': [
                {'path': 'saved.png'},
              ],
            },
          ]),
      );

      expect(queue.canResumeTask(restart), isTrue);
      expect(queue.canResumeTask(removing), isFalse);
      await queue.resumeTasks([restart, deleted, removing, old, offline]);
      final row = box.get(restart.id)!;
      expect(row.isCompleted, isFalse);
      expect(row.taskInfo!.stateCode, 'queued');
      expect(row.taskInfo!.imagePaths, isEmpty);
      expect(row.taskInfo!.completedImages, 0);
      expect(box.get(deleted.id), isNull);
      expect(box.get(removing.id)!.isCompleted, isTrue);
      expect(box.get(old.id)!.isCompleted, isTrue);
      expect(box.get(offline.id)!.isCompleted, isTrue);
      expect(box.get(replacement.id)!.taskInfo!.stateCode, 'queued');
    },
  );

  test(
    'waiting for a chapter response does not write unchanged progress',
    () async {
      await seedReusablePage('waiting.png');
      api.chapterResponse = {
        'chapter': {
          'epId': 'selected',
          'docs': [_page('waiting.png')],
        },
      };
      final entered = api.chapterEntered = Completer<void>();
      final release = api.releaseChapter = Completer<void>();
      final taskId = startTask();
      final pending = run(taskId);
      await entered.future;
      await const DownloadTaskRepository().flushTaskWrites(_payload.taskKey);
      final changes = <List<Type>>[];
      final subscription = objectbox.store.entityChanges.listen(changes.add);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 1250));
        await const DownloadTaskRepository().flushTaskWrites(_payload.taskKey);
        expect(changes.where((types) => types.contains(DownloadTask)), isEmpty);
        expect(
          objectbox.downloadTaskBox.get(taskId)!.status,
          t.download.statusFetchingChapterInfo,
        );
      } finally {
        await subscription.cancel();
        release.complete();
        await pending;
      }
    },
  );

  test('a failed chapter commit retains the last page checkpoint', () async {
    await seedReusablePage('last.png');
    api.chapterResponse = {
      'chapter': {
        'epId': 'selected',
        'docs': [_page('last.png')],
      },
    };
    final reporter = _Reporter()
      ..setOnUpdate((_, message) {
        if (message == t.download.statusDownloadProgress(percent: 100)) {
          api.failCommitPath = true;
        }
      });
    final taskId = startTask();

    await expectLater(
      run(taskId, _payload, reporter),
      throwsA(isA<FileSystemException>()),
    );
    expectNoPublication(taskId);
    final checkpoint = objectbox.downloadTaskBox.get(taskId)!.taskInfo!;
    expect(checkpoint.phaseCode, 'committingChapter');
    expect(checkpoint.completedImages, 1);
    expect(checkpoint.reusedImages, 1);
    expect(checkpoint.totalImages, 1);
    expect(checkpoint.imagePaths, ['last.png']);
  });

  test(
    'a fallback chapter cannot pass on echoed request, order or storage',
    () async {
      api.chapterResponse = {
        'chapterId': 'request-id',
        'data': {
          'chapter': {
            'id': 'another-chapter',
            'logicalKey': 'another-logical-key',
            'requestId': 'request-id',
            'storageChapterId': 'selected',
            'order': 2,
            'pages': [_page('fallback.png')],
          },
        },
      };
      final taskId = startTask();
      await expectLater(run(taskId), throwsFormatException);
      expectNoPublication(taskId);
      expect(api.imageRequests, isEmpty);
    },
  );

  test(
    'a late catalog refresh cannot restore a removed offline record',
    () async {
      final existing =
          createTestDownload(
              buildDownloadTaskKey(_payload.from, _payload.comicId),
            )
            ..source = _payload.from
            ..comicId = _payload.comicId
            ..detailJson = jsonEncode(_normalDetail([]));
      final recordId = objectbox.unifiedDownloadBox.put(existing);
      api.detailEntered = Completer<void>();
      final releaseDetail = api.releaseDetail = Completer<void>();
      final taskId = startTask();
      final stopped = expectLater(
        run(taskId),
        throwsA(isA<DownloadTaskCancelledException>()),
      );
      try {
        await api.detailEntered!.future.timeout(const Duration(seconds: 5));
        objectbox.downloadTaskBox.remove(taskId);
        objectbox.unifiedDownloadBox.remove(recordId);
      } finally {
        releaseDetail.complete();
      }
      await stopped;
      expect(objectbox.unifiedDownloadBox.getAll(), isEmpty);
      expect(objectbox.comicLinkBox.getAll(), isEmpty);
      expect(api.imageRequests, isEmpty);
    },
  );

  test(
    'an exact legacy chapter alias with a missing page preserves local bytes without publishing',
    () async {
      await seedReusablePage('reused.png');
      api.chapterResponse = {
        'data': {
          'chapter': {
            'id': 'site-id',
            'logicalKey': 'catalog-id',
            'pages': [_page('reused.png'), _page('404.png')],
          },
        },
      };
      final taskId = startTask();
      await expectLater(run(taskId), throwsA(isA<DownloadImageJobException>()));
      expectNoPublication(taskId);
      expect(api.imageRequests, [_page('404.png')['url']]);
    },
  );

  test('a legacy numeric route can use its exact catalog alias', () async {
    await seedReusablePage('legacy.png');
    const legacyRef = DownloadChapterTaskRef(
      order: 2,
      storageChapterId: 'shared-storage',
    );
    final payload = _payload.copyWith(chapterRef: legacyRef);
    api.expectedRequestId = '2';
    api.detailChapters = [
      {'id': 'opaque-id', 'requestId': '2', 'name': 'Selected', 'order': 2},
    ];
    api.chapterResponse = {
      'chapterId': '2',
      'data': {
        'chapter': {
          'id': 'opaque-id',
          'order': 2,
          'pages': [_page('legacy.png')],
        },
      },
    };
    final taskId = startTask(payload);
    await run(taskId, payload);

    expect(objectbox.downloadTaskBox.get(taskId)!.isCompleted, isTrue);
    expect(objectbox.unifiedDownloadBox.getAll(), hasLength(1));
    expect(api.imageRequests, isEmpty);
  });
}
