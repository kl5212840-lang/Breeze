import '../video_local_fixture.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/source_shell/models/source_video_module.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/page/source_shell/view/source_profile_video_records.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/view/source_profile_content.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

const _bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';

class _WallpaperApi extends RustLibApi {
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('wallpaper-fixture');
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'source': runtimeName,
        'data': fnPath == 'getUserProfileDetails'
            ? {
                'accountId': 'wallpaper-fixture-account',
                'nickname': 'Wallpaper Account',
                'profileDataSource': 'serverUserEdit',
              }
            : fnPath == 'getUserInfoBundle' ||
                  fnPath == 'getSettingsUserInfoBundle'
            ? {
                'avatar': {'id': 'wallpaper-fixture-account'},
                'extern': {
                  'name': 'Wallpaper Account',
                  'level': 3,
                  'slogan': 'Readable foreground',
                },
              }
            : {
                'items': [],
                'paging': {'page': 1, 'pages': 1, 'hasReachedMax': true},
              },
      }),
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API ${invocation.memberName}');
}

// Flutter checks foundation variables before package:test tearDown runs.
// Restore the override inside the test callback, including assertion failures.
void _iosHostTest(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    await loadUiPreviewFonts();
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _WallpaperApi());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      _iosHostTest(
        'Bika wallpaper keeps hero geometry and clear foreground: $style $brightness',
        (tester) async {
          final directory = Directory.systemTemp.createTempSync(
            'profile_wallpaper_host_',
          );
          final file = File('${directory.path}/wallpaper.png');
          file.writeAsBytesSync(
            img.encodePng(img.Image(width: 40, height: 20)),
          );
          final images = LocalAppearanceImages.instance;
          final previous = images.paths.value;
          images.paths.value = const {};
          final preference = ValueNotifier(style);
          addTearDown(() {
            images.paths.value = previous;
            preference.dispose();
            directory.deleteSync(recursive: true);
          });
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Scaffold(
                  body: SourceProfileContent(
                    source: _bika,
                    avatarUploadFunction: 'uploadAvatar',
                    bioUpdateFunction: 'updateBio',
                    onLogin: () async {},
                    onSettings: () async {},
                    onCloudFavorite: () async {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final name = find.text('Wallpaper Account');
          expect(name, findsOneWidget);
          final before = tester.getRect(name);
          images.paths.value = {'profile:$_bika': file.path};
          await tester.pumpAndSettle();
          expect(tester.getRect(name), before);
          final image = find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is FileImage,
          );
          expect(image, findsOneWidget);
          expect(tester.widget<Image>(image).fit, BoxFit.cover);
          expect(
            find.ancestor(of: name, matching: find.byType(ImageFiltered)),
            findsNothing,
          );
          expect(
            find.ancestor(of: image, matching: find.byType(ClipRect)),
            findsWidgets,
          );
          expect(tester.widget<Text>(name).style?.color, Colors.white);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is ColoredBox &&
                  widget.color == const Color(0x99000000),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text(t.coverPrivacy.wallpaper));
          await tester.pumpAndSettle();
          final sheet = find.byKey(const ValueKey('video-task.body'));
          Finder inside(String label) =>
              find.descendant(of: sheet, matching: find.text(label));
          expect(inside(t.coverPrivacy.wallpaper), findsOneWidget);
          expect(inside(t.coverPrivacy.wallpaperRemove), findsOneWidget);
          expect(inside(t.sourceShell.changeAvatar), findsNothing);
          expect(inside(t.sourceProfile.editBio), findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('profile-own-avatar')));
          await tester.pumpAndSettle();
          expect(inside(t.videoSiteAccount.title), findsOneWidget);
          expect(inside(t.sourceShell.changeAvatar), findsOneWidget);
          expect(inside(t.sourceProfile.editBio), findsOneWidget);
          expect(inside(t.coverPrivacy.wallpaper), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  for (final kind in ['', 'generic', 'jm']) {
    for (final style in ['system', 'breeze']) {
      for (final brightness in Brightness.values) {
        _iosHostTest(
          'own avatar opens its account sheet $kind $style $brightness',
          (tester) async {
            final preference = ValueNotifier(style);
            addTearDown(preference.dispose);
            var opened = 0;
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Scaffold(
                    body: SourceProfileContent(
                      source: kind == 'jm'
                          ? PluginAccountAuthenticationService.jm
                          : _bika,
                      sourceName: '当前插件',
                      profileKind: kind,
                      avatarUploadFunction: kind == '' ? 'uploadAvatar' : '',
                      onLogin: () async {},
                      onCloudFavorite: () async {},
                      onSettings: () async {
                        opened++;
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('profile-own-avatar')));
            await tester.pumpAndSettle();
            expect(opened, 0);
            expect(
              find.byKey(const ValueKey('video-task.body')),
              findsOneWidget,
            );
            final avatarAction = tester.widget<ListTile>(
              find.byKey(const ValueKey('profile-account-avatar-action')),
            );
            expect(avatarAction.onTap, kind == '' ? isNotNull : isNull);
            expect(
              find.byKey(const ValueKey('profile-account-website-action')),
              kind == 'jm' ? findsOneWidget : findsNothing,
            );
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            if (kind == '') {
              final camera = tester.widget<IconButton>(
                find.byKey(const ValueKey('profile-avatar-camera')),
              );
              expect(camera.onPressed, isNotNull);
              expect(
                tester
                    .getSize(
                      find.byKey(const ValueKey('profile-avatar-camera')),
                    )
                    .shortestSide,
                greaterThanOrEqualTo(44),
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      _iosHostTest(
        'one local record section separates comic/video from site $style $brightness',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 1200);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final modules = [
            for (final name in ['movie', 'animate'])
              SourceVideoModule(
                source: _bika,
                title: name == 'movie' ? '电影' : '里番',
                home: Uri.parse('https://$name.fixture/'),
                catalogFn: 'catalog',
                detailFn: 'detail',
                playbackFn: 'play',
                capabilities: const ApiVideoCapabilities(
                  year: false,
                  recent: false,
                ),
              ),
          ];
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  fontFamily: uiPreviewDirectory == null
                      ? null
                      : 'AccountPreview',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.7)),
                  child: RepaintBoundary(
                    key: const ValueKey('profile-record-preview'),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: SourceProfileContent(
                    source: _bika,
                    sourceName: '哔咔',
                    videoModules: modules,
                    onLogin: () async {},
                    onSettings: () async {},
                    onCloudFavorite: () async {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final scroll = find
              .descendant(
                of: find.byType(SourceProfileContent),
                matching: find.byType(Scrollable),
              )
              .first;
          final media = find.byKey(const ValueKey('profile-record-media'));
          await tester.scrollUntilVisible(media, 300, scrollable: scroll);
          await tester.pumpAndSettle();
          NativeVideoSegmentedControl control() =>
              tester.widget<NativeVideoSegmentedControl>(media);
          expect(control().selected, 'comic');
          expect(find.byType(SourceProfileVideoRecords), findsNothing);
          final cloud = tester
              .widgetList<SourceProfileComicPreviewCard>(
                find.byType(SourceProfileComicPreviewCard),
              )
              .singleWhere(
                (value) =>
                    value.previewKey == const ValueKey('profile-preview-cloud'),
              );
          expect(cloud.title, '站点收藏');
          await writeUiPreview(
            tester,
            const ValueKey('profile-record-preview'),
            'profile-comic-records-$style-${brightness.name}',
          );
          await tester.runAsync(useIsolatedVideoResources);
          control().onSelected!('video');
          for (var n = 0; n < 180; n++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 8)),
            );
            await tester.pump(const Duration(milliseconds: 16));
            final rails = tester.widgetList<SourceProfileVideoPreview>(
              find.byType(SourceProfileVideoPreview),
            );
            if (rails.length == 3 && rails.every((rail) => !rail.loading))
              break;
          }
          await tester.pumpAndSettle();
          await writeUiPreview(
            tester,
            const ValueKey('profile-record-preview'),
            'profile-video-records-$style-${brightness.name}',
          );
          expect(find.byType(SourceProfileVideoRecords), findsOneWidget);
          expect(
            find.byKey(const ValueKey('profile-empty-favorite')),
            findsNothing,
          );
          for (final task in ['favorite', 'history', 'download']) {
            expect(find.byKey(ValueKey('profile-video-$task')), findsOneWidget);
          }
          expect(
            find.byKey(const ValueKey('profile-video-records')),
            findsNothing,
          );
          control().onSelected!('comic');
          await tester.pumpAndSettle();
          final favorite = find.byKey(const ValueKey('profile-empty-favorite'));
          await tester.ensureVisible(favorite);
          await tester.tap(favorite);
          await tester.pumpAndSettle();
          expect(find.byType(SourceProfileRecordsView), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  _iosHostTest(
    'declared independent Bika hero queries only its own local records',
    (tester) async {
      const independent = 'fixture-retired-independent-source';
      objectbox.unifiedFavoriteBox.putMany([
        createTestFavorite('independent-favorite')..source = independent,
        createTestFavorite('legacy-favorite')..source = _bika,
      ]);
      objectbox.unifiedHistoryBox.putMany([
        createTestHistory('independent-history')..source = independent,
        createTestHistory('legacy-history')..source = _bika,
      ]);
      objectbox.unifiedDownloadBox.putMany([
        createTestDownload('independent-download')..source = independent,
        createTestDownload('legacy-download')..source = _bika,
      ]);
      await tester.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final preference = ValueNotifier('breeze');
      addTearDown(preference.dispose);
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            home: Scaffold(
              body: SourceProfileContent(
                source: independent,
                sourceName: '哔咔经典',
                profileKind: 'bika',
                onLogin: () async {},
                onSettings: () async {},
                onCloudFavorite: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Lv. 3'),
        findsOneWidget,
        reason: 'The declared brand hero applies without UUID aliasing.',
      );
      final previews = tester
          .widgetList<SourceProfilePreviewSection>(
            find.byType(SourceProfilePreviewSection),
          )
          .toList();
      expect(previews, hasLength(3));
      expect(
        previews
            .expand((value) => value.entries)
            .map((value) => value.id)
            .toSet(),
        {'independent-favorite', 'independent-history', 'independent-download'},
      );
      expect(
        previews
            .expand((value) => value.entries)
            .every((value) => value.source == independent),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
