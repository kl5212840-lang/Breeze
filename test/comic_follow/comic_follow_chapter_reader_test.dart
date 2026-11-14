import 'dart:async';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/comic_follow/comic_follow_chapter_reader.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';

const _copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
const _legacyJm = 'bf99008d-010b-4f17-ac7c-61a9b57dc3d9';
const _newSource = '75ecae02-3d50-4d8f-a3ef-b3dafb517055';
const _declared = {
  'breezeExperience': {'comicFollow': 1},
};

ComicFollow _row({String source = _copy, int known = 10}) {
  final time = DateTime.utc(2026, 11, 12);
  return ComicFollow(
    uniqueKey: '$source:comic',
    source: source,
    comicId: 'comic',
    title: 'Followed work',
    description: '',
    cover: '',
    creator: '',
    titleMeta: '',
    metadata: '',
    lastChapterCount: known,
    detectedChapterCount: known,
    hasUpdate: false,
    updateTime: time,
    deleted: false,
    createdAt: time,
    updatedAt: time,
    schemaVersion: 1,
  );
}

Map<String, dynamic> _response({
  String identity = 'comic',
  Object? snapshot,
  Object eps = const [
    {'id': 'chapter-3', 'name': 'Third', 'order': 3},
    {'id': 'chapter-1', 'name': 'First', 'order': 1},
  ],
}) => {
  'data': {
    'normal': {
      'comicInfo': {'id': identity},
      'eps': eps,
      // A tracking read does not parse or depend on unrelated detail fields.
      'recommend': null,
      'extern': {'comicFollow': ?snapshot},
    },
  },
};

