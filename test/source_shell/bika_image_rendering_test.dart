import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/page/comic_info/widgets/creator_info.dart';
import 'package:zephyr/page/comic_read/cubit/image_size_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/image/image_display.dart';
import 'package:zephyr/page/comic_read/widgets/image/read_image_widget.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/widgets/bika_image_rendering_settings.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

import '../test_helper.dart';

late String _imagePath;

const other = '83d82c45-7da1-45ec-9663-f93887b71947';
Map<String, dynamic> info() => {
  'breezeExperience': {
    'bikaExperience': {
      'version': 1,
      'appearanceKey': bikaExperienceAppearanceKey,
      'loadingArtwork': bikaExperienceArtwork,
    },
  },
};
Future<void> install(String source, {bool capable = true}) async {
  final old = objectbox.pluginInfoBox
      .getAll()
      .where((row) => row.uuid == source)
      .firstOrNull;
  await PluginRegistryService.I.upsert(
    PluginInfo(
      id: old?.id ?? 0,
      uuid: source,
      version: '0.1.4',
      originScript: '',
      insertedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isEnabled: true,
      isDeleted: false,
      lastLoadSuccess: true,
      debug: false,
      getInfoJson: jsonEncode(capable ? info() : {}),
    ),
  );
}

Future<void> until(
  WidgetTester tester,
  bool Function() ready, {
  String reason = 'expected rendering state arrives',
}) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    // Bloc streams, filesystem IO and engine decoding can finish between frames.
    // A loading spinner may keep scheduling frames, so settling the whole tree
    // is not a completion signal for an individual image.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: reason);
}

Future<void> _decodeImage(WidgetTester tester, ImageProvider provider) async {
  var decoded = false;
  Object? decodeError;
  StackTrace? decodeStack;
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) {
      expect(info.image.width, greaterThan(0));
      expect(info.image.height, greaterThan(0));
      info.dispose();
      decoded = true;
    },
    onError: (Object error, StackTrace? stack) {
      decodeError = error;
      decodeStack = stack;
    },
  );
  stream.addListener(listener);
  try {
    // The production provider started in the widget's fake-async zone. Awaiting
    // its stream entirely inside runAsync strands that zone's continuations.
    // Let native IO/codec work run, then pump between stages until a real frame
    // reaches the same stream consumed by the cover/reading widget.
    await until(
      tester,
      () => decoded || decodeError != null,
      reason: 'actual file image provider decodes a nonempty image frame',
    );
    if (decodeError != null) {
      Error.throwWithStackTrace(
        decodeError!,
        decodeStack ?? StackTrace.current,
      );
    }
  } finally {
    stream.removeListener(listener);
  }
}

class _Sizes extends Cubit<ImageSizeState> implements ImageSizeCubit {
  _Sizes()
    : super(
        ImageSizeState(
          sizeCache: {},
          resolvedIndices: {},
          defaultWidth: 100,
          defaultHeight: 100,
        ),
      );
  @override
  ({Size size, bool isCached}) getSize(int index) =>
      (size: const Size(100, 100), isCached: true);
  @override
  void updateSize(int index, Size size) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget cover(String source, String key) => CoverWidget(
  key: ValueKey(key),
  from: source,
  fileServer: '',
  path: '',
  id: key,
  pictureType: PictureType.cover,
  width: 100,
  height: 120,
);
Widget readers({List<String> sources = const [bikaPlusSourceId, other]}) =>
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => GlobalSettingCubit()),
        BlocProvider(create: (_) => ComicReadPreferenceCubit()),
        BlocProvider(create: (_) => ReaderCubit()),
        BlocProvider<ImageSizeCubit>(create: (_) => _Sizes()),
      ],
      child: Row(
        children: [
          for (final source in sources)
            SizedBox(
              width: 120,
              child: ReadImageWidget(
                key: ValueKey(source),
                pictureInfo: PictureInfo(from: source),
                index: 0,
                isColumn: true,
              ),
            ),
        ],
      ),
    );
PictureBloc pictureBloc(WidgetTester tester, Finder owner) {
  final builder = find.descendant(
    of: owner,
    matching: find.byWidgetPredicate(
      (widget) => widget is BlocBuilder<PictureBloc, PictureLoadState>,
    ),
  );
  expect(builder, findsOneWidget);
  return tester.element(builder).read<PictureBloc>();
}

