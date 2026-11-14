import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_picker.dart';

void main() {
  const choices = [
    BookshelfFolderChoice(
      path: '',
      name: '根目录',
      parentPath: '',
      selectable: false,
    ),
    BookshelfFolderChoice(path: '/A', name: '文件夹甲', parentPath: ''),
    BookshelfFolderChoice(path: '/A/child', name: '子文件夹', parentPath: '/A'),
    BookshelfFolderChoice(path: '/B', name: '文件夹乙', parentPath: ''),
    BookshelfFolderChoice(
      path: '/self',
      name: '不能移动到自身',
      parentPath: '',
      selectable: false,
      browsable: false,
    ),
  ];
  Future<void> open(
    WidgetTester tester, {
    bool multiple = false,
    double scale = 1,
    double keyboard = 0,
    required ValueChanged<Set<String>> confirmed,
    Future<BookshelfFolderChoice> Function(String, String)? create,
  }) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BookshelfFolderPicker(
                  choices: choices,
                  title: multiple ? t.bookshelf.copyTo : t.bookshelf.moveTo,
                  multiple: multiple,
                  onConfirmed: confirmed,
                  onCreate: create,
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  for (final multiple in [false, true]) {
    testWidgets(
      multiple
          ? 'copy explicitly allows several targets'
          : 'move replaces its previous single target',
      (tester) async {
        Set<String>? selected;
        await open(tester, multiple: multiple, confirmed: (v) => selected = v);
        await tester.tap(find.byKey(const ValueKey('shelf-folder./A')));
        await tester.tap(find.byKey(const ValueKey('shelf-folder./B')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('shelf-folder.confirm')));
        await tester.pumpAndSettle();
        expect(selected, multiple ? {'/A', '/B'} : {'/B'});
        expect(find.byType(BookshelfFolderPicker), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '320 double text and keyboard retain a full 44 point confirmation',
    (tester) async {
      await open(tester, scale: 2, keyboard: 280, confirmed: (_) {});
      final confirm = find.byKey(const ValueKey('shelf-folder.confirm'));
      expect(tester.getSize(confirm).height, greaterThanOrEqualTo(44));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(740 - 280));
      final blocked = find.descendant(
        of: find.byKey(const ValueKey('shelf-folder./self')),
        matching: find.byType(Radio<String>),
      );
      expect(tester.widget<Radio<String>>(blocked).enabled, false);
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new folder validates inline and selects its created destination',
    (tester) async {
      final created = <String>[];
      Set<String>? selected;
      await open(
        tester,
        confirmed: (v) => selected = v,
        create: (parent, name) async {
          created.add('$parent/$name');
          return BookshelfFolderChoice(
            path: '$parent/$name',
            name: name,
            parentPath: parent,
          );
        },
      );
      await tester.tap(find.byKey(const ValueKey('shelf-folder./A')));
      await tester.tap(find.byKey(const ValueKey('shelf-folder.new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('shelf-folder.name')),
        'bad/name',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(t.bookshelf.folderNameSlash), findsOneWidget);
      expect(created, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('shelf-folder.name')),
        '新目录',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(created, ['/A/新目录']);
      expect(find.byKey(const ValueKey('shelf-folder./A/新目录')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shelf-folder.confirm')));
      await tester.pumpAndSettle();
      expect(selected, {'/A/新目录'});
      expect(tester.takeException(), isNull);
    },
  );
}
