import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/view/download_swipe_actions.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_theme_colors.dart';

void main() {
  Finder sheet() => find.byKey(const ValueKey('download-action-sheet.row'));
  Finder command(String id) => find.byKey(ValueKey('download-swipe.row.$id'));
  final inlineMore = find.byKey(const ValueKey('download-row-more.row'));

  for (final (seed, brightness, interface) in [
    (const Color(0xffad355c), Brightness.light, 'breeze'),
    (const Color(0xff297f8a), Brightness.dark, 'system'),
  ]) {
    testWidgets(
      'download shortcuts and the complete row menu respect $interface $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final style = ValueNotifier(interface);
        final open = ValueNotifier<String?>(null);
        addTearDown(style.dispose);
        addTearDown(open.dispose);
        final colors = BreezeThemeColors.fromSeed(seed, brightness);
        late StateSetter refresh;
        var version = 1;
        var confirmations = 0;
        var removals = 0;
        var rowTaps = 0;
        var unpins = 0;

        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: style,
            child: MaterialApp(
              theme: ThemeData(
                platform: interface == 'system'
                    ? TargetPlatform.android
                    : TargetPlatform.iOS,
                colorScheme: colors,
                scaffoldBackgroundColor: colors.surface,
              ),
              locale: const Locale('zh'),
              supportedLocales: const [Locale('zh')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    refresh = setState;
                    return DownloadSwipeActions(
                      rowKey: 'row',
                      title: '正在测试的作品',
                      openRow: open,
                      actionVersion: version,
                      swipeActionIds: const ['unpin'],
                      actions: [
                        (
                          id: 'delete',
                          label: '删除下载',
                          icon: Icons.delete_outline,
                          run: () async {
                            expect(sheet(), findsNothing);
                            confirmations++;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                title: const Text('删除确认'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialog).pop(),
                                    child: Text(t.common.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialog).pop(true),
                                    child: Text(t.common.delete),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) removals++;
                          },
                        ),
                        (
                          id: 'unpin',
                          label: '取消置顶',
                          icon: Icons.push_pin,
                          run: () => unpins++,
                        ),
                        (
                          id: 'details',
                          label: '作品详情',
                          icon: Icons.info_outline,
                          run: () {},
                        ),
                        (
                          id: 'export',
                          label: '导出副本',
                          icon: Icons.ios_share,
                          run: () {},
                        ),
                      ],
                      child: InkWell(
                        key: const ValueKey('action-test-row'),
                        onTap: () => rowTaps++,
                        child: const SizedBox(
                          height: 108,
                          child: Row(
                            children: [
                              Expanded(child: Text('当前下载')),
                              DownloadRowMoreButton(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final extent = interface == 'system' ? 48.0 : 44.0;
        expect(tester.getSize(inlineMore), Size.square(extent));
        final moreButton = tester.widget<IconButton>(inlineMore);
        expect((moreButton.icon as Icon).size, 16);
        final color = moreButton.style!.foregroundColor!.resolve({})!;
        final contrast = BreezeThemeColors.contrast(color, colors.surface);
        expect(contrast, greaterThanOrEqualTo(3));
        expect(
          contrast,
          lessThan(
            BreezeThemeColors.contrast(colors.onSurfaceVariant, colors.surface),
          ),
        );
        final row = find.byKey(const ValueKey('action-test-row'));
        await tester.drag(row, const Offset(-140, 0));
        await tester.pumpAndSettle();
        expect(command('unpin').hitTestable(), findsOneWidget);
        expect(command('details'), findsNothing);
        expect(inlineMore.hitTestable(), findsOneWidget);
        expect(command('more'), findsNothing);
        expect(command('delete'), findsNothing);
        final tray = find.byKey(const ValueKey('download-swipe-tray.row'));
        expect(tester.widget<Material>(tray).type, MaterialType.transparency);
        final well =
            tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('download-swipe-well.row')),
                    )
                    .decoration
                as BoxDecoration;
        expect(well.color, isNot(colors.surface));
        final shortcut = tester.widget<Text>(
          find.descendant(of: command('unpin'), matching: find.text('取消')),
        );
        expect(shortcut.semanticsLabel, '取消置顶');
        expect(
          BreezeThemeColors.contrast(shortcut.style!.color!, well.color!),
          greaterThanOrEqualTo(4.5),
        );
        await tester.tap(command('unpin'));
        await tester.pumpAndSettle();
        expect(unpins, 1);

        await tester.tap(inlineMore);
        await tester.pumpAndSettle();
        expect(rowTaps, 0);
        expect(sheet(), findsOneWidget);
        expect(
          find.descendant(of: sheet(), matching: find.text('正在测试的作品')),
          findsOneWidget,
        );
        final divider = find.byKey(
          const ValueKey('download-action-sheet-divider.row'),
        );
        final sheetSurface = Theme.of(
          tester.element(sheet()),
        ).colorScheme.surface;
        for (final (id, label) in [
          ('unpin', '取消置顶'),
          ('details', '作品详情'),
          ('export', '导出副本'),
          ('delete', '删除下载'),
        ]) {
          final tile = command(id);
          expect(tile.hitTestable(), findsOneWidget);
          final labelWidget = tester.widget<Text>(
            find.descendant(of: tile, matching: find.text(label)),
          );
          expect(
            BreezeThemeColors.contrast(labelWidget.style!.color!, sheetSurface),
            greaterThanOrEqualTo(4.5),
          );
          expect(tester.getSize(tile).height, greaterThanOrEqualTo(extent));
          expect(
            tester.getCenter(tile).dy,
            id == 'delete'
                ? greaterThan(tester.getCenter(divider).dy)
                : lessThan(tester.getCenter(divider).dy),
          );
        }
        await tester.tap(
          find.byKey(const ValueKey('download-action-sheet-close.row')),
        );
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(confirmations, 0);

        await tester.tap(inlineMore);
        await tester.pumpAndSettle();
        refresh(() => version++);
        await tester.pumpAndSettle();
        await tester.tap(command('delete'));
        await tester.pumpAndSettle();
        expect(confirmations, 0);
        expect(removals, 0);

        await tester.tap(inlineMore);
        await tester.pumpAndSettle();
        await tester.tap(command('delete'));
        await tester.pumpAndSettle();
        expect(confirmations, 1);
        expect(removals, 0);
        await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
        await tester.pumpAndSettle();
        expect(removals, 0);
        expect(rowTaps, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a closing row menu releases its guard when the host unmounts', (
    tester,
  ) async {
    final open = ValueNotifier<String?>(null);
    addTearDown(open.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadSwipeActions(
            rowKey: 'row',
            openRow: open,
            actions: [
              (
                id: 'export',
                label: 'Export copy',
                icon: Icons.ios_share,
                run: () {},
              ),
            ],
            child: const DownloadRowMoreButton(),
          ),
        ),
      ),
    );
    await tester.tap(inlineMore);
    await tester.pumpAndSettle();
    expect(sheet(), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an export-only row keeps the inline menu without a swipe tray', (
    tester,
  ) async {
    final open = ValueNotifier<String?>(null);
    addTearDown(open.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadSwipeActions(
            rowKey: 'row',
            openRow: open,
            actions: [
              (
                id: 'export',
                label: 'Export copy',
                icon: Icons.ios_share,
                run: () {},
              ),
            ],
            child: const SizedBox(
              width: double.infinity,
              height: 80,
              child: DownloadRowMoreButton(),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(DownloadSwipeActions), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(open.value, isNull);
    expect(find.byKey(const ValueKey('download-swipe-tray.row')), findsNothing);
    await tester.tap(inlineMore);
    await tester.pumpAndSettle();
    expect(sheet(), findsOneWidget);
    expect(command('export').hitTestable(), findsOneWidget);
    expect(command('delete'), findsNothing);
  });
}
