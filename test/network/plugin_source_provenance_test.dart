import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../test_helper.dart';

const _plugin = '78617c71-313f-42fe-9317-460d691890b2';

class _ProvenanceApi extends RustLibApi {
  Map<String, dynamic> response = {};
  Object? failure;
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('provenance-fixture');
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
    if (fnPath != 'init' && failure != null) throw failure!;
    return Uint8List.fromList(
    utf8.encode(
      jsonEncode(
        fnPath == 'init'
            ? {
                'data': {'ok': true},
              }
            : response,
      ),
    ),
  );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected fixture API ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _ProvenanceApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'real adapter normalizes plugin identities without rewriting evidence',
    () async {
      api.response = {
        'source': 'third-party-runtime',
        'data': {
          'items': [
            {'source': 'third-party-runtime', 'id': 'work-1'},
          ],
          'verification': {'source': 'serverCalendar', 'signed': true},
          'extern': {
            'checkinProof': {'source': 'savedReceipt', 'date': '2026-11-02'},
          },
        },
      };
      final result = await callUnifiedComicPlugin(
        from: _plugin,
        fnPath: 'fixtureRead',
        core: {},
      );
      expect(result['source'], _plugin);
      expect(result['data']['items'].single['source'], _plugin);
      expect(result['data']['verification']['source'], 'serverCalendar');
      expect(
        result['data']['extern']['checkinProof']['source'],
        'savedReceipt',
      );
    },
  );

  test(
    'legacy responses and unknown evidence providers retain their separate meanings',
    () async {
      api.response = {
        'data': {
          'items': [
            {'source': 'vendor', 'id': 'work-2'},
          ],
        },
      };
      var result = await callUnifiedComicPlugin(
        from: _plugin,
        fnPath: 'fixtureRead',
        core: {},
      );
      expect(result['data']['items'].single['source'], _plugin);
      api.response = {
        'data': {
          'verification': {'source': 'future-provider', 'status': 'unknown'},
        },
      };
      result = await callUnifiedComicPlugin(
        from: _plugin,
        fnPath: 'fixtureRead',
        core: {},
      );
      expect(result['data']['verification']['source'], 'future-provider');
    },
  );
  test('quiet follow reads retain login failure without launching another account route', () async {
    final events = <NeedLogin>[];
    final subscription = eventBus.on<NeedLogin>().listen(events.add);
    api.failure = AnyhowException(jsonEncode({
      'type': 'unauthorized', 'source': _plugin, 'message': 'Fixture login expired',
    }));
    try {
      await expectLater(callUnifiedComicPlugin(from: _plugin, fnPath: 'fixtureRead', core: {},
        notifyUnauthorized: false), throwsA(isA<PluginLoginRequiredException>()));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await expectLater(callUnifiedComicPlugin(from: _plugin, fnPath: 'fixtureRead', core: {}),
        throwsA(isA<PluginLoginRequiredException>()));
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 1);
    } finally {
      api.failure = null;
      await subscription.cancel();
    }
  });

}
