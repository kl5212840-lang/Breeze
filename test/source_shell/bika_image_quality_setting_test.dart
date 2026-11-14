import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/widgets/bika_image_quality_setting.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

Map<String, dynamic> bundle(String value, {bool supported = true}) => {
  'scheme': {
    'sections': [
      {
        'id': 'image',
        'fields': [
          if (supported) {'key': 'image.quality', 'kind': 'select'},
        ],
      },
    ],
  },
  'data': {
    'values': {'image.quality': value},
  },
};

void main() {
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'server quality saves one field and reads back $style $brightness',
        (tester) async {
          var value = 'original';
          final requests = <Map<String, dynamic>>[];
          final pending = Completer<void>();
          final notifier = ValueNotifier(style);
          addTearDown(notifier.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: notifier,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: SettingPageShell(
                  title: 'Settings',
                  child: SettingListView(
                    children: [
                      BikaImageQualitySetting(
                        source: 'fixture',
                        call: (source, fn, core) async {
                          expectSync(source, 'fixture');
                          if (fn == 'saveSettings') {
                            requests.add(core);
                            await pending.future;
                            value =
                                (core['values'] as Map)['image.quality']
                                    as String;
                            return {'ok': true};
                          }
                          return bundle(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          SettingChoiceTile<String> choice() =>
              tester.widget(find.byKey(const ValueKey('bika-image-quality')));
          expect(choice().value, 'original');
          expect(
            choice().items.keys,
            containsAll(['original', 'high', 'medium', 'low']),
          );
          choice().onChanged('high');
          choice().onChanged('low');
          await tester.pump();
          expect(requests, [
            {
              'values': {'image.quality': 'high'},
            },
          ]);
          expect(choice().enabled, isFalse);
          pending.complete();
          await tester.pumpAndSettle();
          expect(
            choice().value,
            'high',
            reason:
                'actual backend=$value error=${choice().error} requests=$requests',
          );
          expect(choice().enabled, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('old bundles do not advertise unsupported image quality', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BikaImageQualitySetting(
            source: 'old',
            call: (_, _, _) async => bundle('original', supported: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingChoiceTile<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('source switch discards a pending quality write readback', (
    tester,
  ) async {
    final source = ValueNotifier('a');
    addTearDown(source.dispose);
    final write = Completer<Map<String, dynamic>>();
    final calls = <String>[];
    Future<Map<String, dynamic>> call(
      String from,
      String fn,
      Map<String, dynamic> core,
    ) async {
      calls.add('$from:$fn');
      if (fn == 'saveSettings') return write.future;
      return bundle(from == 'a' ? 'original' : 'low');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: source,
            builder: (_, value, _) =>
                BikaImageQualitySetting(source: value, call: call),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    SettingChoiceTile<String> choice() =>
        tester.widget(find.byKey(const ValueKey('bika-image-quality')));
    choice().onChanged('high');
    source.value = 'b';
    await tester.pumpAndSettle();
    expect(choice().value, 'low');
    write.complete({'ok': true});
    await tester.pumpAndSettle();
    expect(choice().value, 'low');
    expect(calls.where((call) => call == 'a:getSettingsBundle'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
