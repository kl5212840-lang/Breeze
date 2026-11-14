import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/routing_probe_session.dart';
import 'package:zephyr/page/video/api_video_repository.dart';

const source = 'ccc2fe17-c0a8-4fd8-a596-835772686404';
final home = Uri.parse('https://public.fixture.tv/');
Map<String, dynamic> item() => {
  'id': '42', 'title': 'Public fixture', 'detailUrl': '${home}voddetail/42.html',
  'lines': [for (final line in ['a', 'b']) {
    'id': line, 'label': line, 'episodes': [{
      'id': '1', 'title': 'Episode 1', 'resolveOnPlayback': true,
      'watchUrl': '${home}voddetail/42.html?line=$line&episode=1',
    }],
  }],
};
Map<String, dynamic> info() => {'function': [{
  'action': {'type': 'openVideoLibrary', 'payload': {
    'url': '$home', 'catalogFnPath': 'publicCatalog', 'detailFnPath': 'publicDetail', 'playbackFnPath': 'resolveLine',
  }},
}]};
Map<String, dynamic> media(Map<String, dynamic> args) => {'data': {
  'item': item(), 'lineId': args['lineId'], 'episodeId': args['episodeId'],
  'watchUrl': '${home}voddetail/42.html?line=${args['lineId']}&episode=${args['episodeId']}',
  'sources': [{'url': 'https://cdn-${args['lineId']}.fixture.tv/video.mp4?ephemeral=not-persisted', 'quality': '720p'}],
}};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final partial in [false, true]) {
    test('all declared video lines resolve without a player; partial=$partial preserves the correct snapshot', () async {
      final calls = <String>[];
      final stored = <String>{'previous.fixture.tv'};
      final commits = <bool>[];
      Future<Map<String, dynamic>> call(String fn, Map<String, dynamic> args, Map<String, dynamic> extern) async {
        calls.add('$fn:${args['lineId'] ?? ''}');
        await RoutingObservedMediaDomains.observeHosts(source, ['api.fixture.tv']);
        if (fn == 'publicCatalog') return {'data': {'items': [item()], 'page': 1}};
        if (fn == 'publicDetail') return {'data': item()};
        if (fn == 'resolveLine') {
          if (partial && args['lineId'] == 'b') throw StateError('Fixture resolution failed');
          return media(args);
        }
        throw StateError('Undeclared call');
      }
      final probe = RoutingProbeSession(source: source, info: () async => info(), call: call,
        isCurrent: () => true,
        openVideo: (_) async => RoutingProbeVideoAccess(repository: ApiVideoRepository(
          source: source, home: home, catalogFn: 'publicCatalog', detailFn: 'publicDetail', playbackFn: 'resolveLine',
          pluginCall: (fn, args) => call(fn, args, const {}))),
        commit: ({required source, required domains, required complete}) async {
          commits.add(complete);
          if (complete) stored.clear();
          stored.addAll(domains);
        });
      try {
        final result = await probe.run();
        expect(calls.where((call) => call.startsWith('resolveLine:')), ['resolveLine:a', 'resolveLine:b']);
        expect(result.totalLines, 2);
        expect(result.lines, partial ? 1 : 2);
        expect(result.failed, partial ? 1 : 0);
        expect(result.complete, !partial);
        expect(commits, [!partial]);
        expect(stored.contains('previous.fixture.tv'), partial);
        expect(stored, contains('cdn-a.fixture.tv'));
        if (!partial) expect(stored, contains('cdn-b.fixture.tv'));
        expect(stored.every((host) => !host.contains('?') && !host.contains('/')), isTrue);
      } finally { probe.dispose(); }
    });
  }

  test('cancel before a late resolver result never commits or falls back to passive persistence', () async {
    final pending = Completer<Map<String, dynamic>>();
    final entered = Completer<void>();
    var commits = 0;
    Future<Map<String, dynamic>> call(String fn, Map<String, dynamic> args) async {
      if (fn == 'publicCatalog') return {'data': {'items': [item()], 'page': 1}};
      if (fn == 'publicDetail') return {'data': item()};
      if (!entered.isCompleted) entered.complete();
      return pending.future;
    }
    final probe = RoutingProbeSession(source: source, info: () async => info(), isCurrent: () => true,
      openVideo: (_) async => RoutingProbeVideoAccess(repository: ApiVideoRepository(
        source: source, home: home, catalogFn: 'publicCatalog', detailFn: 'publicDetail', playbackFn: 'resolveLine',
        pluginCall: call)),
      commit: ({required source, required domains, required complete}) async { commits++; });
    final running = probe.run();
    await entered.future;
    probe.cancel();
    final result = await running;
    expect(result.cancelled, isTrue);
    expect(commits, 0);
    pending.complete(media({'lineId': 'a', 'episodeId': '1'}));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(commits, 0);
    expect(await RoutingObservedMediaDomains.read(), isEmpty);
    probe.dispose();
  });

  test('comic sampling calls only the explicit public list read contract, never nearby write fnPaths', () async {
    final calls = <String>[];
    final commits = <bool>[];
    final probe = RoutingProbeSession(source: source, isCurrent: () => true,
      info: () async => {
        'nativeContent': {'home': {'fnPath': 'saveDangerousSettings', 'readonly': false}},
        'settings': {'fnPath': 'saveDangerousSettings'},
        'function': [{'action': {'type': 'openComicList', 'payload': {'scene': {'body': {
          'type': 'pluginPagedComicList', 'request': {
            'fnPath': 'publicList', 'core': {'category': 'all'}, 'extern': {'scope': 'public'},
          },
        }}}}}],
      },
      call: (fn, core, extern) async {
        calls.add(fn);
        expect(core, {'category': 'all', 'page': 1});
        expect(extern, {'scope': 'public'});
        await RoutingObservedMediaDomains.observeHosts(source, ['comic-api.fixture.tv']);
        return {'data': {'items': []}};
      },
      commit: ({required source, required domains, required complete}) async {
        commits.add(complete); expect(domains, ['comic-api.fixture.tv']);
      });
    try {
      final result = await probe.run();
      expect(calls, ['publicList']);
      expect(result.complete, isTrue);
      expect(commits, [true]);
    } finally { probe.dispose(); }
  });

  test('unsupported declarations do not invoke guessed functions or overwrite observations', () async {
    var calls = 0, commits = 0;
    final probe = RoutingProbeSession(source: source, isCurrent: () => true,
      info: () async => {'fnPath': 'getSomething', 'settings': {'fnPath': 'saveSomething'}},
      call: (_, _, _) async { calls++; return {}; },
      commit: ({required source, required domains, required complete}) async { commits++; });
    try {
      final result = await probe.run();
      expect(result.unsupported, 1);
      expect(result.complete, isFalse);
      expect(calls, 0); expect(commits, 0);
    } finally { probe.dispose(); }
  });
}
