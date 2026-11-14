import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/widgets/bika_network_settings.dart';
import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets(
    'network choices use the plugin schema and save only the selected field before readback',
    (tester) async {
      var channel = '3';
      final calls = <(String, Map<String, dynamic>)>[];
      final write = Completer<void>();
      Future<Map<String, dynamic>> call(
        String source,
        String fn,
        Map<String, dynamic> core,
      ) async {
        expectSync(source, bikaPlusSourceId);
        calls.add((fn, core));
        if (fn == 'saveSettings') {
          await write.future;
          channel = '2';
          return {'ok': true};
        }
        return {
          'source': source,
          'scheme': {
            'sections': [
              {
                'id': 'network',
                'fields': [
                  {
                    'key': 'network.apiBase',
                    'kind': 'select',
                    'label': 'API 服务器',
                    'options': [
                      {'label': '主服务器', 'value': 'https://fixture.test/'},
                    ],
                  },
                  {
                    'key': 'network.proxy',
                    'kind': 'select',
                    'label': '分流通道',
                    'options': [
                      {'label': '2', 'value': '2'},
                      {'label': '3', 'value': '3'},
                    ],
                  },
                  {
                    'key': 'auth.password',
                    'kind': 'select',
                    'label': '不得显示',
                    'options': [],
                  },
                ],
              },
            ],
          },
          'data': {
            'values': {
              'network.apiBase': 'https://fixture.test/',
              'network.proxy': channel,
            },
          },
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: BikaNetworkSettingsPage(
            source: bikaPlusSourceId,
            call: call,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('不得显示'), findsNothing);
      SettingChoiceTile<String> choice() => tester.widget(
        find.byKey(const ValueKey('bika-network-network.proxy')),
      );
      choice().onChanged('2');
      choice().onChanged('2');
      await tester.pump();
      expect(calls.where((c) => c.$1 == 'saveSettings'), hasLength(1));
      expect(calls.last.$2, {
        'values': {'network.proxy': '2'},
      });
      expect(choice().enabled, isFalse);
      write.complete();
      await tester.pumpAndSettle();
      expect(
        choice().value,
        '2',
        reason:
            'calls=$calls; rendered=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
      );
      expect(choice().enabled, isTrue);
      expect(calls.map((c) => c.$1), [
        'getSettingsBundle',
        'saveSettings',
        'getSettingsBundle',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy network page keeps its available schema field', (
    tester,
  ) async {
    var channel = '3';
    final functions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: BikaNetworkSettingsPage(
          source: bikaPlusSourceId,
          call: (_, function, core) async {
            functions.add(function);
            if (function == 'saveSettings') {
              channel = (core['values'] as Map)['network.proxy'] as String;
              return {'ok': true};
            }
            return _channelBundle(channel);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('bika-network-network.proxy'));
    expect(field, findsOneWidget);
    tester.widget<SettingChoiceTile<String>>(field).onChanged('2');
    await tester.pumpAndSettle();
    expect(tester.widget<SettingChoiceTile<String>>(field).value, '2');
    expect(functions, [
      'getSettingsBundle',
      'saveSettings',
      'getSettingsBundle',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'network page source switch discards the previous save readback',
    (tester) async {
      final source = ValueNotifier('a');
      addTearDown(source.dispose);
      final write = Completer<Map<String, dynamic>>();
      final calls = <String>[];
      Future<Map<String, dynamic>> call(
        String from,
        String function,
        Map<String, dynamic> core,
      ) async {
        calls.add('$from:$function');
        if (function == 'saveSettings') return write.future;
        return _channelBundle(from == 'a' ? '3' : '2');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: source,
            builder: (_, value, _) =>
                BikaNetworkSettingsPage(source: value, call: call),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('bika-network-network.proxy'));
      tester.widget<SettingChoiceTile<String>>(field).onChanged('2');
      await tester.pump();
      source.value = 'b';
      await tester.pumpAndSettle();
      expect(tester.widget<SettingChoiceTile<String>>(field).enabled, isTrue);
      write.complete({'ok': true});
      await tester.pumpAndSettle();
      expect(tester.widget<SettingChoiceTile<String>>(field).value, '2');
      expect(calls, [
        'a:getSettingsBundle',
        'a:saveSettings',
        'b:getSettingsBundle',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _channelBundle(String channel) => {
  'scheme': {
    'sections': [
      {
        'id': 'network',
        'fields': [
          {
            'key': 'network.proxy',
            'kind': 'select',
            'options': [
              {'label': '2', 'value': '2'},
              {'label': '3', 'value': '3'},
            ],
          },
        ],
      },
    ],
  },
  'data': {
    'values': {'network.proxy': channel},
  },
};
