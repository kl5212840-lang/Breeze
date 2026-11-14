import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/cubit/string_select.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/view/comic_read.dart';
import 'package:zephyr/page/comic_read/widgets/chrome/bottom.dart';
import 'package:zephyr/page/comic_read/widgets/controls/slider.dart';
import 'package:zephyr/page/comic_read/widgets/feedback/error.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/type/enum.dart';

import '../service/reader_history_session_test.dart' as fixture;
import '../test_helper.dart';

class _LoadingPluginApi extends RustLibApi {
  final response = Completer<String>();

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('loading-controls-fixture');

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
    if (fnPath == 'init') return utf8.encode('{"data":{"ok":true}}');
    expect(fnPath, 'getReadSnapshot');
    return utf8.encode(await response.future);
  }

  @override
  Future<QjsCancelTasksByGroupResult> crateApiQjsQjsCancelTasksByGroup({
    required String runtimeName,
    required String taskGroupKey,
  }) async => const QjsCancelTasksByGroupResult(
    cancelled: 1,
    notFound: 0,
    failedRuntimeGroups: [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  testWidgets('a single tap reopens both toolbars after initial auto-hide', (
    tester,
  ) async {
    final api = _LoadingPluginApi();
    RustLib.initMock(api: api);
    final messenger = tester.binding.defaultBinaryMessenger;
    const windowManager = MethodChannel('window_manager');
    messenger.setMockMethodCallHandler(windowManager, (_) async => false);
    addTearDown(() => messenger.setMockMethodCallHandler(windowManager, null));
    for (final channel in const [
      MethodChannel('dev.fluttercommunity.plus/connectivity'),
      MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => ['wifi']);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final global = GlobalSettingCubit();
    final preference = ComicReadPreferenceCubit();
    final stringSelect = StringSelectCubit();
    addTearDown(global.close);
    addTearDown(preference.close);
    addTearDown(stringSelect.close);
    try {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: global),
            BlocProvider.value(value: preference),
          ],
          child: MaterialApp(
            home: ComicReadPage(
              comicId: 'loading-controls-online',
              order: 1,
              epsNumber: 1,
              from: '78617c71-313f-42fe-9317-460d691890b2',
              stringSelectCubit: stringSelect,
              type: ComicEntryType.normal,
              comicInfo: {'comicInfo': fixture.info.toJson(), 'eps': const []},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      final indicator = find.byType(CircularProgressIndicator);
      final back = find.byType(SourceBackButton);
      final settings = find.byTooltip(t.reader.settings);
      final reader = tester
          .element(find.byType(BottomWidget))
          .read<ReaderCubit>();
      expect(indicator, findsOneWidget);
      expect(reader.state.isMenuVisible, isFalse);
      expect(settings.hitTestable(), findsNothing);

      final readingSurface = tester.getCenter(indicator);
      await tester.tapAt(readingSurface);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(back.hitTestable(), findsOneWidget);
      expect(settings.hitTestable(), findsOneWidget);
      expect(find.byType(SliderWidget), findsNothing);
      await tester.tap(settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(t.reader.settings), findsOneWidget);
      Navigator.of(tester.element(find.text(t.reader.settings))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(indicator, findsOneWidget);

      await tester.tapAt(readingSurface);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(reader.state.isMenuVisible, isFalse);
      expect(settings.hitTestable(), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      api.response.complete('{"chapter":{"pages":[]}}');
      await tester.pump();
    }
  });

  testWidgets(
    'reader settings and navigation survive initial load and failure',
    (tester) async {
      final global = GlobalSettingCubit();
      final preference = ComicReadPreferenceCubit();
      final stringSelect = StringSelectCubit();
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(global.close);
      addTearDown(preference.close);
      addTearDown(stringSelect.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: global),
            BlocProvider.value(value: preference),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Downloads')),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push<void>(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => ComicReadPage(
              comicId: 'loading-controls-missing-work',
              order: 1,
              epsNumber: 1,
              from: 'reader-loading-controls',
              stringSelectCubit: stringSelect,
              type: ComicEntryType.download,
              comicInfo: {'comicInfo': fixture.info.toJson(), 'eps': const []},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SourceBackButton), findsOneWidget);
      final bottom = find.byType(BottomWidget);
      Finder readerTool(IconData icon) => find.byWidgetPredicate(
        (widget) => widget is FloatingActionIconButton && widget.icon == icon,
      );
      final settings = readerTool(Icons.tune_rounded);
      final picker = readerTool(Icons.view_list_outlined);
      expect(bottom, findsOneWidget);
      expect(settings, findsOneWidget);
      expect(
        tester.widget<FloatingActionIconButton>(picker).isEnabled,
        isFalse,
      );
      expect(find.byType(SliderWidget), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(ComicErrorWidget), findsOneWidget);
      expect(settings, findsOneWidget);
      expect(find.byType(SliderWidget), findsNothing);
      await tester.tap(find.byTooltip(t.reader.settings));
      await tester.pumpAndSettle();
      expect(find.text(t.reader.settings), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ComicErrorWidget), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Downloads'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
