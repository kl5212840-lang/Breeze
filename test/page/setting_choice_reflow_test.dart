import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final nativeCalls = <String>[];
  setUp(() {
    nativeCalls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call.method);
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'long setting title shares its row with a readable short value $style ${brightness.name} $scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            final saved = <int>[];
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: SettingPageShell(
                    title: '插件设置',
                    grouped: true,
                    child: ListView(
                      children: [
                        SettingSection(
                          title: '图片偏好',
                          children: [
                            SettingChoiceTile<int>(
                              title: '图片加载并发数量',
                              description: '按当前网络选择合适的图片加载数量。',
                              value: 0,
                              items: const {0: '自动', 1: '始终使用来源首选线路'},
                              onChanged: saved.add,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final tile = find.byType(ListTile);
            final title = find.text('图片加载并发数量');
            final choice = find.byType(SettingChoice<int>);
            final tileBounds = tester.getRect(tile),
                titleBounds = tester.getRect(title),
                choiceBounds = tester.getRect(choice);
            expect(
              choiceBounds.top,
              lessThan(titleBounds.bottom),
              reason:
                  'A wrapping title must not force a short value into a detached second row',
            );
            expect(choiceBounds.bottom, greaterThan(titleBounds.top));
            expect(
              titleBounds.right,
              lessThanOrEqualTo(
                choiceBounds.left - (style == 'breeze' ? 11.5 : 15.5),
              ),
            );
            expect(choiceBounds.right, closeTo(tileBounds.right - 16, .5));
            expect(choiceBounds.height, greaterThanOrEqualTo(44));
            expect(
              choiceBounds.width,
              greaterThanOrEqualTo(
                SourceChoiceMenu.triggerWidth(
                  tester.element(choice),
                  ['自动'],
                  selectionIndicator: true,
                  maximumWidth: 500,
                ),
              ),
            );
            final description = find.text('按当前网络选择合适的图片加载数量。');
            final section = tester.getRect(find.byType(SettingChoiceTile<int>));
            final note = tester.getRect(description);
            expect(note.left - section.left, closeTo(16, .5));
            expect(section.right - note.right, greaterThanOrEqualTo(15.5));
            expect(section.bottom - note.bottom, greaterThanOrEqualTo(11.5));
            expect(
              tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
              isFalse,
            );
            final menu = tester.widget<NativeVideoMenu>(
              find.byType(NativeVideoMenu),
            );
            expect(menu.bare, isTrue);
            expect(menu.hostPresentation, isTrue);
            expect(menu.controller?.attached, isTrue);
            if (style == 'system') {
              final native = tester.widget<UiKitView>(
                find.descendant(
                  of: find.byType(NativeVideoMenu),
                  matching: find.byType(UiKitView),
                ),
              );
              expect((native.creationParams as Map)['pressFeedback'], isTrue);
              await tester.tap(title);
              await tester.pump();
              expect(nativeCalls, contains('openMenu'));
            } else {
              await tester.tap(title);
              await tester.pumpAndSettle();
              expect(find.text('始终使用来源首选线路'), findsOneWidget);
              await tester.tap(find.text('始终使用来源首选线路'));
              await tester.pumpAndSettle();
              expect(saved, [1]);
            }
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
