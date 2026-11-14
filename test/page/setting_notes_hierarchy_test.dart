import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../ui_preview_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiPreviewFonts);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null),
  );
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'optional help shares one disclosure while consequences stay visible $style $brightness $scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 760);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final notifier = ValueNotifier(style);
            addTearDown(notifier.dispose);
            const brief = '使用应用时定期同步。';
            const risk = '取消不改变当前资料。';
            final longer = List.filled(12, '本段解释适用条件与操作结果，保留完整内容。').join();
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: notifier,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: SettingPageShell(
                    grouped: true,
                    title: '设置',
                    child: ListView(
                      children: [
                        SettingSection(
                          title: '综合设置',
                          footer: risk,
                          details: {'自动同步': brief, '资料合并规则与适用条件': longer},
                          children: const [ListTile(title: Text('同步开关'))],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(brief), findsNothing);
            expect(find.text(risk), findsOneWidget);
            expect(
              find.text(t.settings.sectionHelp(section: '综合设置')),
              findsOneWidget,
            );
            expect(find.text(longer), findsNothing);
            final disclosure = find.byKey(
              const ValueKey('settings-details-综合设置'),
            );
            await tester.ensureVisible(disclosure);
            await tester.pumpAndSettle();
            expect(tester.getSize(disclosure).height, greaterThanOrEqualTo(44));
            expect(tester.widget(disclosure), isA<TextButton>());
            expect(
              tester
                  .getTopLeft(
                    find.text(t.settings.sectionHelp(section: '综合设置')),
                  )
                  .dx,
              closeTo(tester.getTopLeft(find.text(risk)).dx, .5),
              reason: 'help uses the footer text gutter without a boxed inset',
            );
            await tester.tap(disclosure);
            await tester.pumpAndSettle();
            expect(find.text(longer), findsOneWidget);
            expect(
              tester.getRect(find.text(longer)).right,
              lessThanOrEqualTo(320),
            );
            expect(find.text(brief), findsOneWidget);
            await tester.ensureVisible(disclosure);
            await tester.pumpAndSettle();
            await tester.tap(disclosure);
            await tester.pumpAndSettle();
            expect(find.text(longer), findsNothing);
            expect(find.text(brief), findsNothing);
            expect(find.text(risk), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
      testWidgets(
        'settings help collapses when leaving a retained route $style $brightness',
        (tester) async {
          final notifier = ValueNotifier(style);
          addTearDown(notifier.dispose);
          final navigator = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: notifier,
              child: MaterialApp(
                navigatorKey: navigator,
                theme: ThemeData(brightness: brightness),
                home: const SettingPageShell(
                  title: '设置',
                  child: SingleChildScrollView(
                    child: SettingSection(
                      title: '显示',
                      details: {'主题': '跟随设备的外观设置。'},
                      children: [ListTile(title: Text('主题'))],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byKey(const ValueKey('settings-details-显示'));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text('跟随设备的外观设置。'), findsOneWidget);
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('另一个设置页')),
            ),
          );
          await tester.pumpAndSettle();
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(find.text('跟随设备的外观设置。'), findsNothing);
          expect(button, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
      testWidgets(
        'supporting note remains secondary and readable $style $brightness',
        (tester) async {
          final notifier = ValueNotifier(style);
          addTearDown(notifier.dispose);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const note = '下载文件默认不包含。备份可能含有记住的账号资料，请妥善保存。';
          const outsideNote = '恢复时保留未选择的资料。';
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: notifier,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  fontFamily: uiPreviewDirectory == null
                      ? null
                      : 'AccountPreview',
                ),
                builder: (context, child) => RepaintBoundary(
                  key: const ValueKey('notes.preview'),
                  child: child!,
                ),
                home: SettingPageShell(
                  grouped: true,
                  title: '备份与恢复',
                  child: ListView(
                    children: [
                      SettingSection(
                        title: '导出',
                        footer: note,
                        children: const [
                          ListTile(
                            key: ValueKey('notes.row'),
                            leading: Icon(Icons.archive_outlined),
                            title: Text('导出备份'),
                          ),
                        ],
                      ),
                      const SettingNote.section(outsideNote),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.text(note));
          final theme = Theme.of(context);
          final background = usesCupertinoSettings(context)
              ? CupertinoColors.systemGroupedBackground.resolveFrom(context)
              : theme.scaffoldBackgroundColor;
          final text = tester.widget<Text>(find.text(note));
          double contrast(Color c) {
            final a = c.computeLuminance(), b = background.computeLuminance();
            return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
          }

          expect(contrast(text.style!.color!), greaterThanOrEqualTo(4.5));
          expect(
            contrast(text.style!.color!),
            lessThan(contrast(theme.colorScheme.onSurface)),
          );
          expect(
            text.style!.fontSize,
            lessThan(theme.textTheme.bodyLarge!.fontSize!),
          );
          final distance =
              tester.getTopLeft(find.text(note)).dy -
              tester.getBottomLeft(find.byKey(const ValueKey('notes.row'))).dy;
          expect(distance, inInclusiveRange(8, 12));
          expect(
            tester.getTopLeft(find.text(outsideNote)).dx,
            closeTo(tester.getTopLeft(find.text(note)).dx, .5),
            reason: 'notes outside a group use its actual footer text inset',
          );
          expect(
            tester.getTopRight(find.text(outsideNote)).dx,
            closeTo(tester.getTopRight(find.text(note)).dx, .5),
          );
          expect(tester.takeException(), isNull);
          await writeUiPreview(
            tester,
            const ValueKey('notes.preview'),
            'settings-notes-$style-${brightness.name}',
          );
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
