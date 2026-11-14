import 'dart:async';
import 'dart:convert';
import 'package:flutter/rendering.dart' show RenderObject, RenderUiKitView;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/video/video_library_view.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

const _source = 'hanime-history-fixture';
const _storeKey = 'breeze.video.history.v1.$_source';
VideoWatchRecord _record(
  String id,
  String title,
  int clock, {
  String host = 'hanime1.me',
}) => VideoWatchRecord(
  watchUrl: Uri.parse('https://$host/watch?v=$id'),
  title: title,
  position: const Duration(seconds: 20),
  duration: const Duration(minutes: 2),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(clock),
  completed: false,
);
final _records = [
  _record('1', 'Zeta title', 2000),
  _record('2', 'Alpha title', 1000),
  _record('3', 'Other host title', 3000, host: 'other.example'),
];

Future<void> _openHost(
  WidgetTester tester,
  String style, {
  double scale = 1.3,
}) async {
  final preference = ValueNotifier(style);
  addTearDown(preference.dispose);
  tester.view.physicalSize = scale >= 2
      ? const Size(320, 700)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final channels = <MethodChannel>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
    call,
  ) async {
    if (call.method == 'create') {
      final args = call.arguments as Map;
      final channel = MethodChannel('${args['viewType']}.${args['id']}');
      channels.add(channel);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
  var showingHistory = true;
  await tester.pumpWidget(
    AppInterfaceStyleScope(
      style: preference,
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                videoPageRoute(
                  networkSource: _source,
                  builder: (_) => Scaffold(
                    body: StatefulBuilder(
                      builder: (context, update) => showingHistory
                          ? VideoLibraryView(
                              source: _source,
                              siteHost: 'hanime1.me',
                              onOpenVideo: (_) =>
                                  update(() => showingHistory = false),
                            )
                          : TextButton(
                              onPressed: () =>
                                  update(() => showingHistory = true),
                              child: const Text('return to history'),
                            ),
                    ),
                  ),
                ),
              ),
              child: const Text('open source'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open source'));
  await tester.pumpAndSettle();
}

Finder get _search => find.descendant(
  of: find.byType(SearchQueryField),
  matching: find.byType(TextField),
);
NativeVideoMenu _menu(WidgetTester tester) => tester.widget<NativeVideoMenu>(
  find.byKey(const ValueKey('api-history.manage')),
);
void _sort(WidgetTester tester) => tester
    .widget<NativeVideoMenu>(find.byKey(const ValueKey('api-history.sort')))
    .onSelected('title');
Future<void> _openSearch(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('api-history.search-toggle'));
  final native = find.descendant(of: toggle, matching: find.byType(UiKitView));
  if (native.evaluate().isEmpty) {
    await tester.tap(toggle);
  } else {
    RenderUiKitView? view;
    void visit(RenderObject object) {
      if (object is RenderUiKitView) view = object;
      object.visitChildren(visit);
    }

    visit(tester.renderObject(native));
    final id = view!.viewController.id;
    final replied = Completer<void>();
    tester.binding.channelBuffers.push(
      'breeze.video.control.$id',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('press')),
      (_) => replied.complete(),
    );
    await replied.future;
  }
  await tester.pumpAndSettle();
  expect(_search, findsOneWidget);
}

List<String> _titles(WidgetTester tester) {
  final collection = find.byType(ApiVideoCollection);
  if (collection.evaluate().isEmpty) return [];
  return tester
      .widget<ApiVideoCollection>(collection)
      .items
      .map((item) => item.title)
      .toList();
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      _storeKey: jsonEncode(_records.map((record) => record.toJson()).toList()),
    }),
  );
  for (final style in ['system', 'breeze']) {
    testWidgets(
      '$style local history pushes above the tab navigator and returns to the same profile',
      (tester) async {
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        final root = GlobalKey<NavigatorState>();
        final nested = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              navigatorKey: root,
              home: Scaffold(
                bottomNavigationBar: const Text('main tabs'),
                body: Navigator(
                  key: nested,
                  onGenerateRoute: (_) => videoPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('source profile')),
                      body: TextButton(
                        onPressed: () => openVideoLocalHistory(
                          context,
                          source: _source,
                          siteHost: 'hanime1.me',
                          onOpenVideo: (recordContext, _) =>
                              Navigator.of(recordContext).push<void>(
                                videoPageRoute<void>(
                                  builder: (_) => Scaffold(
                                    body: TextButton(
                                      onPressed: () => root.currentState!.pop(),
                                      child: const Text('return to records'),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                        child: const Text('local records'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('local records'));
        await tester.pumpAndSettle();
        final history = tester.element(find.byType(VideoLibraryView));
        expect(
          ModalRoute.of(history)!.settings.name,
          videoLocalHistoryRouteName,
        );
        expect(ModalRoute.of(history)!.navigator, root.currentState);
        expect(nested.currentState!.canPop(), isFalse);
        expect(find.text('main tabs'), findsNothing);
        expect(find.text('source profile'), findsNothing);
        expect(find.text(t.videoPlayback.siteAccount), findsNothing);
        expect(find.text(t.discover.settings), findsNothing);
        expect(find.text(t.videoSource.localHistory), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        await tester.tap(find.text('Zeta title'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('return to records'));
        await tester.pumpAndSettle();
        expect(find.text('Zeta title'), findsOneWidget);
        tester
            .widget<SourceChromeIconButton>(
              find.descendant(
                of: find.byType(SourceBackButton),
                matching: find.byType(SourceChromeIconButton),
              ),
            )
            .onPressed!();
        await tester.pumpAndSettle();
        expect(find.text('source profile'), findsOneWidget);
        expect(find.text('main tabs'), findsOneWidget);
        expect(nested.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
    testWidgets(
      '$style source route searches complete local history, sorts and restores after remount',
      (tester) async {
        await _openHost(tester, style);
        expect(_titles(tester), ['Zeta title', 'Alpha title']);
        expect(find.text('Other host title'), findsNothing);
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          3,
        );
        _sort(tester);
        await tester.pumpAndSettle();
        expect(_titles(tester), ['Alpha title', 'Zeta title']);
        await _openSearch(tester);
        await tester.enterText(_search, 'ALP');
        await tester.pumpAndSettle();
        expect(_titles(tester), ['Alpha title']);
        await tester.tap(find.text('Alpha title'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('return to history'));
        await tester.pumpAndSettle();
        await _openSearch(tester);
        expect(
          tester.widget<SearchQueryField>(find.byType(SearchQueryField)).query,
          'ALP',
        );
        expect(_titles(tester), ['Alpha title']);
        await tester.tap(find.byTooltip(t.common.clear));
        await tester.pumpAndSettle();
        expect(_titles(tester), ['Alpha title', 'Zeta title']);
        expect(await VideoWatchHistory.read(_source), hasLength(3));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'large text no-match clear preserves sort; a failed local read can retry',
    (tester) async {
      final vertical = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      SharedPreferences.setMockInitialValues({_storeKey: 42});
      await _openHost(tester, 'breeze', scale: 2);
      await tester.scrollUntilVisible(
        find.text(t.common.loadingFailed),
        200,
        scrollable: vertical,
      );
      expect(find.text(t.common.loadingFailed), findsOneWidget);
      final store = await SharedPreferences.getInstance();
      await store.setString(
        _storeKey,
        jsonEncode(_records.map((r) => r.toJson()).toList()),
      );
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(find.text(t.common.loadingFailed), findsNothing);
      _sort(tester);
      await _openSearch(tester);
      await tester.enterText(_search, 'missing title');
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(t.videoLibrary.noResults),
        200,
        scrollable: vertical,
      );
      expect(find.text(t.videoPlayback.historyEmpty), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, t.common.clear));
      await tester.pumpAndSettle();
      expect(_titles(tester), ['Alpha title', 'Zeta title']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'shared record management deletes only the selected independent video',
    (tester) async {
      await _openHost(tester, 'breeze');
      _menu(tester).onSelected('manage');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zeta title'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('api-history.selection.delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, t.common.delete).last);
      await tester.pumpAndSettle();
      expect(_titles(tester), ['Alpha title']);
      final saved = await VideoWatchHistory.read(_source);
      expect(
        saved.map((row) => row.watchUrl.queryParameters['v']),
        unorderedEquals(['2', '3']),
      );
      expect(
        find.byKey(const ValueKey('api-history.compact-header')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
