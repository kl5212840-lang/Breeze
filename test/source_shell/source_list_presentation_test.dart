import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the legacy shared_preferences cache and backing-store contract.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/source_shell/source_list_view_toggle.dart';

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore() : super.empty();

  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool reject = false;
  bool throwOnWrite = false;

  @override
  Future<Map<String, Object>> getAll() async {
    await readGate?.future;
    return super.getAll();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    await writeGate?.future;
    if (throwOnWrite) throw StateError('fixture storage unavailable');
    if (reject) return false;
    return super.setValue(type, key, value);
  }
}

Widget _surface(String source, {bool detailedByDefault = false}) => MaterialApp(
  home: Scaffold(
    body: SourceListPresentation(
      source: source,
      detailedByDefault: detailedByDefault,
      builder: (_, detailed, select) =>
          SourceListViewToggle(detailed: detailed, onChanged: select),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'view preferences persist per source and do not invent missing values',
    () async {
      expect(await SourceListPreferences.read(''), isNull);
      expect(await SourceListPreferences.read('copy'), isNull);
      await SourceListPreferences.write('copy', true);
      await SourceListPreferences.write('jm', false);
      expect(await SourceListPreferences.read('copy'), isTrue);
      expect(await SourceListPreferences.read('jm'), isFalse);
      final store = await SharedPreferences.getInstance();
      await store.reload();
      expect(store.getBool('${SourceListPreferences.prefix}copy'), isTrue);
      expect(store.getBool('${SourceListPreferences.prefix}jm'), isFalse);
    },
  );

  testWidgets('reopening and switching source reuse only that source choice', (
    tester,
  ) async {
    await SourceListPreferences.write('copy', true);
    await tester.pumpWidget(_surface('copy'));
    await tester.pumpAndSettle();
    expect(find.byTooltip(t.comicList.switchToGrid), findsOneWidget);
    await tester.tap(find.byType(SourceListViewToggle));
    await tester.pumpAndSettle();
    expect(await SourceListPreferences.read('copy'), isFalse);

    await tester.pumpWidget(_surface('jm', detailedByDefault: true));
    await tester.pumpAndSettle();
    expect(find.byTooltip(t.comicList.switchToGrid), findsOneWidget);
    expect(await SourceListPreferences.read('jm'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_surface('copy', detailedByDefault: true));
    await tester.pumpAndSettle();
    expect(find.byTooltip(t.comicList.switchToList), findsOneWidget);
  });

  testWidgets(
    'an old async read cannot undo a click while its write is pending',
    (tester) async {
      final store = _ControlledStore()
        ..readGate = Completer<void>()
        ..writeGate = Completer<void>();
      SharedPreferencesStorePlatform.instance = store;
      await tester.pumpWidget(_surface('race'));
      await tester.tap(find.byType(SourceListViewToggle));
      await tester.pump();
      expect(find.byTooltip(t.comicList.switchToGrid), findsOneWidget);

      store.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byTooltip(t.comicList.switchToGrid), findsOneWidget);
      store.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(await SourceListPreferences.read('race'), isTrue);
    },
  );

  testWidgets(
    'two simultaneous surfaces update after a source choice is saved',
    (tester) async {
      Widget choice(Key key) => SourceListPresentation(
        key: key,
        source: 'shared',
        builder: (_, detailed, select) =>
            SourceListViewToggle(detailed: detailed, onChanged: select),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                choice(const ValueKey('search')),
                choice(const ValueKey('list')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SourceListViewToggle).first);
      await tester.pumpAndSettle();
      expect(find.byTooltip(t.comicList.switchToGrid), findsNWidgets(2));
    },
  );

  testWidgets('rapid choices keep the latest value while storage is pending', (
    tester,
  ) async {
    final store = _ControlledStore()..writeGate = Completer<void>();
    SharedPreferencesStorePlatform.instance = store;
    await tester.pumpWidget(_surface('rapid'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SourceListViewToggle));
    await tester.pump();
    await tester.tap(find.byType(SourceListViewToggle));
    await tester.pump();
    expect(find.byTooltip(t.comicList.switchToList), findsOneWidget);
    store.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(await SourceListPreferences.read('rapid'), isFalse);
    expect(find.byTooltip(t.comicList.switchToList), findsOneWidget);
  });

  for (final throwing in [false, true]) {
    testWidgets(
      'storage ${throwing ? 'exception' : 'rejection'} is visible and cannot look persisted',
      (tester) async {
        final store = _ControlledStore()
          ..throwOnWrite = throwing
          ..reject = !throwing;
        SharedPreferencesStorePlatform.instance = store;
        await tester.pumpWidget(_surface('failure'));
        await tester.pumpAndSettle();
        final before = SourceListPreferences.changes.value;
        await tester.tap(find.byType(SourceListViewToggle));
        await tester.pumpAndSettle();
        expect(find.text(t.comicList.viewSaveFailed), findsOneWidget);
        expect(SourceListPreferences.changes.value, before);
        expect(await SourceListPreferences.read('failure'), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