void main() {
  test(
    'Copy opts in to the chapter snapshot; the legacy read uses eps',
    () async {
      final calls = <Map<String, dynamic>?>[];
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        pluginInfo: (_) => _declared,
        read: (source, id, extern) async {
          calls.add(extern);
          expect(id, 'comic');
          return _response(
            snapshot: {
              'chapterCount': 149,
              'latestChapterId': 'chapter-149',
              'latestChapterTitle': 'Latest',
            },
            eps: const [],
          );
        },
      );
      final copy = (await reader.detect(_row()))!;
      expect(calls, [
        {'comicFollow': true},
      ]);
      expect(copy.chapterCount, 149);
      expect(copy.latestChapterTitle, 'Latest');
      expect(copy.latestChapterIds, {'chapter-149'});
      expect(copy.positionOf('chapter-149'), isNull);

      final legacyReader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (source, id, extern) async {
          expect(extern, isNull);
          return _response();
        },
      );
      final legacy = (await legacyReader.detect(_row(source: 'legacy')))!;
      expect(legacy.chapterCount, 2);
      expect(legacy.latestChapterTitle, 'Third');
    },
  );

  test(
    'legacy tracking uses the reader traversal when a chapter has no positive order',
    () async {
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (_, _, _) async => _response(
          eps: const [
            {'id': 'opening', 'name': 'Opening', 'order': 100},
            {
              'id': 'old-ending',
              'logicalKey': 'ending',
              'requestId': 'request-ending',
              'name': 'Ending',
              'order': 0,
            },
          ],
        ),
      );

      final result = (await reader.detect(_row(source: 'legacy', known: 1)))!;
      expect(result.chapterCount, 2);
      expect(result.latestChapterTitle, 'Ending');
      expect(result.latestChapterId, 'ending');
      expect(result.positionOf('request-ending'), 2);
      expect(result.positionOf('old-ending'), 2);
      expect(result.positionOf('opening'), 1);
      expect(result.positionOf('0'), isNull);
    },
  );

  test(
    'an alias shared by distinct chapters cannot confirm either position',
    () async {
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (_, _, _) async => _response(
          eps: const [
            {
              'id': 'shared',
              'logicalKey': 'start',
              'name': 'First',
              'order': 10,
            },
            {
              'id': 'shared',
              'logicalKey': 'end',
              'name': 'Latest',
              'order': 20,
            },
          ],
        ),
      );
      final result = (await reader.detect(_row(source: 'legacy', known: 1)))!;
      expect(result.chapterCount, 2);
      expect(result.positionOf('shared'), isNull);
      expect(result.positionOf('start'), 1);
      expect(result.positionOf('end'), 2);
      expect(result.latestChapterIds, {'end'});
    },
  );

  test(
    'a new UUID opts in by getInfo; unknown contract versions use legacy detail',
    () async {
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        pluginInfo: (source) => source == _newSource
            ? {'data': _declared}
            : {
                'breezeExperience': {'comicFollow': 2},
              },
        read: (source, id, extern) async {
          expect(extern, source == _newSource ? {'comicFollow': true} : null);
          return _response();
        },
      );
      for (final source in [_newSource, 'future-contract']) {
        final result = (await reader.detect(_row(source: source)))!;
        expect(result.chapterCount, 2);
        expect(result.latestChapterTitle, 'Third');
      }
    },
  );

  test(
    'a stuck plugin finishes the check without a second long wait',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        readBudget: Duration.zero,
        read: (_, _, _) {
          calls++;
          return pending.future;
        },
      );
      final result = (await reader.detect(_row()))!;
      expect(result.failure, ComicFollowCheckFailure.network);
      expect(calls, 1);
      pending.complete(_response());
    },
  );

  test(
    'bad identity, incomplete chapters and empty regressions are not updates',
    () async {
      for (final invalid in [
        _response(identity: 'unrelated'),
        _response(
          eps: const [
            {'id': 'bad', 'name': 'Not a chapter'},
          ],
        ),
        _response(eps: const []),
        _response(
          snapshot: {'chapterCount': 1, 'latestChapterTitle': 'Unproven'},
        ),
        {..._response(), 'success': false, 'error': 'do not present raw body'},
      ]) {
        final reader = ComicFollowChapterReader(
          sourceFailure: (_) => null,
          pluginInfo: (_) => _declared,
          read: (_, _, _) async => invalid,
        );
        final result = (await reader.detect(_row()))!;
        expect(result.chapterCount, isNull);
        expect(result.failure, ComicFollowCheckFailure.invalidResponse);
      }
      final legitimatelyEmpty = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (_, _, _) async => _response(eps: const []),
      );
      expect((await legitimatelyEmpty.detect(_row(known: 0)))!.chapterCount, 0);
    },
  );

  test(
    'legacy JM cannot replace a known series with a synthetic single chapter',
    () async {
      final payload = _response(
        eps: const [
          {'id': 'comic', 'name': '第1话', 'order': 1},
        ],
      );
      (payload['data'] as Map<String, dynamic>)['raw'] = {
        'comicInfo': {'series': [], 'total_photos': 48},
      };
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (_, _, extern) async {
          expect(extern, isNull);
          return payload;
        },
      );
      final knownSeries = (await reader.detect(_row(source: _legacyJm)))!;
      expect(knownSeries.failure, ComicFollowCheckFailure.invalidResponse);
      final singleChapter = (await reader.detect(
        _row(source: _legacyJm, known: 1),
      ))!;
      expect(singleChapter.chapterCount, 1);
    },
  );

  test('only positively identified transient errors retry immediately', () async {
    final cases = <(Object, ComicFollowCheckFailure, int)>[
      (
        const SocketException('connection closed'),
        ComicFollowCheckFailure.network,
        2,
      ),
      (
        AnyhowException("[bundle:copy.cjs] unexpected token: 'error'"),
        ComicFollowCheckFailure.invalidResponse,
        1,
      ),
      (
        AnyhowException(
          '[bundle:copy.cjs] {"type":"comic_follow_error","reason":"sourceUnavailable","retryable":false}',
        ),
        ComicFollowCheckFailure.sourceUnavailable,
        1,
      ),
      (
        AnyhowException(
          'HTTPError: Request failed with status code 401: GET https://example.test',
        ),
        ComicFollowCheckFailure.sourceUnavailable,
        1,
      ),
      (
        AnyhowException(
          'HTTPError: Request failed with status code 404: GET https://example.test',
        ),
        ComicFollowCheckFailure.sourceUnavailable,
        1,
      ),
      (
        const PluginLoginRequiredException(
          UnauthorizedPayload(pluginId: _copy, message: 'internal raw text'),
        ),
        ComicFollowCheckFailure.signInRequired,
        1,
      ),
    ];
    for (final (error, reason, count) in cases) {
      var calls = 0, delays = 0;
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => null,
        read: (_, _, _) async {
          calls++;
          throw error;
        },
        delay: (_) async {
          delays++;
        },
      );
      final result = (await reader.detect(_row()))!;
      expect(result.failure, reason);
      expect(result.chapterCount, isNull);
      expect(calls, count);
      expect(delays, count - 1);
    }
  });

  test(
    'a disabled source is not invoked, and invalidated work cannot publish',
    () async {
      var calls = 0;
      ComicFollowCheckFailure? sourceStatus =
          ComicFollowCheckFailure.pluginDisabled;
      final pending = Completer<Map<String, dynamic>>();
      final reader = ComicFollowChapterReader(
        sourceFailure: (_) => sourceStatus,
        read: (_, _, _) {
          calls++;
          return pending.future;
        },
      );
      expect(
        (await reader.detect(_row()))!.failure,
        ComicFollowCheckFailure.pluginDisabled,
      );
      expect(calls, 0);
      sourceStatus = null;
      var active = true;
      final work = reader.detect(_row(), canContinue: () => active);
      expect(calls, 1);
      active = false;
      pending.complete(_response());
      expect(await work, isNull);
    },
  );
}
