import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';

final _home = Uri.parse('https://video.example/');

Map<String, dynamic> _detail(
  String id, {
  String description = '完整简介',
  Uri? home,
}) => {
  'data': {
    'id': id,
    'title': '作品$id',
    'detailUrl': '${home ?? _home}voddetail/$id.html',
    'description': description,
    'genres': '剧情',
    'year': '2026',
    'actors': '演员',
    'sourceViews': 1234,
  },
};

ApiVideoItem _summary(String id) => ApiVideoItem(
  id: id,
  title: '列表作品$id',
  detailUrl: _home.resolve('voddetail/$id.html'),
);

Future<void> _dispatchRequests() => Future<void>.delayed(Duration.zero);

ApiVideoRepository _repository(
  ApiVideoPluginCall call, {
  String source = 'detail-cache',
  Uri? home,
  DateTime Function()? clock,
}) => ApiVideoRepository(
  source: source,
  home: home ?? _home,
  catalogFn: 'list',
  detailFn: 'item',
  playbackFn: 'play',
  pluginCall: call,
  detailClock: clock,
);

void main() {
  test('an explicit failure envelope cannot seed the detail cache', () async {
    var calls = 0;
    final repo = _repository((_, args) async {
      final id = args['id'] as String;
      if (++calls == 1) {
        return {
          ..._detail(id, description: 'Unavailable detail'),
          'ok': false,
          'error': 'https://media.example/private?signature=discard',
        };
      }
      return _detail(id);
    });

    await expectLater(
      repo.item('1'),
      throwsA(
        isA<ApiVideoStageFailure>()
            .having((error) => error.cause, 'cause', isA<FormatException>())
            .having(
              (error) => error.toString(),
              'message',
              isNot(contains('signature')),
            ),
      ),
    );
    expect((await repo.item('1')).description, '完整简介');
    expect(calls, 2);
  });

  test(
    'tapped titles precede pending enrichment and promoted reads deduplicate',
    () async {
      final pending = <String, Completer<Map<String, dynamic>>>{};
      final repo = _repository(
        (_, args) =>
            (pending['${args['id']}'] = Completer<Map<String, dynamic>>())
                .future,
      );
      final first = repo.enrich(_summary('1'));
      final second = repo.enrich(_summary('2'));
      final background = repo.enrich(_summary('3'));
      final promoted = repo.enrich(_summary('4'));
      final tapped = repo.item('5');
      expect(repo.item('4'), same(promoted));
      await _dispatchRequests();
      pending['1']!.complete(_detail('1'));
      await first;
      await _dispatchRequests();
      expect(pending.keys, ['1', '2', '5']);
      pending['2']!.complete(_detail('2'));
      await second;
      await _dispatchRequests();
      expect(pending.keys, ['1', '2', '5', '4']);
      pending['5']!.complete(_detail('5'));
      await tapped;
      await _dispatchRequests();
      expect(pending.keys, ['1', '2', '5', '4', '3']);
      pending['4']!.complete(_detail('4'));
      pending['3']!.complete(_detail('3'));
      await Future.wait([background, promoted]);
    },
  );

  test(
    'browser details use the retained session and a failed read can retry',
    () async {
      const id = '667b4dd8c5ce08e51e654188';
      final home = Uri.parse('https://www.omofuna.com/');
      final url = home.resolve('anime/$id.html');
      var reads = 0, parses = 0;
      final repo = ApiVideoRepository(
        source: 'omo',
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        batchDetailFn: 'batch',
        capabilities: const ApiVideoCapabilities(
          browserDetail: true,
          browserItemPrefix: '/anime/',
        ),
        browserDetailRead: (requested) async {
          expect(requested, url);
          if (++reads == 1) throw TimeoutException('offline');
          return {
            'kind': 'public-detail',
            'url': '$url',
            'html': '<h1>Public work</h1>',
          };
        },
        pluginCall: (path, args) async {
          parses++;
          expect(path, 'item');
          expect(args['browserSnapshot'], isA<Map>());
          expect(args['refresh'], true);
          return _detail(id, home: home);
        },
      );
      await expectLater(repo.item(id), throwsA(isA<TimeoutException>()));
      final value = await repo.item(id, refresh: true);
      expect(await repo.item(id), same(value));
      expect(reads, 2);
      expect(parses, 1);
      expect((await repo.items([id])).single.id, id);
      expect(reads, 3);
      expect(parses, 2);
    },
  );

  test(
    'enrich replaces partial metadata and later summaries cannot overwrite it',
    () async {
      var calls = 0;
      final repo = _repository((_, args) async {
        calls++;
        return _detail('${args['id']}');
      });
      final complete = await repo.enrich(_summary('1'));
      expect(complete.description, '完整简介');
      expect(complete.genres, '剧情');
      expect(complete.actors, '演员');
      expect(complete.sourceViews, 1234);
      expect(await repo.enrich(_summary('1')), same(complete));
      expect(await repo.item('1'), same(complete));
      expect(calls, 1);
    },
  );

  test(
    'same-ID item and enrichment calls share one pending detail request',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      final repo = _repository((_, _) {
        calls++;
        return pending.future;
      });
      final first = repo.item('1'), second = repo.enrich(_summary('1'));
      expect(second, same(first));
      await _dispatchRequests();
      expect(calls, 1);
      pending.complete(_detail('1'));
      expect(await first, same(await second));
    },
  );

  test('all detail IDs share a two-request concurrency limit', () async {
    final pending = <String, Completer<Map<String, dynamic>>>{};
    var active = 0, peak = 0;
    final repo = _repository((_, args) async {
      final id = '${args['id']}';
      active++;
      if (active > peak) peak = active;
      final wait = pending[id] = Completer<Map<String, dynamic>>();
      try {
        return await wait.future;
      } finally {
        active--;
      }
    });
    final futures = [for (var id = 1; id <= 5; id++) repo.item('$id')];
    await _dispatchRequests();
    expect(pending.keys, ['1', '2']);
    for (var id = 1; id <= 5; id++) {
      pending['$id']!.complete(_detail('$id'));
      await futures[id - 1];
      await _dispatchRequests();
    }
    expect(peak, 2);
    expect(active, 0);
    expect(pending.keys, ['1', '2', '3', '4', '5']);
  });

  test(
    'failed and mismatched detail results never poison retry or cache',
    () async {
      var calls = 0;
      final repo = _repository((_, args) async {
        if (++calls == 1) throw TimeoutException('public detail timed out');
        if (calls == 2) return _detail('2');
        return _detail('${args['id']}');
      });
      await expectLater(
        repo.item('1'),
        throwsA(
          isA<ApiVideoStageFailure>().having(
            (error) => error.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );
      await expectLater(repo.item('1'), throwsFormatException);
      final complete = await repo.item('1');
      expect(complete.id, '1');
      expect(await repo.item('1'), same(complete));
      expect(calls, 3);
    },
  );

  test(
    'five-minute TTL expires without being extended by cache hits',
    () async {
      var now = DateTime.utc(2026, 10, 28), calls = 0;
      final repo = _repository((_, args) async {
        calls++;
        return _detail('${args['id']}', description: '版本$calls');
      }, clock: () => now);
      expect((await repo.item('1')).description, '版本1');
      now = now.add(const Duration(minutes: 4, seconds: 59));
      expect((await repo.item('1')).description, '版本1');
      now = now.add(const Duration(seconds: 1));
      expect((await repo.item('1')).description, '版本2');
      expect(calls, 2);
    },
  );

  test('LRU holds 64 details and preserves a recently accessed item', () async {
    final calls = <String, int>{};
    final repo = _repository((_, args) async {
      final id = '${args['id']}';
      calls[id] = (calls[id] ?? 0) + 1;
      return _detail(id);
    });
    for (var id = 1; id <= 64; id++) {
      await repo.item('$id');
    }
    await repo.item('1');
    await repo.item('65');
    await repo.item('1');
    await repo.item('2');
    expect(calls['1'], 1);
    expect(calls['2'], 2);
    expect(calls.values.reduce((a, b) => a + b), 66);
  });

  test(
    'separate repositories never share details even with an identical ID',
    () async {
      var firstCalls = 0, secondCalls = 0, thirdCalls = 0;
      final otherHome = Uri.parse('https://other.example/');
      final first = _repository((_, _) async {
        firstCalls++;
        return _detail('1', description: '一');
      });
      final second = _repository(
        (_, _) async {
          secondCalls++;
          return _detail('1', description: '二', home: otherHome);
        },
        source: 'other-source',
        home: otherHome,
      );
      final third = _repository((_, _) async {
        thirdCalls++;
        return _detail('1', description: '三');
      });
      expect((await first.item('1')).description, '一');
      expect((await second.item('1')).description, '二');
      expect((await third.item('1')).description, '三');
      expect([firstCalls, secondCalls, thirdCalls], [1, 1, 1]);
      await expectLater(second.enrich(_summary('1')), throwsFormatException);
      expect(secondCalls, 1);
    },
  );

  test(
    'refresh bypasses cached data and shares a pending fresh request',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final flags = <bool>[];
      final repo = _repository((_, args) async {
        flags.add(args['refresh'] == true);
        return flags.length == 1
            ? _detail('1', description: '旧')
            : pending.future;
      });
      await repo.item('1');
      final fresh = repo.item('1', refresh: true);
      expect(repo.item('1', refresh: true), same(fresh));
      expect(repo.enrich(_summary('1')), same(fresh));
      pending.complete(_detail('1', description: '新'));
      expect((await fresh).description, '新');
      expect((await repo.item('1')).description, '新');
      expect(flags, [false, true]);
    },
  );

  test('a slower normal response cannot overwrite a newer refresh', () async {
    final old = Completer<Map<String, dynamic>>();
    final fresh = Completer<Map<String, dynamic>>();
    var calls = 0;
    final repo = _repository((_, args) {
      calls++;
      return args['refresh'] == true ? fresh.future : old.future;
    });
    final older = repo.item('1'), newer = repo.item('1', refresh: true);
    fresh.complete(_detail('1', description: '新'));
    await newer;
    old.complete(_detail('1', description: '旧'));
    expect((await older).description, '旧');
    expect((await repo.item('1')).description, '新');
    expect(calls, 2);
  });

  test(
    'a failed refresh cannot resurrect a superseded older request',
    () async {
      final old = Completer<Map<String, dynamic>>();
      final fresh = Completer<Map<String, dynamic>>();
      var calls = 0;
      final repo = _repository((_, args) {
        calls++;
        if (calls > 2) return Future.value(_detail('1', description: '恢复'));
        return args['refresh'] == true ? fresh.future : old.future;
      });
      final older = repo.item('1');
      final failure = expectLater(
        repo.item('1', refresh: true),
        throwsA(
          isA<ApiVideoStageFailure>().having(
            (error) => error.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );
      fresh.completeError(TimeoutException('fresh detail failed'));
      await failure;
      old.complete(_detail('1', description: '过期'));
      await older;
      expect((await repo.item('1')).description, '恢复');
      expect(calls, 3);
    },
  );

  test(
    'a queued ordinary request upgrades to refresh without duplicate work',
    () async {
      final pending = <String, Completer<Map<String, dynamic>>>{};
      final flags = <String, bool>{};
      final repo = _repository((_, args) {
        final id = '${args['id']}';
        flags[id] = args['refresh'] == true;
        return (pending[id] = Completer<Map<String, dynamic>>()).future;
      });
      final first = repo.item('1'), second = repo.item('2');
      final queued = repo.item('3');
      expect(repo.item('3', refresh: true), same(queued));
      await _dispatchRequests();
      pending['1']!.complete(_detail('1'));
      await first;
      await _dispatchRequests();
      expect(flags['3'], isTrue);
      pending['2']!.complete(_detail('2'));
      pending['3']!.complete(_detail('3'));
      await Future.wait([second, queued]);
      expect(flags.length, 3);
    },
  );
}
