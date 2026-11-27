import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/widgets/work_list_divider.dart';

ApiVideoItem item(
  String id, {
  String description = '',
  String host = 'example.test',
  bool cover = false,
}) => ApiVideoItem(
  id: id,
  title: '作品$id',
  detailUrl: Uri.parse('https://$host/anime/$id.html'),
  year: '2026',
  remarks: '12集',
  description: description,
  coverUrl: cover ? Uri.parse('https://images.example/$id.jpg') : null,
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget page(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
    'detailed video synopsis expands without opening the work or changing poster geometry',
    (tester) async {
      phone(tester);
      var opens = 0;
      final description = List.filled(
        24,
        'Video synopsis to read in the details panel.',
      ).join(' ');
      await tester.pumpWidget(
        page(
          ApiVideoCollection(
            items: [item('long', description: description)],
            mode: ApiVideoView.list,
            compactDetails: true,
            storageKey: 'source.metadata.disclosure',
            onOpen: (_) => opens++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cover = find.byKey(const ValueKey('video-list.cover.long'));
      final rect = tester.getRect(cover);
      expect(rect.size, const Size(80, 120));
      await tester.tap(find.byTooltip(t.download.workDetails));
      await tester.pumpAndSettle();
      expect(opens, 0);
      final full = find.descendant(
        of: find.byType(ListView),
        matching: find.text(description),
      );
      expect(full, findsOneWidget);
      expect(tester.widget<Text>(full).maxLines, isNull);
      await tester.tap(find.byTooltip(t.common.close));
      await tester.pumpAndSettle();
      expect(tester.getRect(cover), rect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text keeps portrait and landscape cover proportions', (
    tester,
  ) async {
    phone(tester);
    final work = ApiVideoItem(
      id: 'large',
      title: 'A long title that needs more room in accessibility text sizes',
      detailUrl: Uri.parse('https://example.test/anime/large.html'),
      description:
          'A synopsis that is available in full from the work details.',
      genres: 'Adventure',
      language: 'Japanese',
      sourceStatus: 'Complete',
      sourceViews: 123456,
      sourceRating: 8.5,
      doubanScore: 9.1,
    );
    for (final aspect in [2 / 3, 16 / 9]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                body: ApiVideoCollection(
                  items: [work],
                  mode: ApiVideoView.list,
                  compactDetails: true,
                  posterAspectRatio: aspect,
                  contentPadding: EdgeInsets.zero,
                  storageKey: 'source.large-text',
                  onOpen: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cover = tester.getRect(
        find.byKey(const ValueKey('video-list.cover.large')),
      );
      final row = tester.getRect(find.byKey(const ValueKey('api-video.large')));
      final expectedWidth = aspect < 1 ? 80.0 : 390 * .36;
      expect(cover.width, closeTo(expectedWidth, .01));
      expect(cover.height, closeTo(expectedWidth / aspect, .01));
      expect(row.height, greaterThan(cover.height + 16));
      expect(
        find.text(t.videoLibrary.sourceRatingOnly(score: 8.5)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'detailed rows expose available source facts without changing the grid',
    (tester) async {
      phone(tester);
      final work = ApiVideoItem(
        id: 'metadata',
        title: 'Metadata',
        detailUrl: Uri.parse('https://example.test/voddetail/10.html'),
        genres: 'Adventure',
        language: 'Japanese',
        sourceStatus: 'Complete',
        sourceViews: 46,
        sourceViewsAreClicks: true,
        sourceRating: 8.5,
        sourceRatingCount: 20,
        sourceRatingCountConsistent: false,
        doubanScore: 9.1,
      );
      Future<void> show(ApiVideoView mode) => tester.pumpWidget(
        page(
          ApiVideoCollection(
            items: [work],
            mode: mode,
            storageKey: 'source.metadata',
            onOpen: (_) {},
          ),
        ),
      );
      final facts = [
        t.videoLibrary.sourceClicks(count: 46),
        t.videoLibrary.sourceRatingOnly(score: 8.5),
        t.videoLibrary.doubanRating(score: 9.1),
      ];
      await show(ApiVideoView.list);
      for (final fact in facts) {
        expect(find.text(fact), findsOneWidget);
      }
      expect(find.text('Adventure · Japanese · Complete'), findsOneWidget);
      expect(
        find.text(t.videoLibrary.sourceRating(score: 8.5, count: 20)),
        findsNothing,
      );
      await show(ApiVideoView.grid);
      for (final fact in facts) {
        expect(find.text(fact), findsNothing);
      }
    },
  );

  testWidgets(
    'covered grid requests no detail; lazy list requests only nearby rows',
    (tester) async {
      phone(tester);
      final requested = <String>[];
      final pending = <Completer<ApiVideoItem>>[];
      Future<ApiVideoItem> load(ApiVideoItem summary) {
        requested.add(summary.id);
        final request = Completer<ApiVideoItem>();
        pending.add(request);
        return request.future;
      }

      var mode = ApiVideoView.grid;
      late StateSetter update;
      await tester.pumpWidget(
        page(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return ApiVideoCollection(
                items: [for (var i = 0; i < 100; i++) item('$i', cover: true)],
                mode: mode,
                onOpen: (_) {},
                storageKey: 'source.catalog',
                loadDetail: load,
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(requested, isEmpty);
      update(() => mode = ApiVideoView.list);
      await tester.pump();
      expect(requested, isNotEmpty);
      expect(requested.length, lessThan(12));
      expect(requested.toSet().length, requested.length);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < pending.length; i++) {
        pending[i].complete(item(requested[i], description: '迟到详情'));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading and failed enrichment retain existing description and height',
    (tester) async {
      phone(tester);
      final request = Completer<ApiVideoItem>();
      await tester.pumpWidget(
        page(
          ApiVideoCollection(
            items: [
              item('1', description: '已有完整简介'),
              item('2', description: '下一部作品'),
            ],
            mode: ApiVideoView.list,
            onOpen: (_) {},
            storageKey: 'source.favorites',
            loadDetail: (item) =>
                item.id == '1' ? request.future : Future.value(item),
          ),
        ),
      );
      await tester.pump();
      final before = tester.getRect(find.byKey(const ValueKey('api-video.1')));
      final divider = find.byType(WorkListDivider);
      expect(divider, findsOneWidget);
      expect(tester.getRect(divider).width, before.width);
      expect(tester.getRect(divider).bottom, before.bottom);
      expect(find.text('已有完整简介'), findsOneWidget);
      request.completeError(StateError('failed'));
      await tester.pump();
      expect(find.text('已有完整简介'), findsOneWidget);
      expect(find.byKey(const ValueKey('api-detail.retry.1')), findsNothing);
      expect(tester.getRect(find.byKey(const ValueKey('api-video.1'))), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty full response means no synopsis, rather than old summary',
    (tester) async {
      phone(tester);
      final request = Completer<ApiVideoItem>();
      await tester.pumpWidget(
        page(
          ApiVideoCollection(
            items: [item('1', description: '源站已删除的旧简介')],
            mode: ApiVideoView.list,
            onOpen: (_) {},
            storageKey: 'source.empty',
            loadDetail: (_) => request.future,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('源站已删除的旧简介'), findsOneWidget);
      request.complete(item('1'));
      await tester.pumpAndSettle();
      expect(find.text('源站已删除的旧简介'), findsNothing);
      expect(find.text(t.videoLibrary.noSynopsis), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mismatched identity is rejected and retry can return correct detail',
    (tester) async {
      phone(tester);
      var calls = 0;
      ApiVideoItem? opened;
      await tester.pumpWidget(
        page(
          ApiVideoCollection(
            items: [item('1')],
            mode: ApiVideoView.list,
            onOpen: (value) => opened = value,
            storageKey: 'source.retry',
            loadDetail: (_) async => ++calls == 1
                ? item('1', description: '另一来源信息', host: 'other.test')
                : item('1', description: '正确详情'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('另一来源信息'), findsNothing);
      expect(find.text(t.common.loadingFailed), findsOneWidget);
      final retry = find.byKey(const ValueKey('api-detail.retry.1'));
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(opened, isNull, reason: 'Retry must not also open the video');
      expect(find.text('正确详情'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('api-video.1')));
      expect(opened?.description, '正确详情');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source switch invalidates a late result with the same local id',
    (tester) async {
      phone(tester);
      final first = Completer<ApiVideoItem>(),
          second = Completer<ApiVideoItem>();
      var source = 'a';
      final accepted = <String>[];
      late StateSetter update;
      await tester.pumpWidget(
        page(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return ApiVideoCollection(
                items: [item('1')],
                mode: ApiVideoView.list,
                onOpen: (_) {},
                storageKey: '$source.results',
                loadDetail: (_) => source == 'a' ? first.future : second.future,
                onDetailLoaded: (value) => accepted.add(value.description),
              );
            },
          ),
        ),
      );
      await tester.pump();
      update(() => source = 'b');
      await tester.pump();
      first.complete(item('1', description: '上一来源详情'));
      second.complete(item('1', description: '当前来源详情'));
      await tester.pump();
      expect(find.text('上一来源详情'), findsNothing);
      expect(find.text('当前来源详情'), findsOneWidget);
      expect(accepted, ['当前来源详情']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden retained page stops requests and ignores old completion',
    (tester) async {
      phone(tester);
      final requests = <Completer<ApiVideoItem>>[];
      var active = false;
      late StateSetter update;
      await tester.pumpWidget(
        page(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return ApiVideoCollection(
                items: [item('1')],
                mode: ApiVideoView.list,
                onOpen: (_) {},
                storageKey: 'source.retained',
                detailsActive: active,
                loadDetail: (_) {
                  final request = Completer<ApiVideoItem>();
                  requests.add(request);
                  return request.future;
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(requests, isEmpty);
      update(() => active = true);
      await tester.pump();
      expect(requests.length, 1);
      update(() => active = false);
      await tester.pump();
      requests.first.complete(item('1', description: '隐藏期间旧详情'));
      await tester.pump();
      expect(find.text('隐藏期间旧详情'), findsNothing);
      update(() => active = true);
      await tester.pump();
      expect(requests.length, 2);
      requests.last.complete(item('1', description: '重新进入的详情'));
      await tester.pump();
      expect(find.text('重新进入的详情'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pushing a detail route invalidates background list work', (
    tester,
  ) async {
    phone(tester);
    final requests = <Completer<ApiVideoItem>>[];
    final accepted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ApiVideoCollection(
              items: [item('1')],
              mode: ApiVideoView.list,
              storageKey: 'source.route',
              loadDetail: (_) {
                final request = Completer<ApiVideoItem>();
                requests.add(request);
                return request.future;
              },
              onDetailLoaded: (value) => accepted.add(value.description),
              onOpen: (_) => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      Scaffold(appBar: AppBar(title: const Text('详情页'))),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(requests.length, 1);
    await tester.tap(find.byKey(const ValueKey('api-video.1')));
    await tester.pumpAndSettle();
    requests.first.complete(item('1', description: '详情页下方的旧任务'));
    await tester.pumpAndSettle();
    expect(accepted, isEmpty);
    await tester.pageBack();
    await tester.pump();
    expect(requests.length, 2);
    requests.last.complete(item('1', description: '返回后接纳'));
    await tester.pumpAndSettle();
    expect(accepted, ['返回后接纳']);
    expect(tester.takeException(), isNull);
  });
}