Iterable<DecorationImage> _decorations(WidgetTester tester, Finder owner) =>
    tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.descendant(
              of: owner,
              matching: find.byType(SourceImageFilterQualityBuilder),
            ),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.image)
        .whereType<DecorationImage>();

DecorationImage decoration(WidgetTester tester, String key) =>
    _decorations(tester, find.byKey(ValueKey(key))).single;

Future<void> showImage(WidgetTester tester, Finder owner) async {
  final bloc = pictureBloc(tester, owner);
  // The empty picture path deliberately terminates the real request locally.
  // Wait for that handler before injecting success, so it cannot overwrite it.
  await until(
    tester,
    () => bloc.state.status == PictureLoadStatus.failure,
    reason: 'empty-path picture request terminates before fixture injection',
  );
  bloc.emit(
    PictureLoadState(status: PictureLoadStatus.success, imagePath: _imagePath),
  );
  await until(
    tester,
    () => find
        .descendant(
          of: owner,
          matching: find.byType(SourceImageFilterQualityBuilder),
        )
        .evaluate()
        .isNotEmpty,
    reason: 'real BlocBuilder receives the asynchronous success stream event',
  );

  final images = find.descendant(of: owner, matching: find.byType(Image));
  final isCover = tester.widget(owner) is CoverWidget;
  final provider = isCover
      ? _decorations(tester, owner).single.image
      : tester.widget<Image>(images).image;
  // Resolve the actual production provider with real IO and engine decoding.
  // Its cached stream is shared by the decoration/reading Image consumer.
  await _decodeImage(tester, provider);
  if (!isCover) {
    await until(
      tester,
      () => find
          .descendant(
            of: owner,
            matching: find.byWidgetPredicate(
              (widget) => widget is RawImage && widget.image != null,
            ),
          )
          .evaluate()
          .isNotEmpty,
      reason: 'reading Image.file presents a decoded image frame',
    );
  }
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const changes = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUpAll(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
    final fixture = File(
      '${TestObjectBoxHelper.tempPath}/rendering-fixture.png',
    );
    await fixture.writeAsBytes(
      await File('asset/image/assets/default_cover.png').readAsBytes(),
    );
    _imagePath = fixture.path;
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(changes, null);
    await TestObjectBoxHelper.tearDownTestObjectBox();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPluginInstallationState.instance.reload();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    await PluginRegistryService.I.refreshFromDb();
    await install(bikaPlusSourceId);
    await install(other);
  });

  testWidgets(
    'comic creator uses the bundled avatar for the site placeholder',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreatorInfoWidget(
              creator: Creator(
                id: 'creator-fixture',
                name: 'Fixture creator',
                avatar: ComicImage(
                  id: 'avatar-fixture',
                  url: 'https://example.invalid/nopic-Male.gif',
                  name: '',
                ),
              ),
              from: 'avatar-fixture',
              imageKey: 'comic-fixture',
            ),
          ),
        ),
      );
      final avatar = tester.widget<Image>(find.byType(Image));
      expect(
        avatar.image,
        const AssetImage('asset/image/assets/default_cover.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Plus cover updates share its source choice and keep another source independent',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                cover(bikaPlusSourceId, 'plus-a'),
                cover(bikaPlusSourceId, 'plus-b'),
                cover(other, 'other'),
              ],
            ),
          ),
        ),
      );
      for (final key in ['plus-a', 'plus-b', 'other']) {
        await showImage(tester, find.byKey(ValueKey(key)));
      }
      final provider = decoration(tester, 'plus-a').image;
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'high',
      );
      savePluginConfigValueSync(other, bikaImageFilterQualityKey, 'low');
      await until(
        tester,
        () =>
            decoration(tester, 'plus-a').filterQuality == FilterQuality.high &&
            decoration(tester, 'plus-b').filterQuality == FilterQuality.high &&
            decoration(tester, 'other').filterQuality == FilterQuality.medium,
      );
      expect(decoration(tester, 'plus-a').image, same(provider));
      await tester.runAsync(() => install(bikaPlusSourceId, capable: false));
      await until(
        tester,
        () =>
            decoration(tester, 'plus-a').filterQuality == FilterQuality.medium,
      );
      expect(decoration(tester, 'other').filterQuality, FilterQuality.medium);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Plus reading images receive updates without replacing their image provider',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: readers())));
      for (final source in [bikaPlusSourceId, other]) {
        await showImage(tester, find.byKey(ValueKey(source)));
      }
      Image image(String source) => tester.widget<Image>(
        find.descendant(
          of: find.byKey(ValueKey(source)),
          matching: find.byType(Image),
        ),
      );
      final provider = image(bikaPlusSourceId).image;
      final state = tester.state(find.byKey(const ValueKey(bikaPlusSourceId)));
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'none',
      );
      await until(
        tester,
        () => image(bikaPlusSourceId).filterQuality == FilterQuality.none,
      );
      expect(image(other).filterQuality, FilterQuality.medium);
      expect(image(bikaPlusSourceId).image, provider);
      expect(
        tester.state(find.byKey(const ValueKey(bikaPlusSourceId))),
        same(state),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a retained rendering consumer switches its source lease before later updates',
    (tester) async {
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'high',
      );
      savePluginConfigValueSync(other, bikaImageFilterQualityKey, 'low');
      final source = ValueNotifier(bikaPlusSourceId);
      addTearDown(source.dispose);
      FilterQuality? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<String>(
            valueListenable: source,
            builder: (_, value, _) => SourceImageFilterQualityBuilder(
              source: value,
              builder: (_, quality) {
                seen = quality;
                return Text(quality.name);
              },
            ),
          ),
        ),
      );
      expect(seen, FilterQuality.high);
      source.value = other;
      await tester.pump();
      expect(seen, FilterQuality.medium);
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'none',
      );
      savePluginConfigValueSync(other, bikaImageFilterQualityKey, 'high');
      await tester.pump();
      expect(seen, FilterQuality.medium);
      source.value = bikaPlusSourceId;
      await until(tester, () => seen == FilterQuality.none);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'actual cover sampling changes outside the source shell without changing image identity or another source',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [cover(bikaPlusSourceId, 'bk'), cover(other, 'other')],
            ),
          ),
        ),
      );
      await showImage(tester, find.byKey(const ValueKey('bk')));
      await showImage(tester, find.byKey(const ValueKey('other')));
      expect(decoration(tester, 'bk').filterQuality, FilterQuality.medium);
      final provider = decoration(tester, 'bk').image;
      final retained = tester.state(find.byKey(const ValueKey('bk')));
      final retainedBloc = pictureBloc(
        tester,
        find.byKey(const ValueKey('bk')),
      );
      savePluginConfigValueSync(other, bikaImageFilterQualityKey, 'high');
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'none',
      );
      await until(
        tester,
        () => decoration(tester, 'bk').filterQuality == FilterQuality.none,
      );
      expect(decoration(tester, 'other').filterQuality, FilterQuality.medium);
      expect(decoration(tester, 'bk').image, same(provider));
      expect(tester.state(find.byKey(const ValueKey('bk'))), same(retained));
      expect(
        pictureBloc(tester, find.byKey(const ValueKey('bk'))),
        same(retainedBloc),
      );
      await tester.runAsync(() => install(bikaPlusSourceId, capable: false));
      await until(
        tester,
        () => decoration(tester, 'bk').filterQuality == FilterQuality.medium,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  for (final style in ['original', 'follow']) {
    testWidgets('BK $style sampling is source-bound inside a branded route', (
      tester,
    ) async {
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaExperienceAppearanceKey,
        style,
      );
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'high',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (_) => Scaffold(
              body: Row(
                children: [
                  cover(bikaPlusSourceId, 'bk'),
                  cover(other, 'other'),
                ],
              ),
            ),
          ),
        ),
      );
      await showImage(tester, find.byKey(const ValueKey('bk')));
      await showImage(tester, find.byKey(const ValueKey('other')));
      expect(decoration(tester, 'bk').filterQuality, FilterQuality.high);
      expect(decoration(tester, 'other').filterQuality, FilterQuality.medium);
      final provider = decoration(tester, 'bk').image;
      final retained = tester.state(find.byKey(const ValueKey('bk')));
      final retainedBloc = pictureBloc(
        tester,
        find.byKey(const ValueKey('bk')),
      );
      savePluginConfigValueSync(other, bikaImageFilterQualityKey, 'none');
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'low',
      );
      await until(
        tester,
        () => decoration(tester, 'bk').filterQuality == FilterQuality.low,
      );
      expect(decoration(tester, 'other').filterQuality, FilterQuality.medium);
      expect(decoration(tester, 'bk').image, same(provider));
      expect(tester.state(find.byKey(const ValueKey('bk'))), same(retained));
      expect(
        pictureBloc(tester, find.byKey(const ValueKey('bk'))),
        same(retainedBloc),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'real reading Image.file receives the source choice even without a source route',
    (tester) async {
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'low',
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: readers())));
      await showImage(tester, find.byKey(const ValueKey(bikaPlusSourceId)));
      await showImage(tester, find.byKey(const ValueKey(other)));
      Image image(String source) => tester.widget<Image>(
        find.descendant(
          of: find.byKey(ValueKey(source)),
          matching: find.byType(Image),
        ),
      );
      expect(image(bikaPlusSourceId).filterQuality, FilterQuality.low);
      expect(image(other).filterQuality, FilterQuality.medium);
      final imageProvider = image(bikaPlusSourceId).image;
      final retainedReader = tester.state(
        find.byKey(const ValueKey(bikaPlusSourceId)),
      );
      final retainedBloc = pictureBloc(
        tester,
        find.byKey(const ValueKey(bikaPlusSourceId)),
      );
      final display = tester.state(
        find.descendant(
          of: find.byKey(const ValueKey(bikaPlusSourceId)),
          matching: find.byType(ImageDisplay),
        ),
      );
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        'high',
      );
      await until(
        tester,
        () => image(bikaPlusSourceId).filterQuality == FilterQuality.high,
      );
      expect(image(bikaPlusSourceId).image, imageProvider);
      expect(
        tester.state(find.byKey(const ValueKey(bikaPlusSourceId))),
        same(retainedReader),
      );
      expect(
        pictureBloc(tester, find.byKey(const ValueKey(bikaPlusSourceId))),
        same(retainedBloc),
      );
      expect(
        tester.state(
          find.descendant(
            of: find.byKey(const ValueKey(bikaPlusSourceId)),
            matching: find.byType(ImageDisplay),
          ),
        ),
        same(display),
      );
      expect(image(other).filterQuality, FilterQuality.medium);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('render setting saves only its local key and verifies readback', (
    tester,
  ) async {
    savePluginConfigValueSync(bikaPlusSourceId, 'image.quality', 'original');
    await tester.pumpWidget(
      const MaterialApp(
        home: BikaImageRenderingSettingsPage(source: bikaPlusSourceId),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<SettingChoiceTile<FilterQuality>>(
      find.byKey(const ValueKey('bika-image-filter-quality')),
    );
    expect(tile.value, FilterQuality.medium);
    tile.onChanged(FilterQuality.high);
    await tester.pump();
    for (var frame = 0; frame < 7; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final savedTile = tester.widget<SettingChoiceTile<FilterQuality>>(
      find.byKey(const ValueKey('bika-image-filter-quality')),
    );
    expect(savedTile.value, FilterQuality.high);
    expect(savedTile.enabled, isTrue);
    expect(savedTile.error, isNull);
    expect(
      loadPluginConfigValue<String>(
        bikaPlusSourceId,
        bikaImageFilterQualityKey,
        fallback: '',
      ),
      'high',
    );
    expect(
      loadPluginConfigValue<String>(
        bikaPlusSourceId,
        'image.quality',
        fallback: '',
      ),
      'original',
    );
    expect(
      loadPluginConfigValue<String>(
        other,
        bikaImageFilterQualityKey,
        fallback: '',
      ),
      '',
    );
    expect(find.text(t.common.saved), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    toastification.managers.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'failed rendering write does not report success or advance the selected value',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BikaImageRenderingSettingsPage(
            source: bikaPlusSourceId,
            read: (_) async => 'medium',
            save: (_, _, _) async => throw StateError('synthetic save failure'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      SettingChoiceTile<FilterQuality> tile() => tester.widget(
        find.byKey(const ValueKey('bika-image-filter-quality')),
      );
      tile().onChanged(FilterQuality.high);
      await tester.pumpAndSettle();
      expect(tile().value, FilterQuality.medium);
      expect(
        find.text(t.sourceShell.bikaImageRenderingSaveFailed),
        findsOneWidget,
      );
      expect(find.text(t.common.saved), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a no-op rendering write fails readback instead of reporting saved',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BikaImageRenderingSettingsPage(
            source: bikaPlusSourceId,
            read: (_) async => 'medium',
            save: (_, _, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tile = tester.widget<SettingChoiceTile<FilterQuality>>(
        find.byKey(const ValueKey('bika-image-filter-quality')),
      );
      tile.onChanged(FilterQuality.high);
      await tester.pumpAndSettle();
      expect(
        find.text(t.sourceShell.bikaImageRenderingNotUpdated),
        findsOneWidget,
      );
      expect(find.text(t.common.saved), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
