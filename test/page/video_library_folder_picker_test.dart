import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_visual.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';

final film = ApiVideoItem(
  id: '7',
  title: '作品',
  detailUrl: Uri.parse('https://example.test/7'),
);

class _DelayedStore extends VideoLibraryStore {
  _DelayedStore() : super(deviceId: 'fixture', storageKey: 'picker-fixture');
  Completer<void>? gate;
  @override
  Future<void> setFavorite(
    String source,
    ApiVideoItem item,
    bool favorite, {
    Set<String>? folderIds,
  }) async {
    await gate?.future;
    await super.setFavorite(source, item, favorite, folderIds: folderIds);
  }
}

void main() {
  late _DelayedStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _DelayedStore();
  });
  tearDown(() {
    store.dispose();
  });
  Finder key(String value) => find.byKey(ValueKey('video-folder.$value'));
  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    double keyboard = 0,
    VideoFolderAssignment? assignment,
    Set<String> itemKeys = const {},
    String source = 'a',
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
              child: const Text('打开'),
              onPressed: () => showVideoFolderPicker(
                context,
                source: source,
                item: assignment == null ? film : null,
                itemKeys: itemKeys,
                assignment: assignment,
                store: store,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'short folder picker is an island; cancelling selection leaves the complete store unchanged',
    (tester) async {
      final folder = await store.createFolder('a', '今晚看');
      await store.setFavorite('a', film, true);
      final before = jsonEncode((await store.read()).toJson());
      await open(tester);
      expect(find.byType(BottomSheet), findsNothing);
      final surface = find.byKey(const ValueKey('bookshelf.island.surface'));
      expect(tester.getSize(surface).height, lessThan(500));
      expect(find.byType(BookshelfFolderIcon), findsOneWidget);
      await tester.tap(key('option.$folder'));
      await tester.pump();
      await tester.tap(key('cancel'));
      await tester.pumpAndSettle();
      expect(jsonEncode((await store.read()).toJson()), before);
    },
  );

  testWidgets(
    'empty folder list offers inline creation and cancelling its draft writes nothing',
    (tester) async {
      await open(tester);
      expect(find.text(t.common.empty), findsOneWidget);
      await tester.tap(key('new'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(key('new-name'), '暂不创建');
      await tester.tap(key('cancel-create'));
      await tester.pumpAndSettle();
      expect((await store.read()).foldersFor('a'), isEmpty);
      await tester.tap(key('new'));
      await tester.pumpAndSettle();
      await tester.enterText(key('new-name'), '今晚看');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final folders = (await store.read()).foldersFor('a');
      expect(folders.values.single.data['name'], '今晚看');
      expect((await store.read()).foldersFor('b'), isEmpty);
      await tester.tap(key('save'));
      await tester.pumpAndSettle();
      expect(
        (await store.read()).foldersOf(VideoLibraryStore.itemKey('a', '7')),
        {folders.keys.single},
      );
    },
  );

  testWidgets(
    '320 double text keyboard keeps full save/cancel while long folders scroll',
    (tester) async {
      for (var index = 0; index < 12; index++) {
        await store.createFolder('a', '分类文件夹 $index');
      }
      await open(tester, scale: 2, keyboard: 280);
      for (final id in ['save', 'cancel', 'close']) {
        expect(tester.getSize(key(id)).height, greaterThanOrEqualTo(44));
        expect(tester.getRect(key(id)).bottom, lessThanOrEqualTo(460));
      }
      expect(find.byKey(const ValueKey('video-folder.search')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(key('cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'saving blocks outside dismissal, close, and duplicate writes until completion',
    (tester) async {
      await open(tester);
      final gate = store.gate = Completer<void>();
      await tester.tap(key('save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(key('save')).onPressed, isNull);
      expect(tester.widget<TextButton>(key('cancel')).onPressed, isNull);
      await tester.tapAt(const Offset(3, 3));
      await tester.pump();
      expect(key('save'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(key('save'), findsNothing);
      expect((await store.read()).contains('a', '7'), isTrue);
    },
  );
  for (final assignment in VideoFolderAssignment.values) {
    testWidgets(
      '${assignment.name} assigns existing multi-source favorites to a shared folder',
      (tester) async {
        final oldA = await store.createFolder('a', 'Old A');
        final oldB = await store.createFolder('b', 'Old B');
        final target = await store.createFolder(
          VideoLibraryStore.sharedFolderSource,
          'Shared target',
        );
        await store.setFavorite('a', film, true, folderIds: {oldA});
        await store.setFavorite('b', film, true, folderIds: {oldB});
        final a = VideoLibraryStore.itemKey('a', film.id);
        final b = VideoLibraryStore.itemKey('b', film.id);
        final before = await store.read();
        await open(
          tester,
          assignment: assignment,
          itemKeys: {a, b},
          source: VideoLibraryStore.sharedFolderSource,
        );
        expect(
          find.text(
            assignment == VideoFolderAssignment.move
                ? t.bookshelf.moveTo
                : t.bookshelf.copyTo,
          ),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(key('save')).onPressed, isNull);
        expect(key('option.$oldA'), findsNothing);
        expect(key('option.$oldB'), findsNothing);
        if (assignment == VideoFolderAssignment.copy) {
          expect(key('unfiled'), findsNothing);
        }
        await tester.tap(key('option.$target'));
        await tester.pump();
        expect(tester.widget<FilledButton>(key('save')).onPressed, isNotNull);
        await tester.tap(key('save'));
        await tester.pumpAndSettle();
        final after = await store.read();
        expect(
          after.foldersOf(a),
          assignment == VideoFolderAssignment.move ? {target} : {oldA, target},
        );
        expect(
          after.foldersOf(b),
          assignment == VideoFolderAssignment.move ? {target} : {oldB, target},
        );
        expect(
          jsonEncode(
            after.favorites.map((key, value) => MapEntry(key, value.toJson())),
          ),
          jsonEncode(
            before.favorites.map((key, value) => MapEntry(key, value.toJson())),
          ),
        );
        expect(key('save'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${assignment.name} cancel discards targets without writing memberships',
      (tester) async {
        final old = await store.createFolder('a', 'Original');
        final target = await store.createFolder('a', 'Target');
        await store.setFavorite('a', film, true, folderIds: {old});
        final itemKey = VideoLibraryStore.itemKey('a', film.id);
        final before = jsonEncode((await store.read()).toJson());
        await open(tester, assignment: assignment, itemKeys: {itemKey});
        expect(tester.widget<FilledButton>(key('save')).onPressed, isNull);
        await tester.tap(key('option.$target'));
        await tester.pump();
        await tester.tap(key('cancel'));
        await tester.pumpAndSettle();
        expect(jsonEncode((await store.read()).toJson()), before);
        expect(key('save'), findsNothing);
      },
    );
  }

  testWidgets(
    'move clears a single favorite only after explicit Unfiled selection',
    (tester) async {
      final old = await store.createFolder('a', 'Original');
      await store.setFavorite('a', film, true, folderIds: {old});
      final itemKey = VideoLibraryStore.itemKey('a', film.id);
      await open(
        tester,
        assignment: VideoFolderAssignment.move,
        itemKeys: {itemKey},
      );
      expect(tester.widget<FilledButton>(key('save')).onPressed, isNull);
      await tester.tap(key('option.$old'));
      await tester.pump();
      expect(tester.widget<FilledButton>(key('save')).onPressed, isNotNull);
      await tester.tap(key('option.$old'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(key('save')).onPressed,
        isNull,
        reason:
            'Deselecting a target is not an instruction to clear existing folders',
      );
      expect((await store.read()).foldersOf(itemKey), {old});
      await tester.tap(key('unfiled'));
      await tester.pump();
      expect(tester.widget<FilledButton>(key('save')).onPressed, isNotNull);
      await tester.tap(key('save'));
      await tester.pumpAndSettle();
      final after = await store.read();
      expect(after.foldersOf(itemKey), isEmpty);
      expect(after.contains('a', film.id), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
