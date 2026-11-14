import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/object_box/model.dart' show ComicFolderType;
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/models/collect_comic.dart';
import 'package:zephyr/page/comic_info/models/favorite_workflow.dart';
import 'package:zephyr/page/comic_info/widgets/comic_operation.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

NormalComicAllInfo _detail({bool allowed = true, bool collected = false}) =>
    NormalComicAllInfo.fromJson({
      'comicInfo': {
        'id': 'work',
        'title': 'fixture',
        'titleMeta': [],
        'description': '',
        'cover': {'id': 'work', 'url': '', 'name': ''},
        'metadata': [],
      },
      'eps': [],
      'recommend': [],
      'allowCollected': allowed,
      'isFavourite': collected,
    });

Widget _host({
  required String style,
  required GlobalSettingCubit settings,
  required ComicFollowCubit follows,
  required Widget child,
}) {
  final preference = ValueNotifier(style);
  addTearDown(preference.dispose);
  return AppInterfaceStyleScope(
    style: preference,
    child: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settings),
        BlocProvider.value(value: follows),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.comicFollowBox.removeAll();
  });

  test('removing a local favorite also removes its legacy aliases', () async {
    await setLocalComicFavorite(
      from: 'fixture',
      normalInfo: _detail(),
      collected: true,
    );
    final legacy = createTestFavorite(' fixture :work')
      ..source = ' fixture '
      ..comicId = 'work';
    final other = createTestFavorite('other:work')
      ..source = 'other'
      ..comicId = 'work';
    objectbox.unifiedFavoriteBox.putMany([legacy, other]);
    ComicLinkService.addComic(legacy.uniqueKey, null, ComicFolderType.favorite);
    ComicLinkService.addComic(other.uniqueKey, null, ComicFolderType.favorite);

    final result = await setLocalComicFavorite(
      from: 'fixture',
      normalInfo: _detail(),
      collected: false,
    );
    expect(result, (collected: false, changed: true));
    expect(objectbox.unifiedFavoriteBox.get(legacy.id)!.deleted, isTrue);
    expect(
      ComicLinkService.linksOfComic(legacy.uniqueKey, ComicFolderType.favorite),
      isEmpty,
    );
    expect(objectbox.unifiedFavoriteBox.get(other.id)!.deleted, isFalse);
    expect(
      ComicLinkService.linksOfComic(other.uniqueKey, ComicFolderType.favorite),
      hasLength(1),
    );
  });

  test('legacy cover repair cannot defeat a newer cloud removal', () async {
    await setLocalComicFavorite(
      from: 'fixture',
      normalInfo: _detail(),
      collected: true,
    );
    final favorite = objectbox.unifiedFavoriteBox.getAll().single
      ..cover = '{"id":"work","url":"https://example.test/cover.jpg"}'
      ..createdAt = DateTime.utc(2020)
      ..updatedAt = DateTime.utc(2020);
    objectbox.unifiedFavoriteBox.put(favorite);
    final removal = {
      ...favorite.toJson(),
      'updatedAt': DateTime.utc(2020, 1, 2).toIso8601String(),
      'deleted': true,
    };

    expect(
      await isLocalComicCollected(from: 'fixture', comicId: 'work'),
      isTrue,
    );
    final repaired = objectbox.unifiedFavoriteBox.getAll().single;
    expect(jsonDecode(repaired.cover)['path'], 'work.jpg');
    ComicSyncCore.mergeUnifiedData(
      objectbox.store,
      {
        'favorites': [removal],
      },
      participatingSources: {'fixture'},
    );
    expect(objectbox.unifiedFavoriteBox.getAll().single.deleted, isTrue);
  });

  testWidgets(
    'confirming removal cannot re-add a favorite removed while the dialog was open',
    (tester) async {
      final settings = GlobalSettingCubit();
      final follows = ComicFollowCubit();
      addTearDown(settings.close);
      addTearDown(follows.close);
      final info = _detail(allowed: false);
      await tester.pumpWidget(
        _host(
          style: 'breeze',
          settings: settings,
          follows: follows,
          child: ComicOperationWidget(
            normalInfo: info,
            from: 'fixture',
            comicInfo: info,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star));
      await tester.pumpAndSettle();
      expect(find.text(t.comicInfo.confirmUncollectTitle), findsOneWidget);

      final saved = objectbox.unifiedFavoriteBox.getAll().single;
      saved.deleted = true;
      objectbox.unifiedFavoriteBox.put(saved);
      await tester.tap(find.text(t.common.confirm));
      await tester.pumpAndSettle();

      expect(objectbox.unifiedFavoriteBox.getAll().single.deleted, isTrue);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(
        objectbox.comicLinkBox.getAll().every((link) => link.deletedAt != null),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'favorite preference falls back locally and cancel preserves follow $style',
      (tester) async {
        final settings = GlobalSettingCubit()
          ..updateALl(
            const GlobalSettingState(
              cloudFavoritePreferred: true,
              autoFollowOnCollect: true,
            ),
          );
        final follows = ComicFollowCubit();
        addTearDown(settings.close);
        addTearDown(follows.close);
        var info = _detail(allowed: false);
        late StateSetter update;
        await tester.pumpWidget(
          _host(
            style: style,
            settings: settings,
            follows: follows,
            child: StatefulBuilder(
              builder: (_, rebuild) {
                update = rebuild;
                return ComicOperationWidget(
                  normalInfo: info,
                  from: 'local-$style',
                  comicInfo: info,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.cloud_outlined), findsNothing);
        expect(find.byIcon(Icons.star_border), findsOneWidget);
        await tester.tap(find.byIcon(Icons.star_border));
        await tester.pumpAndSettle();
        expect(objectbox.unifiedFavoriteBox.getAll().single.deleted, isFalse);
        expect(objectbox.comicFollowBox.getAll().single.source, 'local-$style');
        await tester.tap(find.byIcon(Icons.star));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(objectbox.unifiedFavoriteBox.getAll().single.deleted, isFalse);
        expect(objectbox.comicFollowBox.getAll(), hasLength(1));
        // No login state is used to decide capability: an allowed but anonymous
        // source keeps its remote favorite action reachable.
        update(() => info = _detail());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
        settings.updateState(
          (state) => state.copyWith(cloudFavoritePreferred: false),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.star), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    for (final outcome in [
      'add',
      'remaining',
      'cancel',
      'failure',
      'account-change',
      'refresh',
      'page-change',
      'unchanged',
    ]) {
      testWidgets(
        'favorite $outcome rejects duplicates and only a new success follows $style',
        (tester) async {
          final settings = GlobalSettingCubit()
            ..updateALl(
              const GlobalSettingState(
                cloudFavoritePreferred: true,
                autoFollowOnCollect: true,
              ),
            );
          final follows = ComicFollowCubit();
          addTearDown(settings.close);
          addTearDown(follows.close);
          final pending = Completer<bool>();
          final notices = <ToastEvent>[];
          final subscription = eventBus.on<ToastEvent>().listen(notices.add);
          addTearDown(subscription.cancel);
          var calls = 0;
          var info = _detail(collected: outcome == 'remaining');
          final source = '$style-$outcome';
          late StateSetter update;
          await tester.pumpWidget(
            _host(
              style: style,
              settings: settings,
              follows: follows,
              child: StatefulBuilder(
                builder: (_, rebuild) {
                  update = rebuild;
                  return ComicOperationWidget(
                    normalInfo: info,
                    from: source,
                    comicInfo: info,
                    collectionTargetId: outcome == 'remaining'
                        ? 'one-folder'
                        : null,
                    cloudFavoriteAction: (current) {
                      calls++;
                      expect(current, outcome == 'remaining');
                      return pending.future;
                    },
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final action = find.byIcon(
            outcome == 'remaining'
                ? Icons.cloud_done_outlined
                : Icons.cloud_outlined,
          );
          await tester.tap(action);
          await tester.tap(action);
          expect(calls, 1);
          if (outcome == 'account-change')
            pluginSessionWriteFence.advance(source);
          if (outcome == 'refresh') {
            update(() => info = info.copyWith(totalComments: 1));
            await tester.pump();
          }
          if (outcome == 'page-change')
            await tester.pumpWidget(const SizedBox.shrink());
          if (outcome == 'cancel') {
            pending.completeError(
              const FavoriteWorkflowIncompleteException(
                FavoriteWorkflowExecutionResult(
                  status: FavoriteWorkflowStatus.cancelled,
                ),
              ),
            );
          } else if (outcome == 'failure') {
            pending.completeError(StateError('fixture favorite failed'));
          } else {
            pending.complete(outcome != 'unchanged');
          }
          await tester.pumpAndSettle();
          expect(
            objectbox.comicFollowBox.getAll(),
            hasLength(outcome == 'add' ? 1 : 0),
          );
          final successes = notices.where(
            (event) => event.type == ToastType.success,
          );
          expect(
            successes,
            hasLength(outcome == 'add' || outcome == 'remaining' ? 1 : 0),
          );
          if (outcome == 'remaining') {
            expect(successes.single.message, t.comicInfo.removedFromCloudFolder);
          }
          if (outcome == 'unchanged') {
            expect(notices.last.type, ToastType.info);
            expect(notices.last.message, t.comicInfo.cloudUncollectedState);
          }
          if (outcome == 'account-change' || outcome == 'refresh') {
            expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
