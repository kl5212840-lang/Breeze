import 'dart:async';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/source_downloaded_videos_page.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/omofun_site_history_preview.dart';
import 'package:zephyr/page/video/omofun_native_history_scope.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';

void main() {
  test('download preview selects only source validated files, newest first', () {
    Map<String, dynamic> row(String id, String source, int at,
        {bool available = true, bool file = true}) => {
      'resourceId': id, 'source': source, 'at': at,
      'available': available, 'filePresent': file,
    };
    final selected = sourcePlayableVideoRows([
      row('old', 'omo', 1), row('new', 'omo', 2), row('foreign', 'other', 9),
      row('running', 'omo', 8, available: false), row('missing', 'omo', 7, file: false),
      row('', 'omo', 10),
    ], 'omo');
    expect(selected.map((row) => row['resourceId']), ['new', 'old']);
  });
  testWidgets('site preview keeps no-cover records and clears private rows on sign out', (tester) async {
    final home = Uri.parse('https://www.omofuna.com/');
    final gate = Completer<Map<String, dynamic>>();
    final client = OmoSiteClient(home: home, request: (operation, args) async {
      if (operation == 'account') return {'kind': 'account', 'account': {'id': '1', 'name': 'Fixture'}};
      expect(operation, 'historyPreview');
      return gate.future;
    });
    addTearDown(client.dispose);
    await client.readAccount();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OmoNativeHistoryScope(
      source: 'omo', mode: ApiVideoView.list, openEntry: (_) async {},
      child: OmoSiteHistoryPreview(client: client, source: 'omo'),
    ))));
    gate.complete({'kind': 'history', 'rawCount': 1, 'hasMore': false, 'items': [{
      'url': home.resolve('/anime/1234567890abcdef/play/1/2.html').toString(),
      'title': 'No-cover actual history', 'episodeLabel': 'Episode 2',
    }]});
    await tester.pumpAndSettle();
    expect(find.text('No-cover actual history'), findsOneWidget);
    expect(find.byType(ApiVideoPoster), findsOneWidget);
    client.invalidateAccount();
    await tester.pump();
    expect(find.text('No-cover actual history'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('nonempty unmapped site history cannot display a fake empty preview', (tester) async {
    final client = OmoSiteClient(home: Uri.parse('https://www.omofuna.com/'), request: (operation, args) async {
      if (operation == 'account') return {'kind': 'account', 'account': {'id': '1', 'name': 'Fixture'}};
      expect(operation, 'historyPreview');
      return {'kind': 'history', 'rawCount': 2, 'hasMore': false, 'items': []};
    });
    addTearDown(client.dispose);
    await client.readAccount();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OmoNativeHistoryScope(
      source: 'omo', mode: ApiVideoView.list, openEntry: (_) async {},
      child: OmoSiteHistoryPreview(client: client, source: 'omo'),
    ))));
    await tester.pumpAndSettle();
    expect(find.text(t.common.empty), findsNothing);
    expect(find.text(t.videoSource.readFailed), findsOneWidget);
    expect(find.text(t.common.retry), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  for (final width in [320.0, 600.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Omo responsive preview matches JM columns and caps four items $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: Padding(padding: const EdgeInsets.all(16),
            child: SourceProfileVideoPreview(identity: 'omo-density', title: 'Omo',
              responsivePreview: true, icon: Icons.history, onViewAll: () {},
              items: List.generate(8, (index) => SourceProfileVideoPreviewItem(
                id: '$index', title: index == 0 ? 'Short' : 'Long title requiring two lines',
                note: index == 0 ? '' : 'Actual progress and date',
                cover: const ColoredBox(color: Colors.blue), onOpen: () {})),
            ))))));
        await tester.pump();
        final list = tester.widget<ListView>(find.byType(ListView));
        expect(list.semanticChildCount, 4);
        final available = width - 32;
        final columns = (available / 112).floor().clamp(3, 4);
        final expectedWidth = (available - 12 * (columns - 1)) / columns;
        final poster = tester.getSize(find.byKey(const ValueKey('video-preview.cover.omo-density.0')));
        expect(poster.width, closeTo(expectedWidth, .01));
        expect(poster.width / poster.height, closeTo(2 / 3, .001));
        final title = tester.getSize(find.byKey(const ValueKey('video-preview.title.omo-density.0')));
        final note = tester.getSize(find.byKey(const ValueKey('video-preview.note.omo-density.0')));
        expect(title.height, closeTo(note.height, .01));
        expect(title.height, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final width in [320.0, 390.0, 440.0]) {
    for (final scale in [1.0, 1.4, 2.0]) {
      testWidgets('video rail $width/$scale scrolls with fixed portrait and real actions', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = '', all = 0;
        await tester.pumpWidget(MaterialApp(home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: Padding(
            padding: const EdgeInsets.all(16), child: SourceProfileVideoPreview(
              identity: 'fixture', title: '本机历史', icon: Icons.history,
              onViewAll: () => all++, countLabel: '8',
              items: List.generate(8, (index) => SourceProfileVideoPreviewItem(
                id: '$index', title: 'Long video title 第一部长标题 $index',
                note: '12:30 · 2026-11-06', onOpen: () => opened = '$index',
                cover: Builder(builder: (context) {
                  expect(CollectionCoverPrivacyScope.contains(context), isTrue);
                  return ColoredBox(key: ValueKey('poster.$index'), color: Colors.red);
                }),
              )),
            ),
          ))),
        )));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(const ValueKey('poster.0'))), const Size(80, 120));
        await tester.tap(find.byKey(const ValueKey('video-preview.fixture.0')));
        expect(opened, '0');
        final viewAll = find.descendant(
          of: find.byType(SourceProfilePreviewHeader),
          matching: find.widgetWithText(TextButton, '查看全部'),
        );
        expect(viewAll, findsOneWidget);
        await tester.tap(viewAll);
        expect(all, 1);
        await tester.drag(find.byType(ListView), const Offset(-520, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('generic portrait records use per-row height instead of longest note', (tester) async {
    final items = List.generate(3, (index) => ApiVideoItem(
      id: '$index', title: 'Work $index', detailUrl: Uri.parse('https://example.com/$index')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApiVideoCollection(
      items: items, mode: ApiVideoView.list, onOpen: (_) {}, storageKey: 'compact-profile-records',
      recordNoteBuilder: (item) => item.id == '1' ? List.filled(24, 'Record date').join('\n') : '2026-11-06',
    ))));
    await tester.pump();
    final first = tester.getSize(find.byKey(const ValueKey('api-video.0')));
    final long = tester.getSize(find.byKey(const ValueKey('api-video.1')));
    expect(first.height, 136);
    expect(long.height, greaterThan(first.height));
    expect(tester.takeException(), isNull);
  });
}
