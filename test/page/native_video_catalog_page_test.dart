import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/video/video_verification_gate.dart';
import 'package:zephyr/page/video/video_personal_overview.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Verify external browser dispatch without navigating to a real site.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_video_catalog_page.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/native_video_auth_form.dart';
import 'package:zephyr/page/video/native_video_account_form.dart';
import 'package:zephyr/page/video/video_site_forms.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/video_search_filter_panel.dart';
import 'package:zephyr/page/video/video_card_metadata.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';

class _OfficialWebsiteLauncher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  final launches = <({String url, PreferredLaunchMode mode})>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url: url, mode: options.mode));
    return true;
  }
}

// Media boundary for route-return behavior, not a real-site acceptance.
class _ReturnVideoPlatform extends VideoPlayerPlatform {
  final _events = <int, StreamController<VideoEvent>>{};
  int _id = 0;
  int playCount = 0;
  int get activePlayers => _events.length;
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource source) async {
    final id = ++_id;
    position = Duration.zero;
    final events = _events[id] = StreamController<VideoEvent>.broadcast();
    Timer.run(
      () => events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1920, 1080),
        ),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;
  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose(int playerId) async => _events.remove(playerId)?.close();
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<void> setLooping(int playerId, bool value) async {}
  @override
  Future<void> setVolume(int playerId, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double value) async {}
  @override
  Future<void> play(int playerId) async {
    playCount++;
    _events[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async => _events[playerId]?.add(
    VideoEvent(
      eventType: VideoEventType.isPlayingStateUpdate,
      isPlaying: false,
    ),
  );
  @override
  Future<void> seekTo(int playerId, Duration value) async => position = value;
  @override
  Future<Duration> getPosition(int playerId) async => position;
}

/// A platform boundary, not a replacement catalog widget: tests exercise the
/// real page, callbacks, parser calls, navigation and visible mode controls.
class _WebPlatform extends InAppWebViewPlatform {
  late PlatformInAppWebViewWidgetCreationParams params;
  late final controller = _WebController(this);
  final loads = <Uri>[];
  bool created = false;
  final documents = <_WebPlatform>[];
  final _documentsByOwner = <Object, _WebPlatform>{};
  bool hangSnapshot = false;
  Map<String, dynamic> domSnapshot = {};
  Map<String, dynamic>? creatorDirectory;
  Map<String, dynamic>? resolvedCreator;
  Future<dynamic>? nextCreatorRead;
  int directoryReads = 0, creatorResolutions = 0;

  bool challenge = false;
  bool siteReady = true;
  bool authUiReady = false;
  Future<dynamic>? nextSiteState;
  Future<dynamic>? nextTimeOrigin;
  int creations = 0;
  Future<WebUri?>? nextUrl;
  Uri? currentUrl;
  final inspectionChanges = <bool>[];
  bool failInspection = false;
  final verificationWindows = <Uri>[];
  Completer<bool>? verificationWindowResult;
  String profileHref = '';
  bool signedOutEntry = true;
  int accountReads = 0;
  Map<String, dynamic> accountMetadata = {
    'supported': true,
    'signedIn': true,
    'profileReady': true,
    'passwordReady': true,
    'avatarReady': false,
    'logoutReady': true,
    'otpReady': false,
    'name': 'Private account fixture',
    'email': 'private@example.test',
  };
  int stops = 0;
  int presentationChanges = 0;
  int stateReads = 0;
  int authSubmissions = 0;
  Map<String, dynamic> authMetadata = {'supported': true, 'mode': 'login'};

  dynamic get wrapped => params.controllerFromPlatform!(controller);

  void finishLastLoad() {
    currentUrl = loads.last;
    final url = WebUri(currentUrl.toString());
    params.onLoadStart?.call(wrapped, url);
    params.onLoadStop?.call(wrapped, url);
  }

  /// Simulate the platform boundary of an original website link. Host `loads`
  /// intentionally counts only loadUrl commands, not browser-owned navigation.
  Future<void> navigateWebsite(Uri target, {bool finish = true}) async {
    final url = WebUri(target.toString());
    final decision = await params.shouldOverrideUrlLoading?.call(
      wrapped,
      NavigationAction(request: URLRequest(url: url), isForMainFrame: true),
    );
    if (decision == NavigationActionPolicy.CANCEL) return;
    params.onLoadStart?.call(wrapped, url);
    if (finish) finishWebsiteNavigation(target);
  }

  void finishWebsiteNavigation(Uri target) {
    currentUrl = target;
    final url = WebUri(target.toString());
    params.onPageCommitVisible?.call(wrapped, url);
    params.onLoadStop?.call(wrapped, url);
  }

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return _WebWidget(params, this);
  }
}

class _WebWidget extends PlatformInAppWebViewWidget {
  _WebWidget(super.params, this.host) : super.implementation();
  final _WebPlatform host;

  @override
  Widget build(BuildContext context) {
    final owner = context
        .findAncestorStateOfType<State<NativeVideoCatalogPage>>()!;
    final doc = host._documentsByOwner.putIfAbsent(owner, () {
      if (host._documentsByOwner.isEmpty) return host;
      final child = _WebPlatform()
        ..signedOutEntry = host.signedOutEntry
        ..profileHref = host.profileHref;
      host.documents.add(child);
      return child;
    });
    doc.params = params;
    return _WebDocument(host: doc);
  }

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _WebDocument extends StatefulWidget {
  const _WebDocument({required this.host});
  final _WebPlatform host;
  @override
  State<_WebDocument> createState() => _WebDocumentState();
}

class _WebDocumentState extends State<_WebDocument> {
  @override
  void initState() {
    super.initState();
    widget.host.creations++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.host.params.onWebViewCreated?.call(widget.host.wrapped);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(key: ValueKey('website-document'), color: Colors.green);
}

class _WebController extends PlatformInAppWebViewController
    implements VideoBrowserInspection, VideoBrowserVerificationWindow {
  _WebController(this.host)
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'test'),
      );
  final _WebPlatform host;

  @override
  Future<bool> openVerificationWindow(Uri url) async {
    host.verificationWindows.add(url);
    return await host.verificationWindowResult?.future ?? false;
  }

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const {},
    ContentWorld? contentWorld,
  }) async => CallAsyncJavaScriptResult(
    value: await evaluateJavascript(source: functionBody),
  );

  @override
  Future<bool> setInspectionEnabled(bool enabled) async {
    if (host.failInspection) throw StateError('unavailable');
    host.inspectionChanges.add(enabled);
    return enabled;
  }

  @override
  Future<void> stopLoading() async {
    host.stops++;
  }

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    host.loads.add(Uri.parse(urlRequest.url.toString()));
  }

  @override
  Future<WebUri?> getUrl() async {
    final pending = host.nextUrl;
    host.nextUrl = null;
    return pending ??
        (host.currentUrl == null ? null : WebUri(host.currentUrl.toString()));
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    if (source == 'performance.timeOrigin' && host.nextTimeOrigin != null) {
      final pending = host.nextTimeOrigin;
      host.nextTimeOrigin = null;
      return pending;
    }
    if (source.contains('const breezeCreatorDirectoryStart')) {
      final resolving = source.contains('let watch = ');
      if (resolving) {
        host.creatorResolutions++;
      } else {
        host.directoryReads++;
      }
      final pending = host.nextCreatorRead;
      host.nextCreatorRead = null;
      if (pending != null) return pending;
      final value = resolving ? host.resolvedCreator : host.creatorDirectory;
      return value == null
          ? {'status': 'unsupported'}
          : {'status': 'ok', 'value': value};
    }
    if (source.contains('const {root, formFor}')) {
      host.accountReads++;
      return host.accountMetadata;
    }
    if (source.contains('const breezeAccountEntry')) return host.signedOutEntry;
    if (source == videoAuthMetadataScript) return host.authMetadata;
    if (source.contains('const metadata =') &&
        source.contains('form.requestSubmit()')) {
      host.authSubmissions++;
      return 'submitted';
    }
    if (source.contains('data-breeze-video-hidden')) host.presentationChanges++;
    if (source.contains('const breezeSiteState')) {
      host.stateReads++;
      final pending = host.nextSiteState;
      host.nextSiteState = null;
      if (pending != null) return pending;
      return jsonEncode({
        'url': host.currentUrl?.toString() ?? 'about:blank',
        'nativeContent': host.siteReady && !host.challenge,
        'siteUi': (host.siteReady || host.authUiReady) && !host.challenge,
        'challengeShell': host.challenge,
      });
    }
    if (source.contains('return JSON.stringify({')) {
      if (host.hangSnapshot) return Completer<dynamic>().future;
      return jsonEncode({
        if (source.contains('documentUrl: location.href'))
          'documentUrl': host.currentUrl?.toString(),
        ...host.domSnapshot,
      });
    }
    if (source.contains('return JSON.stringify(counts)')) return '{}';
    if (source.contains('#user-modal-trigger')) return host.profileHref;
    return null;
  }
}

Map<String, dynamic> _catalog(String title) => {
  'data': {
    'sections': [],
    'videos': [
      {
        'title': title,
        'watchUrl': 'https://hanime1.me/watch?v=1',
        'coverUrl': '',
      },
    ],
  },
};

class _Plugin {
  final calls = <(String, Map<String, dynamic>)>[];
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? catalog;
  bool failDetail = false;
  Map<String, dynamic>? creator;
  Map<String, String> tagTargets = {};
  Map<String, dynamic> sourceValues = {};

  bool playable = false;

  Future<Map<String, dynamic>> call(
    String fnPath,
    Map<String, dynamic> core,
  ) async {
    calls.add((fnPath, core));
    if (fnPath == 'getSettingsBundle') {
      return {
        'data': {'values': sourceValues},
      };
    }
    if (fnPath == 'catalog') {
      if (catalog != null) return catalog!(core);
      final uri = Uri.parse(core['pageUrl'] as String);
      return _catalog(
        uri.queryParameters['sort'] == null ? 'Home card' : 'Rank card',
      );
    }
    if (fnPath == 'detail') {
      if (failDetail) throw const FormatException('Detail unavailable');
      return {
        'data': {
          'title':
              'Detail ${Uri.parse(core['watchUrl'] as String).queryParameters['v']}',
          'description': 'Summary',
          'tags': ['Sample tag'],
          'tagTargets': tagTargets,
          'episodes': [
            {'title': 'Episode 2', 'watchUrl': 'https://hanime1.me/watch?v=2'},
          ],
          'related': [],
          if (creator != null) 'creator': creator,
        },
      };
    }
    if (fnPath == 'playback' && playable) {
      return {
        'data': {
          'title': 'Playable detail',
          'sources': [
            {'url': 'https://fixture.test/video.mp4', 'quality': 'auto'},
          ],
        },
      };
    }
    throw const FormatException('No media source in this fixture');
  }
}

Future<void> _pump(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Plugin plugin, {
  double textScale = 1,
  List<NativeCatalogCategory> categories = const [],
  bool nativePersonal = false,
  bool nativeAuth = false,
  List<Uri> externalAuthenticationEntries = const [],
  VideoFilterSchema? filters,
  Brightness brightness = Brightness.light,
  bool nestedRoot = false,
  Uri? initialUrl,
}) async {
  Widget withDiscoverRoot(Widget catalog) => !nestedRoot
      ? catalog
      : Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                PageRouteBuilder<void>(
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(seconds: 2),
                  pageBuilder: (_, _, _) => catalog,
                ),
              ),
              child: const Text('Open fixture source'),
            ),
          ),
        );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: withDiscoverRoot(
        NativeVideoCatalogPage(
          source: 'hanime-test',
          title: 'Hanime1',
          homeUrl: Uri.parse('https://hanime1.me/'),
          initialUrl: initialUrl,
          catalogFnPath: 'catalog',
          detailFnPath: 'detail',
          playbackFnPath: 'playback',
          selectors: const {},
          nativeAccount: nativePersonal,
          nativeSubscriptions: nativePersonal,
          nativeAuth: nativeAuth,
          externalAuthenticationEntries: externalAuthenticationEntries,
          searchFilters: filters,
          categories: categories,
          tabs: [
            NativeCatalogTab(
              id: 'recommend',
              title: '推荐',
              url: Uri.parse('https://hanime1.me/'),
              mode: 'catalog',
            ),
            NativeCatalogTab(
              id: 'ranking',
              title: '排行',
              url: Uri.parse('https://hanime1.me/search?sort=views'),
              mode: 'catalog',
            ),
            NativeCatalogTab(
              id: 'subscriptions',
              title: '订阅',
              url: Uri.parse('https://hanime1.me/subscriptions'),
              mode: nativePersonal ? 'catalog' : 'website',
            ),
            NativeCatalogTab(
              id: 'account',
              title: '我的',
              url: Uri.parse('https://hanime1.me/login'),
              mode: 'account',
            ),
          ],
          pluginCall: plugin.call,
        ),
      ),
    ),
  );
  if (nestedRoot) {
    await tester.tap(find.text('Open fixture source'));
  }
  await _pump(tester);
}

Future<void> _chooseMode(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip(t.videoPlayback.websiteToggle));
  await _pump(tester, 3);
  final label = title == t.videoPlayback.website
      ? t.videoPlayback.backToWeb
      : t.videoPlayback.nativeCatalog;
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('video-host-menu')),
      matching: find.text(label),
    ),
  );
  await _pump(tester, 3);
}

Future<void> _openPersonalLibrary(WidgetTester tester, String suffix) async {
  final entry = find.byKey(ValueKey('video-personal.$suffix'));
  final label = switch (suffix) {
    'histories' => t.videoPersonal.histories,
    'saves' => t.videoPersonal.watchLater,
    'likes' => t.videoPersonal.likes,
    _ => t.videoPersonal.playlists,
  };
  final target = entry.evaluate().isNotEmpty
      ? entry
      : find.widgetWithText(Tab, label);
  await tester.ensureVisible(target);
  await tester.tap(target);
}

Future<void> _openNativeLogin(
  WidgetTester tester,
  _Plugin plugin,
  _WebPlatform web,
) async {
  plugin.catalog = (core) async {
    final page = Uri.parse(core['pageUrl'] as String);
    return {
      'data': {
        ..._catalog('Feed card')['data'] as Map<String, dynamic>,
        'account': {'status': 'signedOut'},
        if (page.path == '/login') 'auth': {'supported': true, 'mode': 'login'},
      },
    };
  };
  await _mount(tester, plugin, nativePersonal: true, nativeAuth: true);
  web.finishLastLoad();
  await _pump(tester);
  await tester.tap(find.text('订阅'));
  await _pump(tester);
  web.finishLastLoad();
  await _pump(tester);
  await tester.tap(find.text(t.videoCommunity.login));
  await _pump(tester);
  web.finishLastLoad();
  await _pump(tester);
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'fixture@example.test',
  );
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'synthetic-password',
  );
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await _pump(tester);
  expect(web.authSubmissions, 1);
}

Future<void> _verificationAction(WidgetTester tester, String value) async {
  final menu = tester.widget<NativeVideoMenu>(
    find.byWidgetPredicate(
      (widget) =>
          widget is NativeVideoMenu &&
          widget.tooltip == t.videoPlayback.verificationActions,
    ),
  );
  menu.onSelected(value);
  await _pump(tester, 3);
}

const _filters = VideoFilterSchema(
  options: {
    'genre': [
      VideoFilterChoice(value: '', label: 'All types'),
      VideoFilterChoice(value: '3DCG', label: '3DCG'),
    ],
    'sort': [
      VideoFilterChoice(value: '', label: 'Default'),
      VideoFilterChoice(value: 'views', label: 'Views'),
    ],
    'date': [
      VideoFilterChoice(value: '', label: 'All dates'),
      VideoFilterChoice(value: 'past', label: 'Past day'),
    ],
    'duration': [
      VideoFilterChoice(value: '', label: 'All lengths'),
      VideoFilterChoice(value: 'short', label: 'Short'),
    ],
  },
  tagGroups: {
    'Attributes': [
      VideoFilterChoice(value: 'A', label: 'Tag A'),
      VideoFilterChoice(value: 'B', label: 'Tag B'),
    ],
  },
);

void main() {
  late _WebPlatform web;
  late _Plugin plugin;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    web = _WebPlatform();
    plugin = _Plugin();
    final original = InAppWebViewPlatform.instance;
    InAppWebViewPlatform.instance = web;
    addTearDown(
      () => InAppWebViewPlatform.instance = original ?? _WebPlatform(),
    );
  });

  testWidgets(
    'official website opens declared home externally without changing the current page',
    (tester) async {
      final launcher = _OfficialWebsiteLauncher();
      final originalLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);
      await _mount(
        tester,
        plugin,
        initialUrl: Uri.parse('https://hanime1.me/search?query=public-fixture'),
      );
      web.finishLastLoad();
      await _pump(tester);
      NativeVideoMenu menu() => tester.widget<NativeVideoMenu>(
        find.byWidgetPredicate(
          (widget) =>
              widget is NativeVideoMenu &&
              widget.options.containsKey('officialWebsite'),
        ),
      );
      expect(
        menu().options['officialWebsite'],
        t.sourceShell.openOfficialWebsite,
      );
      expect(menu().optionIcons.containsKey('officialWebsite'), isTrue);
      final loads = web.loads.toList();
      final stops = web.stops;
      final selected = menu().selected;
      menu().onSelected('officialWebsite');
      await _pump(tester);
      expect(launcher.launches, [
        (
          url: 'https://hanime1.me/',
          mode: PreferredLaunchMode.externalApplication,
        ),
      ]);
      expect(web.loads, loads);
      expect(web.stops, stops);
      expect(menu().selected, selected);
      expect(menu().options.keys, isNot(contains('diagnostics')));
      expect(menu().options.keys, isNot(contains('inspection')));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'official indexed-tag website URL restores native conditions and canonical paging',
    (tester) async {
      plugin.sourceValues['video.defaultMode'] = 'website';
      final official = Uri.https('hanime1.me', '/search', {
        'genre': '泡麵番',
        'sort': '最新上市',
        'tags[0]': '1080p',
        'page': '2',
      });
      plugin.catalog = (core) async {
        final current = Uri.parse(core['pageUrl'] as String);
        final page = int.tryParse(current.queryParameters['page'] ?? '') ?? 1;
        return {
          'data': {
            ..._catalog('Filtered page $page')['data'] as Map<String, dynamic>,
            'paging': {
              'page': page,
              'totalPages': 3,
              'nextUrl': page == 2
                  ? official
                        .replace(
                          queryParameters: {
                            ...official.queryParameters,
                            'page': '3',
                          },
                        )
                        .toString()
                  : '',
              'previousUrl': '',
            },
          },
        };
      };
      await _mount(tester, plugin, filters: _filters);
      web.finishLastLoad();
      await _pump(tester);
      await web.navigateWebsite(official);
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester);
      expect(find.text('Filtered page 2'), findsOneWidget);
      var active = tester
          .widget<VideoActiveFilters>(find.byType(VideoActiveFilters))
          .filters;
      expect(active.tags, ['1080p']);
      expect(active.genre, '泡麵番');
      expect(active.sort, '最新上市');
      expect(active.page, 2);
      await tester.ensureVisible(find.text(t.common.nextPage));
      await tester.tap(find.text(t.common.nextPage));
      await _pump(tester);
      expect(web.loads.last.queryParametersAll, {
        'genre': ['泡麵番'],
        'sort': ['最新上市'],
        'tags[]': ['1080p'],
        'page': ['3'],
      });
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Filtered page 3'), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(find.text('Filtered page 2'), findsOneWidget);
      active = tester
          .widget<VideoActiveFilters>(find.byType(VideoActiveFilters))
          .filters;
      expect(active.tags, ['1080p']);
      expect(active.page, 2);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'full filters, omitted paging parameters and cached return preserve one request identity',
    (tester) async {
      plugin.catalog = (core) async {
        final uri = Uri.parse(core['pageUrl'] as String),
            page =
                int.tryParse(
                  Uri.parse(
                        core['pageUrl'] as String,
                      ).queryParameters['page'] ??
                      '',
                ) ??
                1;
        return {
          'data': {
            ..._catalog('Page $page')['data'] as Map<String, dynamic>,
            if (uri.path == '/search')
              'paging': {
                'page': page,
                'totalPages': 2,
                'previousUrl': page == 2 ? 'https://hanime1.me/search' : '',
                'nextUrl': page == 1 ? 'https://hanime1.me/search?page=2' : '',
              },
          },
        };
      };
      await _mount(tester, plugin, filters: _filters);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('排行'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('video-filter-open.tags')));
      await _pump(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Tag A'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Tag B'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ChoiceChip, t.videoFilters.anyMatch),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, t.videoFilters.genre));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '3DCG'));
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, t.videoFilters.date));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Past day'));
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, t.videoFilters.duration));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Short'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('video-filter.apply')));
      await _pump(tester);
      final first = web.loads.last;
      expect(first.queryParametersAll['tags[]'], ['A', 'B']);
      expect(first.queryParameters['sort'], 'views');
      expect(first.queryParameters['genre'], '3DCG');
      expect(first.queryParameters['date'], 'past');
      expect(first.queryParameters['duration'], 'short');
      expect(first.queryParameters['broad'], 'on');
      web.finishLastLoad();
      await _pump(tester);
      await tester.ensureVisible(find.text(t.common.nextPage));
      await tester.tap(find.text(t.common.nextPage));
      await _pump(tester);
      final next = web.loads.last;
      expect(next.queryParametersAll, {
        ...first.queryParametersAll,
        'page': ['2'],
      });
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(web.loads.length, loads);
      expect(find.text('Page 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('video-filter-open.tags')));
      await _pump(tester);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Tag A'))
            .selected,
        true,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Tag B'))
            .selected,
        true,
      );
      await tester.tap(find.byTooltip(t.common.cancel));
      await _pump(tester);
      expect(web.loads.length, loads);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a detail tag uses its actual filter target and retains the source sort',
    (tester) async {
      plugin.tagTargets = {
        'Sample tag': 'https://hanime1.me/search?tags%5B%5D=Wire%20tag',
      };
      await _mount(tester, plugin, filters: _filters);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('排行'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Rank card'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      await tester.tap(find.widgetWithText(ActionChip, 'Sample tag'));
      await _pump(tester);
      expect(web.documents.last.loads.last.queryParametersAll['tags[]'], [
        'Wire tag',
      ]);
      expect(web.documents.last.loads.last.queryParameters['sort'], 'views');
      expect(web.documents.last.loads.last.queryParameters['query'], isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a committed challenge is visible before load-stop', (
    tester,
  ) async {
    web.challenge = true;
    await _mount(tester, plugin);
    web.currentUrl = web.loads.last;
    final url = WebUri(web.currentUrl.toString());
    web.params.onLoadStart?.call(web.wrapped, url);
    web.params.onReceivedHttpError?.call(
      web.wrapped,
      WebResourceRequest(url: url, isForMainFrame: true),
      WebResourceResponse(
        statusCode: 403,
        headers: {'cf-mitigated': 'challenge'},
      ),
    );
    web.params.onPageCommitVisible?.call(web.wrapped, url);
    await _pump(tester);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(web.loads, hasLength(1));
    expect(find.byKey(const ValueKey('website-document')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ready cards appear before subframes finish loading', (
    tester,
  ) async {
    await _mount(tester, plugin);
    expect(find.text('Home card'), findsNothing);
    web.currentUrl = web.loads.last;
    web.params.onPageCommitVisible?.call(
      web.wrapped,
      WebUri(web.currentUrl.toString()),
    );
    await _pump(tester, 3);
    expect(find.text('Home card'), findsOneWidget);
    expect(plugin.calls.where((c) => c.$1 == 'catalog'), hasLength(1));
    // A late load-stop must not parse/render the same catalog again.
    web.params.onLoadStop?.call(web.wrapped, WebUri(web.currentUrl.toString()));
    await _pump(tester, 3);
    expect(plugin.calls.where((c) => c.$1 == 'catalog'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fresh tab revisits do not request or parse the page again', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('排行'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('推荐'));
      await tester.pump();
      expect(find.text('Home card'), findsOneWidget);
      await tester.tap(find.text('排行'));
      await tester.pump();
      expect(find.text('Rank card'), findsOneWidget);
    }
    expect(web.loads, hasLength(2));
    expect(plugin.calls.where((c) => c.$1 == 'catalog'), hasLength(2));
    expect(web.creations, 1);
    expect(
      find.byKey(const ValueKey('catalog-background-refresh')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'catalog builds only visible posters, not the entire result page',
    (tester) async {
      plugin.catalog = (_) async => {
        'data': {
          'videos': List.generate(
            160,
            (i) => {
              'title': 'Card $i',
              'coverUrl': '',
              'watchUrl': 'https://hanime1.me/watch?v=${i + 1}',
            },
          ),
        },
      };
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      final built = find
          .byType(VideoThumbnail, skipOffstage: false)
          .evaluate()
          .length;
      debugPrint('Catalog performance fixture: $built / 160 posters built');
      expect(built, greaterThan(0));
      expect(
        built,
        lessThan(24),
        reason: 'offscreen posters must not start loading',
      );
      expect(find.text('Card 159'), findsNothing);
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -600),
      );
      await _pump(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tab revisit shows cached cards immediately and survives refresh failure',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('排行'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Rank card'), findsOneWidget);
      await tester.tap(find.text('推荐'));
      await tester.pump();
      expect(find.text('Home card'), findsOneWidget);
      // A fresh tab revisit is local. An explicit re-tap requests refresh.
      await tester.tap(find.text('推荐'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('catalog-background-refresh')),
        findsOneWidget,
      );
      web.params.onReceivedError?.call(
        web.wrapped,
        WebResourceRequest(
          url: WebUri('https://hanime1.me/'),
          isForMainFrame: true,
        ),
        WebResourceError(
          type: WebResourceErrorType.TIMEOUT,
          description: 'timeout',
        ),
      );
      await _pump(tester, 3);
      expect(find.text('Home card'), findsOneWidget);
      expect(find.text(t.videoPlayback.catalogRefreshFailed), findsOneWidget);
      expect(find.text(t.videoPlayback.catalogFallback), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('website mode invalidates earlier catalog account snapshots', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('排行'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester);
    await _chooseMode(tester, t.videoPlayback.website);
    await _chooseMode(tester, t.videoPlayback.nativeCatalog);
    await tester.tap(find.text('推荐'));
    await _pump(tester);
    expect(
      find.text('Home card'),
      findsNothing,
      reason:
          'a website can change the account; do not reuse old account snapshots',
    );
    web.finishLastLoad();
    await _pump(tester);
    expect(find.text('Home card'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('refresh of the same URL waits for the new document commit', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    expect(plugin.calls.where((c) => c.$1 == 'catalog'), hasLength(1));
    await tester.tap(find.text('推荐'));
    await _pump(tester, 20);
    expect(find.text('Home card'), findsOneWidget);
    expect(
      plugin.calls.where((c) => c.$1 == 'catalog'),
      hasLength(1),
      reason: 'the previous same-URL DOM is not a new successful refresh',
    );
    web.params.onPageCommitVisible?.call(
      web.wrapped,
      WebUri(web.currentUrl.toString()),
    );
    await _pump(tester, 3);
    expect(plugin.calls.where((c) => c.$1 == 'catalog'), hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a challenge during cached refresh takes precedence over cards', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('排行'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('推荐'));
    await tester.pump();
    expect(find.text('Home card'), findsOneWidget);
    await tester.tap(find.text('推荐'));
    await tester.pump();
    web.challenge = true;
    web.currentUrl = web.loads.last;
    final url = WebUri(web.currentUrl.toString());
    web.params.onReceivedHttpError?.call(
      web.wrapped,
      WebResourceRequest(url: url, isForMainFrame: true),
      WebResourceResponse(
        statusCode: 403,
        headers: {'cf-mitigated': 'challenge'},
      ),
    );
    web.params.onPageCommitVisible?.call(web.wrapped, url);
    await _pump(tester, 3);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(find.text('Home card'), findsNothing);
    expect(web.loads, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('verification cannot be restarted by switching main tabs', (
    tester,
  ) async {
    web.challenge = true;
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    final stops = web.stops;
    expect(find.byType(BottomNavigationBar), findsNothing);
    for (final title in ['排行', '订阅', '我的', '推荐']) {
      expect(find.text(title), findsNothing);
    }
    expect(web.loads, hasLength(1));
    expect(web.stops, stops);
    expect(web.creations, 1);
    expect(web.presentationChanges, 0);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(plugin.calls.where((call) => call.$1 == 'catalog'), isEmpty);

    // The website's own refresh/completion is not another app load. Wait well
    // past the host's 60-second observation deadline, then deliver real content.
    await _pump(tester, 650);
    web.challenge = false;
    web.params.onLoadStart?.call(
      web.wrapped,
      WebUri(web.currentUrl.toString()),
    );
    web.params.onLoadStop?.call(web.wrapped, WebUri(web.currentUrl.toString()));
    await _pump(tester);
    expect(find.text('Home card'), findsOneWidget);
    expect(web.loads, hasLength(1));
    expect(web.stops, stops);
    expect(web.creations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'late verification completion without navigation resumes after the soft deadline',
    (tester) async {
      web.challenge = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester, 650);
      final stops = web.stops;
      web.challenge =
          false; // Content changes without another load-stop callback.
      await _pump(tester, 60);
      expect(find.text('Home card'), findsOneWidget);
      expect(web.loads, hasLength(1));
      expect(web.stops, stops);
      expect(web.presentationChanges, 0);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'background verification pauses observation and checks again on resume',
    (tester) async {
      web.challenge = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester, 650);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _pump(tester);
      final reads = web.stateReads;
      web.challenge = false;
      await _pump(tester, 100);
      expect(web.stateReads, reads);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      expect(web.loads, hasLength(1));
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'challenge response is status-independent and remains live after observation timeout',
    (tester) async {
      await _mount(tester, plugin);
      web.currentUrl = web.loads.last;
      web.siteReady = false; // New/unrecognized challenge HTML template.
      final url = WebUri(web.currentUrl.toString());
      web.params.onLoadStart?.call(web.wrapped, url);
      final browser = tester.widget<VideoSiteBrowser>(
        find.byType(VideoSiteBrowser),
      );
      browser.onDocumentResponse!(web.currentUrl!, 200, {
        'CF-Mitigated': 'challenge',
      });
      web.params.onPageCommitVisible?.call(web.wrapped, url);
      await _pump(tester);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      final stops = web.stops;
      final viewport = tester.getSize(
        find.byKey(const ValueKey('website-document')),
      );
      await _pump(tester, 650);
      expect(web.loads, hasLength(1));
      expect(web.stops, stops);
      expect(web.presentationChanges, 0);
      expect(
        tester.getSize(find.byKey(const ValueKey('website-document'))),
        viewport,
      );

      web.siteReady = true;
      web.params.onLoadStart?.call(web.wrapped, url);
      browser.onDocumentResponse!(web.currentUrl!, 200, const {});
      web.params.onPageCommitVisible?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      expect(web.loads, hasLength(1));
      expect(web.stops, stops);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('internal back cannot interrupt a category challenge', (
    tester,
  ) async {
    await _mount(
      tester,
      plugin,
      categories: [
        NativeCatalogCategory(
          title: 'Test genre',
          url: Uri.parse('https://hanime1.me/search?genre=Test'),
        ),
      ],
    );
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('Test genre'));
    await _pump(tester);
    web.challenge = true;
    web.finishLastLoad();
    await _pump(tester);
    final stops = web.stops;
    final scope = tester.widget<PopScope<Object?>>(
      find.byWidgetPredicate((widget) => widget is PopScope<Object?>).first,
    );
    scope.onPopInvokedWithResult!(false, null);
    await _pump(tester);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(find.byTooltip(t.videoPlayback.closeSource), findsOneWidget);
    expect(web.stops, stops);
    expect(web.loads, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'diagnostic commands are opt-in and revocation closes inspection',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      NativeVideoMenu menu() => tester.widget<NativeVideoMenu>(
        find.byWidgetPredicate(
          (widget) =>
              widget is NativeVideoMenu &&
              widget.tooltip == t.videoPlayback.websiteToggle,
        ),
      );
      final initialLoads = web.loads.length;
      expect(menu().options.keys, isNot(contains('diagnostics')));
      expect(menu().options.keys, isNot(contains('inspection')));
      // Even a stale native callback must not expose a disabled tool.
      menu().onSelected('inspection');
      menu().onSelected('diagnostics');
      await _pump(tester);
      expect(find.text(t.videoPlayback.browserInspectionPrompt), findsNothing);
      expect(web.inspectionChanges, isEmpty);
      await SourceDiagnosticPreferences.setEnabled('hanime-test', true);
      await _pump(tester);
      expect(menu().options.keys, containsAll(['diagnostics', 'inspection']));
      menu().onSelected('inspection');
      await _pump(tester);
      await tester.tap(
        find.widgetWithText(
          TextButton,
          t.videoPlayback.enableBrowserInspection,
        ),
      );
      await _pump(tester);
      expect(web.inspectionChanges, [true]);
      await SourceDiagnosticPreferences.setEnabled('hanime-test', false);
      await _pump(tester);
      expect(web.inspectionChanges, [true, false]);
      expect(menu().options.keys, isNot(contains('diagnostics')));
      expect(menu().options.keys, isNot(contains('inspection')));
      expect(menu().options.keys, containsAll(['tools', 'exit']));
      expect(web.loads.length, initialLoads);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('inspection remains accessible after verification has passed', (
    tester,
  ) async {
    await SourceDiagnosticPreferences.setEnabled('hanime-test', true);
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    var menu = tester.widget<NativeVideoMenu>(
      find.byWidgetPredicate(
        (widget) =>
            widget is NativeVideoMenu &&
            widget.tooltip == t.videoPlayback.websiteToggle,
      ),
    );
    expect(menu.options.keys, containsAll(['diagnostics', 'inspection']));
    expect(menu.options['diagnostics'], t.videoPlayback.pageAnalysis);
    expect(menu.options['tools'], t.videoCommunity.preferences);
    expect(menu.options.keys.every(menu.optionIcons.containsKey), isTrue);
    menu.onSelected('inspection');
    await _pump(tester);
    await tester.tap(
      find.widgetWithText(TextButton, t.videoPlayback.enableBrowserInspection),
    );
    await _pump(tester);
    menu = tester.widget<NativeVideoMenu>(
      find.byWidgetPredicate(
        (widget) =>
            widget is NativeVideoMenu &&
            widget.tooltip == t.videoPlayback.websiteToggle,
      ),
    );
    expect(
      menu.options['inspection'],
      t.videoPlayback.disableBrowserInspection,
    );
    menu.onSelected('inspection');
    await _pump(tester);
    expect(web.inspectionChanges, [true, false]);
    expect(web.loads, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'back from a category restores its parent ranking without reloading',
    (tester) async {
      await _mount(
        tester,
        plugin,
        categories: [
          NativeCatalogCategory(
            title: 'Test genre',
            url: Uri.parse('https://hanime1.me/search?genre=Test'),
          ),
        ],
      );
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('排行'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Test genre'));
      await _pump(tester);
      expect(web.loads.last.queryParameters['genre'], 'Test');
      expect(web.loads.last.queryParameters['sort'], 'views');
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(web.loads, hasLength(loads));
      expect(find.text('Rank card'), findsOneWidget);
      expect(find.byType(NativeVideoCatalogPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'browser inspection needs consent and never reloads verification',
    (tester) async {
      await SourceDiagnosticPreferences.setEnabled('hanime-test', true);
      web.challenge = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      await _verificationAction(tester, 'inspection');
      expect(
        find.text(t.videoPlayback.browserInspectionPrompt),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await _pump(tester);
      expect(web.inspectionChanges, isEmpty);
      await _verificationAction(tester, 'inspection');
      await tester.tap(
        find.widgetWithText(
          TextButton,
          t.videoPlayback.enableBrowserInspection,
        ),
      );
      await _pump(tester);
      expect(web.inspectionChanges, [true]);
      await _verificationAction(tester, 'inspection');
      expect(web.inspectionChanges, [true, false]);
      expect(web.loads, hasLength(loads));
      expect(web.creations, 1);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('inspection errors leave the website and toggle unchanged', (
    tester,
  ) async {
    await SourceDiagnosticPreferences.setEnabled('hanime-test', true);
    web.challenge = true;
    web.failInspection = true;
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    final loads = web.loads.length;
    await _verificationAction(tester, 'inspection');
    await tester.tap(
      find.widgetWithText(TextButton, t.videoPlayback.enableBrowserInspection),
    );
    await _pump(tester);
    expect(find.text(t.videoPlayback.browserInspectionFailed), findsOneWidget);
    expect(web.inspectionChanges, isEmpty);
    await _verificationAction(tester, 'inspection');
    expect(find.text(t.videoPlayback.browserInspectionPrompt), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
    await _pump(tester);
    expect(web.loads, hasLength(loads));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'explicit website mode persists through navigation and back until native is chosen',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      await _chooseMode(tester, t.videoPlayback.website);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byType(BottomNavigationBar), findsNothing);
      await web.navigateWebsite(
        Uri.parse('https://hanime1.me/search?sort=views'),
      );
      await _pump(tester);
      expect(find.byType(BottomNavigationBar), findsNothing);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(web.loads.last.path, '/');
      expect(find.byType(BottomNavigationBar), findsNothing);
      await web.navigateWebsite(
        Uri.parse('https://hanime1.me/search?sort=views'),
      );
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1,
      );
      expect(find.text('Rank card'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a challenge appearing after success is detected without a reload',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      final viewport = tester.getSize(
        find.byKey(const ValueKey('website-document')),
      );
      web.challenge =
          true; // DOM changes after load-stop, with no new callback.
      await _pump(tester, 60);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      expect(web.loads, hasLength(loads));
      final verificationViewport = tester.getSize(
        find.byKey(const ValueKey('website-document')),
      );
      expect(verificationViewport.width, viewport.width);
      expect(verificationViewport.height, greaterThan(viewport.height));
      expect(find.byType(BottomNavigationBar), findsNothing);
      await _verificationAction(tester, 'website');
      await _verificationAction(tester, 'native');
      expect(web.loads, hasLength(loads));
      expect(find.text('推荐'), findsNothing);
      expect(web.loads, hasLength(loads));
      web.challenge = false;
      await _pump(tester, 30);
      expect(find.text('Home card'), findsOneWidget);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'late native mode lookup cannot override a newer website choice',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.website);
      final pending = Completer<WebUri?>();
      web.nextUrl = pending.future;
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _chooseMode(tester, t.videoPlayback.website);
      pending.complete(WebUri('https://hanime1.me/'));
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'website',
        ),
        findsOneWidget,
      );
      expect(find.text('Home card'), findsNothing);
      expect(web.loads, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'switching a website watch page to native opens that same detail',
    (tester) async {
      plugin.sourceValues['video.defaultMode'] = 'website';
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.website);
      web.currentUrl = Uri.parse('https://hanime1.me/watch?v=77');
      web.params.onLoadStart?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester, 20);
      expect(find.text('Detail 77'), findsOneWidget);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(web.loads, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'website search leaves the old My tab when explicitly returning to native',
    (tester) async {
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.website);
      await web.navigateWebsite(
        Uri.parse('https://hanime1.me/search?query=test'),
      );
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      expect(find.byType(VideoSearchEntry), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final callback in ['policy', 'commit', 'stop', 'history']) {
    testWidgets('explicit website choice survives $callback site navigation', (
      tester,
    ) async {
      await _mount(tester, plugin, nativePersonal: true, nativeAuth: true);
      web.finishLastLoad();
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.website);
      final nativeReads = plugin.calls
          .where((v) => ['catalog', 'detail', 'playback'].contains(v.$1))
          .length;
      for (final path in [
        '/search?query=test',
        '/subscriptions',
        '/user/42',
        '/user/42/edit',
        '/watch?v=77',
        '/login',
      ]) {
        final target = Uri.parse('https://hanime1.me$path');
        final url = WebUri(target.toString());
        switch (callback) {
          case 'policy':
            await web.navigateWebsite(target);
          case 'commit':
            web.currentUrl = target;
            web.params.onPageCommitVisible?.call(web.wrapped, url);
            web.params.onLoadStop?.call(web.wrapped, url);
          case 'stop':
            web.currentUrl = target;
            web.params.onLoadStop?.call(web.wrapped, url);
          case 'history':
            web.currentUrl = target;
            web.params.onUpdateVisitedHistory?.call(web.wrapped, url, false);
            web.params.onLoadStop?.call(web.wrapped, url);
        }
        await _pump(tester, 8);
        expect(
          find.byWidgetPredicate(
            (w) => w is NativeVideoMenu && w.selected == 'website',
          ),
          findsOneWidget,
          reason: path,
        );
        expect(find.byType(BottomNavigationBar), findsNothing, reason: path);
        expect(find.byType(NativeVideoPage), findsNothing, reason: path);
        expect(find.byType(NativeVideoAuthForm), findsNothing, reason: path);
        expect(find.byType(NativeVideoAccountForm), findsNothing, reason: path);
      }
      expect(
        plugin.calls
            .where((v) => ['catalog', 'detail', 'playback'].contains(v.$1))
            .length,
        nativeReads,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'explicit detail website continuation keeps later navigation on website',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      await tester.ensureVisible(
        find.widgetWithText(TextButton, t.videoPlayback.backToWeb),
      );
      await tester.tap(
        find.widgetWithText(TextButton, t.videoPlayback.backToWeb),
      );
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'website',
        ),
        findsOneWidget,
      );
      expect(find.byType(BottomNavigationBar), findsNothing);
      await web.navigateWebsite(
        Uri.parse('https://hanime1.me/search?sort=views'),
      );
      await _pump(tester);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NativeVideoPage), findsNothing);
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1,
      );
      expect(find.text('Rank card'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final completion in ['commit', 'stop']) {
    testWidgets(
      'a $completion-only watch URL after an old start still opens native',
      (tester) async {
        await _mount(tester, plugin);
        web.finishLastLoad();
        await _pump(tester);
        await tester.tap(find.text('订阅'));
        await _pump(tester);
        web.finishLastLoad();
        await _pump(tester);
        // WKWebView.url can still be the previous page at provisional start.
        web.params.onLoadStart?.call(
          web.wrapped,
          WebUri(web.currentUrl.toString()),
        );
        web.currentUrl = Uri.parse('https://hanime1.me/watch?v=99');
        final url = WebUri(web.currentUrl.toString());
        if (completion == 'commit') {
          web.params.onPageCommitVisible?.call(web.wrapped, url);
        } else {
          web.params.onLoadStop?.call(web.wrapped, url);
        }
        await _pump(tester, 20);
        expect(find.text('Detail 99'), findsOneWidget);
        expect(find.byType(NativeVideoPage), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final tab in ['订阅', '我的']) {
    for (final explicitWebsite in [false, true]) {
      testWidgets(
        '$tab video uses native preference=$explicitWebsite and returns to its parent',
        (tester) async {
          if (explicitWebsite) {
            plugin.sourceValues['video.defaultMode'] = 'website';
          }
          await _mount(tester, plugin);
          web.finishLastLoad();
          await _pump(tester);
          web.profileHref = '/user/42';
          if (explicitWebsite) {
            await web.navigateWebsite(
              Uri.parse(
                tab == '订阅'
                    ? 'https://hanime1.me/subscriptions'
                    : 'https://hanime1.me/user/42',
              ),
            );
          } else {
            await tester.tap(find.text(tab));
            await _pump(tester);
            web.finishLastLoad();
          }
          await _pump(tester);
          final parent = web.currentUrl;
          final loads = web.loads.length;
          web.currentUrl = Uri.parse('https://hanime1.me/watch?v=77');
          final url = WebUri(web.currentUrl.toString());
          web.params.onLoadStart?.call(web.wrapped, url);
          web.params.onPageCommitVisible?.call(web.wrapped, url);
          web.params.onLoadStop?.call(web.wrapped, url);
          await _pump(tester, 20);
          if (explicitWebsite) {
            expect(find.byType(NativeVideoPage), findsNothing);
            await _chooseMode(tester, t.videoPlayback.nativeCatalog);
            await _pump(tester, 20);
          }
          expect(find.text('Detail 77'), findsOneWidget);
          expect(find.byType(NativeVideoPage), findsOneWidget);
          expect(
            web.loads,
            hasLength(loads),
            reason: 'use the already loaded watch document',
          );
          if (find.byType(NativeVideoPage).evaluate().isNotEmpty) {
            await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
          } else {
            await tester.pageBack();
          }
          await _pump(tester);
          expect(
            web.loads.last.path,
            parent?.path,
            reason: 'return to the actual subscription/profile parent',
          );
          expect(web.loads.last.queryParametersAll, parent?.queryParametersAll);
          web.finishLastLoad();
          await _pump(tester);
          expect(find.byType(NativeVideoPage), findsNothing);
          expect(
            find.byTooltip(t.videoPlayback.browserActions),
            findsOneWidget,
          );
          expect(find.byType(BottomNavigationBar), findsNothing);
          await web.navigateWebsite(Uri.parse('https://hanime1.me/'));
          await _pump(tester);
          expect(find.text('Home card'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (w) => w is NativeVideoMenu && w.selected == 'native',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'history-only site navigation also opens the current native video',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      web.currentUrl = Uri.parse('https://hanime1.me/watch?v=88');
      web.params.onUpdateVisitedHistory?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
        false,
      );
      await _pump(tester, 20);
      expect(find.text('Detail 88'), findsOneWidget);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tag and creator catalog navigation returns through the video to its original parent',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      await tester.tap(find.widgetWithText(ActionChip, 'Sample tag'));
      await _pump(tester);
      web.documents.single.finishLastLoad();
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(web.loads.last.queryParameters['v'], '1');
      await _pump(tester, 20);
      expect(find.text('Detail 1'), findsOneWidget);
      if (find.byType(NativeVideoPage).evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
      } else {
        await tester.pageBack();
      }
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      expect(find.byTooltip(t.videoPlayback.closeSource), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'catalog menu owns its barrier across ten reopen cycles, rapid reopen and back',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <String, MethodChannel>{};
      final calls = <MethodCall>[];
      final created = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          final channel = MethodChannel('breeze.video.control.$id');
          created.add(channel);
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'update') {
              channels[(call.arguments as Map)['tooltip'] as String] = channel;
            }
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in created) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final menu = find.byKey(const ValueKey('video-host-menu'));
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      final outside = tester.getCenter(find.byType(BottomNavigationBar));
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byTooltip(t.videoPlayback.websiteToggle));
        await tester.pump();
        await _pump(tester);
        expect(menu, findsOneWidget);
        await tester.tapAt(outside);
        await _pump(tester);
        expect(menu, findsNothing);
        expect(
          web.loads.length,
          loads,
          reason: 'outside dismissal must not select an underlying tab',
        );
      }
      await tester.tap(find.byTooltip(t.videoPlayback.websiteToggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      await tester.tapAt(outside);
      await tester.pump();
      // Reopen while the old route is still reversing.
      await tester.tap(find.byTooltip(t.videoPlayback.websiteToggle));
      await tester.pump();
      await _pump(tester);
      expect(menu, findsOneWidget);
      tester.binding.handleMetricsChanged();
      await _pump(tester);
      expect(
        menu,
        findsOneWidget,
        reason: 'a repeated identical metrics event is not a rotation',
      );
      await tester.binding.handlePopRoute();
      await _pump(tester);
      expect(menu, findsNothing);
      expect(find.byType(NativeVideoCatalogPage), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.websiteToggle));
      await tester.pump();
      await _pump(tester);
      tester.view.physicalSize = const Size(760, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      await _pump(tester);
      expect(menu, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'detail author opens its observed profile and returns through the same video',
    (tester) async {
      plugin.creator = {
        'name': 'Display creator',
        'role': 'artist',
        'artistId': '7',
        'profileUrl': 'https://hanime1.me/user/88',
        'nameSearchUrl': 'https://hanime1.me/search?query=canonical-key',
      };
      plugin.catalog = (core) async {
        final uri = Uri.parse(core['pageUrl'] as String);
        return _catalog(uri.path == '/user/88' ? 'Creator work' : 'Home card');
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      final watchLoads = web.loads.length;
      await tester.tap(find.text('Display creator'));
      await _pump(tester);
      final authorWeb = web.documents.single;
      expect(authorWeb.loads.last.path, '/user/88');
      expect(
        web.loads.length,
        watchLoads,
        reason: 'the retained video document must not navigate',
      );
      expect(find.widgetWithText(AppBar, 'Display creator'), findsOneWidget);
      authorWeb.finishLastLoad();
      await _pump(tester);
      expect(find.text('Creator work'), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
      await _pump(tester, 20);
      expect(find.text('Detail 1'), findsOneWidget);
      expect(
        web.loads.length,
        watchLoads,
        reason: 'author pop must not fetch or repush the video',
      );
      await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final seconds in [42, 118]) {
    for (final playing in [false, true]) {
      testWidgets(
        'author return preserves playing=$playing at $seconds without history',
        (tester) async {
          final original = VideoPlayerPlatform.instance;
          final media = _ReturnVideoPlatform();
          VideoPlayerPlatform.instance = media;
          addTearDown(() => VideoPlayerPlatform.instance = original);
          SharedPreferences.setMockInitialValues({
            'breeze.video.defaults.recordHistory': false,
            'breeze.video.defaults.resumeProgress': false,
            'breeze.video.defaults.controlsStyle': 'breeze',
          });
          plugin.playable = true;
          plugin.creator = {
            'name': 'Display creator',
            'role': 'artist',
            'artistId': '7',
            'profileUrl': 'https://hanime1.me/user/88',
          };
          plugin.catalog = (core) async => _catalog(
            Uri.parse(core['pageUrl'] as String).path == '/user/88'
                ? 'Creator work'
                : 'Home card',
          );
          await _mount(tester, plugin, nativePersonal: true);
          web.finishLastLoad();
          await _pump(tester);
          await tester.tap(find.text('Home card'));
          await _pump(tester);
          web.finishLastLoad();
          await _pump(tester, 20);
          media.position = Duration(seconds: seconds);
          await _pump(tester, 6);
          if (!playing) {
            await tester.tap(find.byTooltip(t.videoPlayback.pause));
            await _pump(tester, 2);
          }
          final watchLoads = web.loads.length;
          await tester.tap(find.text('Display creator'));
          await _pump(tester);
          final authorWeb = web.documents.single;
          expect(authorWeb.loads.last.path, '/user/88');
          authorWeb.finishLastLoad();
          await _pump(tester);
          if (Theme.of(
                tester.element(find.byType(NativeVideoCatalogPage).last),
              ).platform ==
              TargetPlatform.iOS) {
            final width =
                tester.view.physicalSize.width / tester.view.devicePixelRatio;
            final route =
                ModalRoute.of(
                      tester.element(
                        find.widgetWithText(AppBar, 'Display creator'),
                      ),
                    )!
                    as PageRoute;
            expect(route.popGestureEnabled, isTrue);
            final back = await tester.startGesture(const Offset(1, 250));
            await back.moveBy(const Offset(24, 0));
            await tester.pump(const Duration(milliseconds: 16));
            await back.moveBy(Offset(width * .65, 0));
            await tester.pump(const Duration(milliseconds: 60));
            await back.up();
          } else {
            await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
          }
          await _pump(tester, 20);
          expect(web.loads.length, watchLoads);
          expect(
            media._id,
            1,
            reason:
                'return reuses the original media instead of replaying route arrival',
          );
          expect(
            find.byTooltip(
              playing ? t.videoPlayback.pause : t.videoPlayback.play,
            ),
            findsOneWidget,
          );
          expect(media.position, Duration(seconds: seconds));
          expect(media.playCount, playing ? 2 : 1);
          await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
          await _pump(tester);
          expect(find.text('Home card'), findsOneWidget);
          await tester.tap(find.text('Home card'));
          await _pump(tester);
          web.finishLastLoad();
          await _pump(tester, 20);
          expect(find.byTooltip(t.videoPlayback.pause), findsOneWidget);
          expect(media.position, Duration.zero);
          expect(media.playCount, playing ? 3 : 2);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }

  testWidgets(
    'an author redirect to home cannot become a successful author catalog',
    (tester) async {
      plugin.creator = {
        'name': 'Display creator',
        'role': 'artist',
        'artistId': '7',
        'profileUrl': 'https://hanime1.me/user/88',
        'nameSearchUrl': 'https://hanime1.me/search?query=canonical-key',
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      await tester.tap(find.text('Display creator'));
      await _pump(tester);
      final calls = plugin.calls.where((call) => call.$1 == 'catalog').length;
      final authorWeb = web.documents.single;
      authorWeb.currentUrl = Uri.parse('https://hanime1.me/');
      authorWeb.params.onLoadStop?.call(
        authorWeb.wrapped,
        WebUri(authorWeb.currentUrl.toString()),
      );
      await tester.pump(const Duration(seconds: 31));
      await _pump(tester);
      expect(plugin.calls.where((call) => call.$1 == 'catalog').length, calls);
      expect(find.text('Home card'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Display creator'), findsOneWidget);
      expect(find.text(t.videoPlayback.catalogFallback), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a name-only creator never invents a profile or artist lookup', (
    tester,
  ) async {
    plugin.creator = {'name': 'Display creator', 'url': ''};
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('Home card'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester, 20);
    final count = web.loads.length;
    await tester.tap(find.text('Display creator'));
    await _pump(tester);
    expect(web.loads.length, count);
    expect(find.byType(NativeVideoPage), findsOneWidget);
    expect(find.text(t.videoCommunity.creatorUnavailable), findsOneWidget);
    expect(
      plugin.calls.where(
        (call) =>
            Uri.parse(
              (call.$2['pageUrl'] ?? 'https://hanime1.me/').toString(),
            ).queryParameters['type'] ==
            'artist',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'subscription works and avatar resolve to the same real author with one directory read',
    (tester) async {
      final author = {
        'role': 'artist',
        'entityKey': 'artist:7',
        'artistId': '7',
        'name': 'Directory author',
        'nameSearchUrl':
            'https://hanime1.me/search?query=actual-alias&genre=3DCG',
      };
      web.domSnapshot = {
        'account': {'profileUrl': '/user/42'},
      };
      web.creatorDirectory = {
        'ownerUrl': 'https://hanime1.me/user/42',
        'creators': [author],
        'nextUrl': null,
      };
      web.resolvedCreator = {
        ...author,
        'ownerUrl': 'https://hanime1.me/user/42',
        'profileUrl': 'https://hanime1.me/user/88',
        'profileId': '88',
      };
      plugin.catalog = (core) async {
        final snapshot = core['snapshot'] as Map;
        final directory =
            (snapshot['creatorDirectory'] as Map?)?['creators'] as List? ?? [];
        return {
          'data': {
            'sections': [],
            'videos': [],
            'account': {
              'status': 'signedIn',
              'isOwnProfile': false,
              'profileUrl': 'https://hanime1.me/user/42',
            },
            'creatorGroups': [
              for (final ref in directory) {'creator': ref, 'videos': []},
            ],
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(web.directoryReads, 1);
      expect(web.creatorResolutions, 0);
      expect(find.text('Directory author'), findsOneWidget);
      await tester.tap(find.text(t.videoCommunity.viewCreatorWorks));
      await _pump(tester);
      expect(web.documents.last.loads.last.path, '/user/88');
      expect(web.documents.last.loads.last.hasQuery, false);
      expect(web.creatorResolutions, 1);
      web.documents.last.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(find.text('Directory author'), findsNWidgets(1));
      expect(web.directoryReads, 1);
      await tester.tap(find.text('Directory author'));
      await _pump(tester);
      expect(web.creatorResolutions, 1);
      expect(web.documents.last.loads.last.path, '/user/88');
      expect(
        web.loads.any((u) => u.path == '/user/7'),
        false,
        reason: 'artist ID never constructs the profile URL',
      );
      expect(
        web.loads.any((u) => u.queryParameters['type'] == 'artist'),
        false,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'latest author tap cancels the earlier resolution and ignores its late failure',
    (tester) async {
      Map<String, dynamic> author(String id) => {
        'role': 'artist',
        'entityKey': 'artist:$id',
        'artistId': id,
        'name': 'Directory $id',
        'nameSearchUrl': 'https://hanime1.me/search?query=alias-$id',
      };
      final a = author('7'), b = author('8');
      web.domSnapshot = {
        'account': {'profileUrl': 'https://hanime1.me/user/42'},
      };
      web.creatorDirectory = {
        'ownerUrl': 'https://hanime1.me/user/42',
        'creators': [a, b],
      };
      web.resolvedCreator = {
        ...b,
        'ownerUrl': 'https://hanime1.me/user/42',
        'profileUrl': 'https://hanime1.me/user/99',
      };
      plugin.catalog = (core) async {
        final refs =
            ((core['snapshot'] as Map)['creatorDirectory'] as Map?)?['creators']
                as List? ??
            [];
        return {
          'data': {
            'sections': [],
            'videos': [],
            'account': {
              'status': 'signedIn',
              'isOwnProfile': false,
              'profileUrl': 'https://hanime1.me/user/42',
            },
            'creatorGroups': [
              for (final ref in refs) {'creator': ref, 'videos': []},
            ],
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      final delayed = Completer<dynamic>();
      web.nextCreatorRead = delayed.future;
      await tester.tap(find.text('Directory 7'));
      await _pump(tester, 2);
      await tester.ensureVisible(find.text('Directory 8'));
      await tester.tap(find.text('Directory 8'));
      await _pump(tester);
      expect(web.creatorResolutions, 2);
      expect(web.documents.last.loads.last.path, '/user/99');
      delayed.complete({
        'status': 'ok',
        'value': {
          ...a,
          'ownerUrl': 'https://hanime1.me/user/42',
          'profileUrl': 'https://hanime1.me/user/88',
        },
      });
      await _pump(tester);
      expect(web.documents.last.loads.last.path, '/user/99');
      expect(find.text(t.videoCommunity.creatorUnavailable), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an owner switch on a public profile discards the prior directory and identity',
    (tester) async {
      var owner = '42';
      web.domSnapshot = {
        'account': {'profileUrl': 'https://hanime1.me/user/42'},
      };
      web.creatorDirectory = {
        'ownerUrl': 'https://hanime1.me/user/42',
        'creators': [
          {
            'role': 'artist',
            'artistId': '7',
            'entityKey': 'artist:7',
            'name': 'Old author',
            'profileUrl': 'https://hanime1.me/user/88',
            'nameSearchUrl': 'https://hanime1.me/search?query=alias-7',
          },
        ],
      };
      plugin.catalog = (core) async {
        final uri = Uri.parse(core['pageUrl'] as String);
        final refs =
            ((core['snapshot'] as Map)['creatorDirectory'] as Map?)?['creators']
                as List? ??
            [];
        return {
          'data': {
            'sections': [],
            'videos': [],
            'account': {
              'status': 'signedIn',
              'isOwnProfile': false,
              'profileUrl': 'https://hanime1.me/user/$owner',
            },
            if (uri.path == '/user/88')
              'publicProfile': {'status': 'profile', 'name': 'Public author'},
            'creatorGroups': [
              for (final ref in refs) {'creator': ref, 'videos': []},
            ],
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Old author'));
      await _pump(tester);
      web.documents.last.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
      await _pump(tester);
      owner = '43';
      web.domSnapshot = {
        'account': {'profileUrl': 'https://hanime1.me/user/43'},
      };
      web.creatorDirectory = {
        'ownerUrl': 'https://hanime1.me/user/43',
        'creators': [],
      };
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(web.directoryReads, 2);
      expect(find.text('Old author'), findsNothing);
      final latest =
          plugin.calls.where((c) => c.$1 == 'catalog').last.$2['snapshot']
              as Map;
      expect(
        (latest['creatorDirectory'] as Map)['ownerUrl'],
        'https://hanime1.me/user/43',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'directory pagination keeps verified cursor after profile return and preserves prior authors',
    (tester) async {
      Map<String, dynamic> author(String id) => {
        'role': 'artist',
        'entityKey': 'artist:$id',
        'artistId': id,
        'name': 'Paged author $id',
        'profileUrl': 'https://hanime1.me/user/9$id',
        'nameSearchUrl': 'https://hanime1.me/search?query=alias-$id',
      };
      web.domSnapshot = {
        'account': {'profileUrl': 'https://hanime1.me/user/42'},
      };
      web.creatorDirectory = {
        'ownerUrl': 'https://hanime1.me/user/42',
        'creators': [author('7')],
        'nextUrl': 'https://hanime1.me/subscribe/artist?page=2',
      };
      plugin.catalog = (core) async {
        final refs =
            ((core['snapshot'] as Map)['creatorDirectory'] as Map?)?['creators']
                as List? ??
            [];
        return {
          'data': {
            'sections': [],
            'videos': [],
            'account': {
              'status': 'signedIn',
              'isOwnProfile': false,
              'profileUrl': 'https://hanime1.me/user/42',
            },
            'creatorGroups': [
              for (final ref in refs) {'creator': ref, 'videos': []},
            ],
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Paged author 7'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      web.creatorDirectory = {
        'ownerUrl': 'https://hanime1.me/user/42',
        'creators': [author('8')],
        'nextUrl': null,
      };
      await tester.ensureVisible(
        find.text(t.videoCommunity.moreSubscribedCreators),
      );
      await tester.tap(find.text(t.videoCommunity.moreSubscribedCreators));
      await _pump(tester);
      expect(web.directoryReads, 2);
      expect(web.loads.last.path, '/subscriptions');
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Paged author 7'), findsOneWidget);
      expect(find.text('Paged author 8'), findsOneWidget);
      expect(find.text(t.videoCommunity.moreSubscribedCreators), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'top search has external spacing from More and both retain phone touch targets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, plugin, textScale: 2);
      web.finishLastLoad();
      await _pump(tester);
      final search = tester.getRect(find.byType(VideoSearchEntry));
      final more = tester.getRect(find.byType(NativeVideoMenu));
      expect(more.left - search.right, greaterThanOrEqualTo(8));
      expect(320 - more.right, greaterThanOrEqualTo(8));
      expect(more.width, greaterThanOrEqualTo(44));
      expect(more.height, greaterThanOrEqualTo(44));
      expect(search.height, greaterThanOrEqualTo(44));
      expect(search.width, greaterThanOrEqualTo(190));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'catalog displays provided card metadata at large text without inventing empty metrics',
    (tester) async {
      plugin.catalog = (_) async => {
        'data': {
          'sections': [],
          'videos': [
            {
              'title': 'Observed metadata card',
              'watchUrl': 'https://hanime1.me/watch?v=1',
              'coverUrl': '',
              'creatorName': 'Artist',
              'subtitle': 'Artist • 2天前',
              'publishedRelative': '• 2天前',
              'duration': '01:24',
              'viewCountRaw': '1.2万次',
              'ratingPercentRaw': '99%',
            },
          ],
        },
      };
      await _mount(tester, plugin, textScale: 2);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Artist · 2天前'), findsOneWidget);
      expect(find.text('01:24'), findsOneWidget);
      expect(
        find.text(
          '${t.videoMetadata.views(value: '1.2万次')} · ${t.videoMetadata.rating(value: '99%')}',
        ),
        findsOneWidget,
      );
      expect(find.text('0%'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'personal identity and tabs survive pending, failed and stale tab responses',
    (tester) async {
      // Compatibility mode retains the old return-to-first-tab behavior.
      await SourceReturnPreferences.setMode(SourceReturnMode.stepByStep);
      final delayed = Completer<Map<String, dynamic>>();
      final account = {
        'status': 'signedIn',
        'isOwnProfile': true,
        'profileUrl': 'https://hanime1.me/user/42',
        'name': 'Stable identity',
        'links': [
          for (final entry in {
            '': 'Personal home',
            '/histories': 'History tab',
            '/saves': 'Saved tab',
          }.entries)
            {
              'title': entry.value,
              'url': 'https://hanime1.me/user/42${entry.key}',
            },
        ],
      };
      var fail = true;
      plugin.catalog = (core) async {
        final path = Uri.parse(core['pageUrl'] as String).path;
        if (path.endsWith('/histories')) return delayed.future;
        if (path.endsWith('/saves') && fail) {
          throw const FormatException('Fixture offline');
        }
        return {
          'data': {
            ..._catalog('Current collection')['data'] as Map<String, dynamic>,
            'account': account,
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await _openPersonalLibrary(tester, 'histories');
      await _pump(tester);
      expect(find.text('Stable identity'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      web.finishLastLoad();
      await _pump(tester);
      await _openPersonalLibrary(tester, 'saves');
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Stable identity'), findsOneWidget);
      expect(find.text(t.videoCommunity.network), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      delayed.complete({
        'data': {
          ..._catalog('Stale history')['data'] as Map<String, dynamic>,
          'account': account,
        },
      });
      await _pump(tester);
      expect(find.text('Stale history'), findsNothing);
      fail = false;
      await tester.tap(find.text(t.common.retry));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Current collection'), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(
        web.loads.last.path,
        '/user/42/saves',
        reason: 'return to the fresh overview does not reload the website',
      );
      expect(find.byType(VideoPersonalOverview), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(web.loads.last.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'subscription author shelves retain horizontal position and collapse after author return',
    (tester) async {
      Map<String, dynamic> card(int id) => {
        'title': 'Shelf video $id',
        'watchUrl': 'https://hanime1.me/watch?v=$id',
        'coverUrl': '',
      };
      plugin.catalog = (core) async {
        final path = Uri.parse(core['pageUrl'] as String).path;
        if (path == '/user/11') {
          return {
            'data': {
              'videos': [],
              'sections': [],
              'account': {'status': 'signedIn', 'isOwnProfile': false},
              'publicProfile': {
                'status': 'profile',
                'name': 'Author profile 11',
              },
            },
          };
        }
        return {
          'data': {
            'videos': [for (var i = 1; i <= 9; i++) card(i), card(99)],
            'sections': [],
            'account': {'status': 'signedIn'},
            'creatorGroups': [
              {
                'creator': {
                  'title': 'Author 11',
                  'pageUrl': 'https://hanime1.me/user/11',
                  'followed': true,
                },
                'videos': [for (var i = 1; i <= 8; i++) card(i)],
              },
              {
                'creator': {
                  'title': 'Author 22',
                  'pageUrl': 'https://hanime1.me/user/22',
                  'followed': true,
                },
                'videos': [card(9)],
              },
            ],
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      final row = find.byKey(
        const PageStorageKey('creator.videos.artist-profile:11'),
      );
      final scroll = find.descendant(
        of: row,
        matching: find.byType(Scrollable),
      );
      await tester.drag(row, const Offset(-350, 0));
      await _pump(tester);
      final offset = tester.state<ScrollableState>(scroll).position.pixels;
      expect(offset, greaterThan(100));
      final collapse = find.byTooltip(
        t.videoCommunity.collapseCreator(name: 'Author 22'),
      );
      await tester.ensureVisible(collapse);
      await tester.tap(collapse);
      await _pump(tester);
      expect(find.text('Shelf video 9'), findsNothing);
      await tester.ensureVisible(find.text('Author 11'));
      await _pump(tester, 2);
      await tester.tap(find.text('Author 11'));
      await _pump(tester);
      expect(web.documents.last.loads.last.path, '/user/11');
      expect(find.widgetWithText(AppBar, 'Author 11'), findsOneWidget);
      web.documents.last.finishLastLoad();
      await _pump(tester);
      expect(find.text('Author profile 11'), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        closeTo(offset, .1),
      );
      expect(
        find.byTooltip(t.videoCommunity.expandCreator(name: 'Author 22')),
        findsOneWidget,
      );
      expect(find.text('Shelf video 9'), findsNothing);
      await tester.ensureVisible(find.text('Shelf video 99'));
      expect(
        find.text('Shelf video 99'),
        findsOneWidget,
        reason: 'unassigned videos remain accessible',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'personal tabs restore independent scroll positions using the fresh cache',
    (tester) async {
      plugin.catalog = (core) async => {
        'data': {
          'sections': [],
          'videos': [
            for (var id = 1; id <= 80; id++)
              {
                'title': 'Collection $id',
                'watchUrl': 'https://hanime1.me/watch?v=$id',
                'coverUrl': '',
              },
          ],
          'account': {
            'status': 'signedIn',
            'isOwnProfile': true,
            'profileUrl': 'https://hanime1.me/user/42',
            'name': 'Scroll account',
            'links': [
              for (final kind in ['histories', 'saves'])
                {'title': kind, 'url': 'https://hanime1.me/user/42/$kind'},
            ],
          },
        },
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await _openPersonalLibrary(tester, 'saves');
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      final saved = find.byKey(
        const PageStorageKey('video-catalog.https://hanime1.me/user/42/saves'),
      );
      final savedScroll = find.descendant(
        of: saved,
        matching: find.byType(Scrollable),
      );
      await tester.drag(saved, const Offset(0, -430));
      await _pump(tester);
      final savedOffset = tester
          .state<ScrollableState>(savedScroll)
          .position
          .pixels;
      await _openPersonalLibrary(tester, 'histories');
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      final history = find.byKey(
        const PageStorageKey(
          'video-catalog.https://hanime1.me/user/42/histories',
        ),
      );
      final historyScroll = find.descendant(
        of: history,
        matching: find.byType(Scrollable),
      );
      expect(tester.state<ScrollableState>(historyScroll).position.pixels, 0);
      await tester.drag(history, const Offset(0, -230));
      await _pump(tester);
      final historyOffset = tester
          .state<ScrollableState>(historyScroll)
          .position
          .pixels;
      final requests = web.loads.length;
      await _openPersonalLibrary(tester, 'saves');
      await _pump(tester);
      expect(
        web.loads.length,
        requests,
        reason: 'a fresh personal tab does not navigate the browser again',
      );
      expect(
        tester.state<ScrollableState>(savedScroll).position.pixels,
        closeTo(savedOffset, .1),
      );
      await _openPersonalLibrary(tester, 'histories');
      await _pump(tester);
      expect(
        tester.state<ScrollableState>(historyScroll).position.pixels,
        closeTo(historyOffset, .1),
      );
      expect(find.text('Scroll account'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'partial identity is marked unconfirmed and logout clears the cached identity',
    (tester) async {
      plugin.catalog = (core) async {
        final path = Uri.parse(core['pageUrl'] as String).path;
        return {
          'data': {
            'sections': [],
            'videos': [],
            'account': path.endsWith('/histories')
                ? {'status': 'unknown', 'isOwnProfile': false}
                : path.endsWith('/saves')
                ? {'status': 'signedOut', 'isOwnProfile': false}
                : {
                    'status': 'signedIn',
                    'isOwnProfile': true,
                    'profileUrl': 'https://hanime1.me/user/42',
                    'name': 'Confirmed identity',
                    'links': [
                      for (final kind in ['histories', 'saves'])
                        {
                          'title': kind,
                          'url': 'https://hanime1.me/user/42/$kind',
                        },
                    ],
                  },
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await _openPersonalLibrary(tester, 'histories');
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Confirmed identity'), findsOneWidget);
      expect(find.text(t.videoPlayback.accountUnconfirmed), findsOneWidget);
      await _openPersonalLibrary(tester, 'saves');
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Confirmed identity'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text(t.videoCommunity.loginRequired), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'subscription aliases share one author row and canonical native destination',
    (tester) async {
      plugin.catalog = (_) async => {
        'data': {
          'sections': [],
          'videos': [],
          'account': {'status': 'signedIn'},
          'creators': [
            {
              'title': 'Canonical author',
              'role': 'artist',
              'artistId': '44',
              'profileUrl': 'https://hanime1.me/user/11',
              'nameSearchUrl': 'https://hanime1.me/search?query=canonical-key',
            },
          ],
          'creatorGroups': [
            {
              'creator': {
                'title': 'Canonical author',
                'role': 'artist',
                'artistId': '44',
                'profileUrl': 'https://hanime1.me/user/11',
                'nameSearchUrl':
                    'https://hanime1.me/search?query=canonical-key',
              },
              'videos': [
                {
                  'title': 'Alias video',
                  'watchUrl': 'https://hanime1.me/watch?v=11',
                  'coverUrl': '',
                },
              ],
            },
          ],
        },
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Canonical author'), findsOneWidget);
      expect(find.text('Alias video'), findsOneWidget);
      await tester.tap(find.text('Canonical author'));
      await _pump(tester);
      expect(
        web.documents.last.loads.last.toString(),
        'https://hanime1.me/user/11',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native personal lists open videos and restore the same collection',
    (tester) async {
      plugin.catalog = (core) async {
        final data = _catalog('Site video')['data'] as Map<String, dynamic>;
        return {
          'data': {
            ...data,
            'account': {
              'status': 'signedIn',
              'isOwnProfile': true,
              'name': 'Example account',
              'links': [
                for (final name in ['histories', 'saves', 'likes', 'playlists'])
                  {
                    'title': 'Site $name',
                    'url': 'https://hanime1.me/user/42/$name',
                  },
              ],
            },
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Example account'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      expect(find.text(t.videoPlayback.localWatchHistory), findsNothing);
      expect(find.byType(VideoPersonalOverview), findsOneWidget);
      for (final name in ['histories', 'saves', 'likes', 'playlists']) {
        await _openPersonalLibrary(tester, name);
        await _pump(tester);
        expect(web.loads.last.path, '/user/42/$name');
        web.finishLastLoad();
        await _pump(tester);
        expect(
          find.byWidgetPredicate(
            (w) => w is NativeVideoMenu && w.selected == 'native',
          ),
          findsOneWidget,
        );
      }
      await tester.ensureVisible(find.text('Site video'));
      await _pump(tester, 2);
      await tester.tap(find.text('Site video'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      if (find.byType(NativeVideoPage).evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
      } else {
        await tester.pageBack();
      }
      await _pump(tester);
      expect(
        find.text('Example account'),
        findsOneWidget,
        reason: 'the same identity remains above every personal tab',
      );
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
      expect(find.text('Site video'), findsOneWidget);
      expect(
        web.loads.last.path,
        '/watch',
        reason: 'return uses the cached native list',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native subscription lists open the native player without visiting a webpage',
    (tester) async {
      plugin.catalog = (_) async => {
        'data': {
          ..._catalog('Subscribed video')['data'] as Map<String, dynamic>,
          'account': {'status': 'signedIn'},
        },
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Subscribed video'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'required website login and registration never offer a native switch',
    (tester) async {
      plugin.catalog = (_) async => {
        'data': {
          'videos': [],
          'sections': [],
          'account': {'status': 'signedOut'},
        },
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(t.videoCommunity.login));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      for (final path in ['/login', '/register']) {
        web.currentUrl = Uri.parse('https://hanime1.me$path');
        web.params.onLoadStart?.call(
          web.wrapped,
          WebUri(web.currentUrl.toString()),
        );
        web.params.onLoadStop?.call(
          web.wrapped,
          WebUri(web.currentUrl.toString()),
        );
        await _pump(tester);
        final options = tester
            .widget<NativeVideoMenu>(
              find.byWidgetPredicate(
                (w) =>
                    w is NativeVideoMenu &&
                    w.tooltip == t.videoPlayback.browserActions,
              ),
            )
            .options;
        expect(options.containsKey('native'), false);
        expect(options.containsKey('website'), false);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'verification has help and retry actions but no impossible native switch',
    (tester) async {
      web.challenge = true;
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      final menu = tester.widget<NativeVideoMenu>(
        find.byWidgetPredicate(
          (w) =>
              w is NativeVideoMenu &&
              w.tooltip == t.videoPlayback.verificationActions,
        ),
      );
      expect(menu.options.containsKey('native'), false);
      expect(menu.options.containsKey('website'), false);
      expect(menu.options.keys, containsAll(['help', 'check', 'reload']));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'website login returns to the requested native subscription list',
    (tester) async {
      var signedIn = false;
      plugin.catalog = (_) async => {
        'data': {
          ..._catalog('After login')['data'] as Map<String, dynamic>,
          'account': {'status': signedIn ? 'signedIn' : 'signedOut'},
        },
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text(t.videoCommunity.login));
      await _pump(tester);
      expect(web.loads.last.path, '/login');
      web.finishLastLoad();
      await _pump(tester);
      signedIn = true;
      web.currentUrl = Uri.parse('https://hanime1.me/user/42');
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester, 15);
      expect(web.loads.last.path, '/subscriptions');
      web.finishLastLoad();
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      expect(find.text('After login'), findsOneWidget);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native authentication redirect is visible and resumes without an app reload',
    (tester) async {
      var signedIn = false;
      plugin.catalog = (_) async => {
        'data': {
          ..._catalog('Subscription after redirect')['data']
              as Map<String, dynamic>,
          'account': {'status': signedIn ? 'signedIn' : 'signedOut'},
        },
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      final loads = web.loads.length;
      web.currentUrl = Uri.parse('https://hanime1.me/login');
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      expect(find.byTooltip(t.videoPlayback.browserActions), findsOneWidget);
      expect(web.loads, hasLength(loads));
      signedIn = true;
      web.currentUrl = Uri.parse('https://hanime1.me/user/42');
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester, 15);
      expect(web.loads.last.path, '/subscriptions');
      web.finishLastLoad();
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('native profile fits 320px and large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      plugin.catalog = (_) async => {
        'data': {
          'videos': [],
          'sections': [],
          'paging': {
            'page': 1,
            'totalPages': 2,
            'nextUrl': 'https://hanime1.me/user/42?page=2',
          },
          'account': {
            'status': 'signedIn',
            'isOwnProfile': true,
            'name': 'A long account name 账户名字账户名字',
            'summary': 'Example profile information',
          },
        },
      };
      await _mount(
        tester,
        plugin,
        nativePersonal: true,
        textScale: 2,
        brightness: brightness,
      );
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('A long account name 账户名字账户名字'), findsOneWidget);
      await tester.ensureVisible(find.text(t.common.nextPage));
      await _pump(tester);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, t.common.nextPage),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'leaving native login prevents a late auth redirect from replacing the list',
    (tester) async {
      await _openNativeLogin(tester, plugin, web);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(find.byType(NativeVideoAuthForm), findsNothing);
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      web.profileHref = '/user/42';
      web.currentUrl = Uri.parse('https://hanime1.me/');
      final url = WebUri(web.currentUrl.toString());
      web.params.onPageCommitVisible?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester);
      expect(web.loads.length, loads);
      expect(find.text('Feed card'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a stale login completion cannot replace its committed auth redirect',
    (tester) async {
      await _openNativeLogin(tester, plugin, web);
      web.siteReady = false;
      web.authUiReady = true;
      web.profileHref = '/user/42';
      web.currentUrl = Uri.parse('https://hanime1.me/');
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri('https://hanime1.me/login'),
      );
      await _pump(tester, 15);
      expect(web.loads.last.path, '/subscriptions');
      web.siteReady = true;
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Feed card'), findsOneWidget);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native authentication resumes its destination after a verification redirect',
    (tester) async {
      await _openNativeLogin(tester, plugin, web);
      final loads = web.loads.length;
      web.challenge = true;
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      expect(web.loads.length, loads);
      web.challenge = false;
      web.siteReady = false;
      web.authUiReady = true;
      web.profileHref = '/user/42';
      web.currentUrl = Uri.parse('https://hanime1.me/');
      final url = WebUri(web.currentUrl.toString());
      web.params.onPageCommitVisible?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester);
      expect(web.loads.last.path, '/subscriptions');
      web.siteReady = true;
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Feed card'), findsOneWidget);
      expect(find.text(t.videoPlayback.verificationTitle), findsNothing);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native login handles a home redirect then resumes subscriptions in the same browser',
    (tester) async {
      var signedIn = false;
      plugin.catalog = (core) async {
        final page = Uri.parse(core['pageUrl'] as String);
        return {
          'data': {
            'videos': signedIn
                ? (_catalog('Resumed feed')['data'] as Map)['videos']
                : [],
            'sections': [],
            'account': {
              'status': signedIn ? 'signedIn' : 'signedOut',
              'profileUrl': signedIn ? 'https://hanime1.me/user/42' : '',
            },
            if (page.path == '/login')
              'auth': {'supported': true, 'mode': 'login'},
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true, nativeAuth: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text(t.videoCommunity.login));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byType(NativeVideoAuthForm), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'fixture@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await _pump(tester);
      expect(web.authSubmissions, 1);
      signedIn = true;
      web.siteReady = false;
      web.authUiReady = true;
      web.profileHref = '/user/42';
      web.currentUrl = Uri.parse('https://hanime1.me/');
      final url = WebUri(web.currentUrl.toString());
      web.params.onLoadStart?.call(web.wrapped, url);
      web.params.onPageCommitVisible?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester, 15);
      expect(web.loads.last.path, '/subscriptions');
      web.siteReady = true;
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Resumed feed'), findsOneWidget);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an unsupported ordinary auth form waits for an explicit website choice',
    (tester) async {
      plugin.catalog = (_) async => {
        'data': {
          'videos': [],
          'sections': [],
          'account': {'status': 'signedOut'},
          'auth': {
            'supported': false,
            'mode': 'login',
            'reason': 'unsupported',
          },
        },
      };
      await _mount(tester, plugin, nativePersonal: true, nativeAuth: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text(t.videoPlayback.catalogFallback), findsOneWidget);
      expect(find.byTooltip(t.videoPlayback.browserActions), findsNothing);
      await tester.tap(
        find.widgetWithText(OutlinedButton, t.videoPlayback.website),
      );
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byTooltip(t.videoPlayback.browserActions), findsOneWidget);
      expect(web.loads.last.path, '/login');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native auth offers registration but captcha remains a required browser task',
    (tester) async {
      plugin.catalog = (core) async {
        final page = Uri.parse(core['pageUrl'] as String);
        return {
          'data': {
            'videos': [],
            'sections': [],
            'account': {'status': 'signedOut'},
            if (page.path == '/login' || page.path == '/register')
              'auth': {
                'supported': page.path == '/login',
                'mode': page.path.substring(1),
                'reason': 'verification',
              },
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true, nativeAuth: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byType(NativeVideoAuthForm), findsOneWidget);
      await tester.ensureVisible(find.text(t.videoCommunity.createAccount));
      await tester.tap(find.text(t.videoCommunity.createAccount));
      await _pump(tester);
      expect(web.loads.last.path, '/register');
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byType(NativeVideoAuthForm), findsNothing);
      final menu = tester.widget<NativeVideoMenu>(
        find.byWidgetPredicate(
          (w) =>
              w is NativeVideoMenu &&
              w.tooltip == t.videoPlayback.browserActions,
        ),
      );
      expect(menu.options.containsKey('native'), false);
      expect(web.authSubmissions, 0);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('full website and verification use only the website navigation', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await _chooseMode(tester, t.videoPlayback.website);
    web.finishLastLoad();
    await _pump(tester);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('website-document')), findsOneWidget);
    await _chooseMode(tester, t.videoPlayback.nativeCatalog);
    web.finishLastLoad();
    await _pump(tester);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home card'), findsOneWidget);
    web.challenge = true;
    await tester.tap(find.text('排行'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    web.challenge = false;
    await _pump(tester, 40);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Rank card'), findsOneWidget);
    expect(web.creations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'website self profile selects My after native identity confirmation',
    (tester) async {
      plugin.sourceValues['video.defaultMode'] = 'website';
      plugin.catalog = (core) async => {
        'data': {
          'videos': [],
          'sections': [],
          'account': {
            'status': 'signedIn',
            'isOwnProfile': true,
            'profileUrl': 'https://hanime1.me/user/42',
            'name': 'Confirmed account',
            'links': [
              {'title': 'home', 'url': 'https://hanime1.me/user/42'},
            ],
          },
        },
      };
      await _mount(tester, plugin, nativePersonal: true);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byType(BottomNavigationBar), findsNothing);
      await web.navigateWebsite(Uri.parse('https://hanime1.me/user/42'));
      await _pump(tester);
      expect(find.byType(BottomNavigationBar), findsNothing);
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester);
      expect(find.text('Confirmed account'), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        3,
      );
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(web.loads.last.path, '/');
      // A newer explicit native choice takes precedence over old web history.
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final optedIn in [false, true]) {
    testWidgets(
      'Google website continuation requires explicit opt-in $optedIn',
      (tester) async {
        final entry = Uri.parse('https://hanime1.me/auth/google');
        final launches = <MethodCall>[];
        var openSucceeded = true;
        const launcher = MethodChannel('plugins.flutter.io/url_launcher');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launcher, (call) async {
              launches.add(call);
              return openSucceeded;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(launcher, null),
        );
        web.authMetadata = {
          'supported': true,
          'mode': 'login',
          'googleUrl': entry.toString(),
        };
        plugin.catalog = (core) async => {
          'data': {
            'videos': [],
            'sections': [],
            'account': {'status': 'signedOut'},
            if (Uri.parse(core['pageUrl'] as String).path == '/login')
              'auth': web.authMetadata,
          },
        };
        await _mount(
          tester,
          plugin,
          nativePersonal: true,
          nativeAuth: true,
          externalAuthenticationEntries: optedIn ? [entry] : [],
        );
        web.finishLastLoad();
        await _pump(tester);
        await tester.tap(find.text('我的'));
        await _pump(tester);
        web.finishLastLoad();
        await _pump(tester);
        expect(find.byType(NativeVideoAuthForm), findsOneWidget);
        final google = find.text(t.videoSiteAccount.googleInBrowser);
        if (!optedIn) {
          expect(google, findsNothing);
          expect(launches, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        await tester.enterText(
          find.byType(TextFormField).first,
          'fixture@example.test',
        );
        final originalLoads = web.loads.length;
        await tester.ensureVisible(google);
        await tester.tap(google);
        await _pump(tester);
        expect(find.text(t.videoSiteAccount.googleWebsiteNote), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
        await _pump(tester);
        expect(launches, isEmpty);
        expect(web.authSubmissions, 0);
        expect(web.loads, hasLength(originalLoads));
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'fixture@example.test',
        );
        await tester.tap(google);
        await _pump(tester);
        await tester.tap(find.text(t.videoSiteAccount.continueInBrowser));
        await _pump(tester);
        expect(launches, hasLength(1));
        expect(launches.single.method, 'launch');
        expect(launches.single.arguments['url'], entry.toString());
        expect(launches.single.arguments['useSafariVC'], false);
        expect(launches.single.arguments['useWebView'], false);
        expect(web.authSubmissions, 0);
        expect(web.loads, hasLength(originalLoads));
        expect(find.byType(NativeVideoAuthForm), findsOneWidget);
        openSucceeded = false;
        await tester.tap(google);
        await _pump(tester);
        await tester.tap(find.text(t.videoSiteAccount.continueInBrowser));
        await _pump(tester);
        expect(find.text(t.videoSiteAccount.browserOpenFailed), findsOneWidget);
        expect(
          find.widgetWithText(SnackBarAction, t.common.retry),
          findsOneWidget,
        );
        final browser = tester.widget<VideoSiteBrowser>(
          find.byType(VideoSiteBrowser),
        );
        browser.onExternalAuthentication!(
          Uri.parse('https://accounts.google.com/?state=private'),
        );
        await _pump(tester);
        expect(find.text(t.videoSiteAccount.googleWebsiteNote), findsNothing);
        browser.onExternalAuthentication!(entry);
        browser.onExternalAuthentication!(entry);
        await _pump(tester);
        expect(find.text(t.videoSiteAccount.googleWebsiteNote), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
        await _pump(tester);
        expect(launches, hasLength(2));
        expect(web.creations, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('website fallback switches back to the same detail repeatedly', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('Home card'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester, 20);
    for (var i = 0; i < 3; i++) {
      expect(find.text('Detail 1'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextButton, t.videoPlayback.backToWeb),
      );
      await tester.tap(
        find.widgetWithText(TextButton, t.videoPlayback.backToWeb),
      );
      await _pump(tester);
      expect(web.loads.last.queryParameters['v'], '1');
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester, 20);
      expect(web.loads, hasLength(loads));
      expect(find.text('Detail 1'), findsOneWidget);
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      expect(find.byType(NativeVideoPage), findsOneWidget);
    }
    expect(web.creations, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a challenge on a subscription video resumes that native detail once',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      web.challenge = true;
      web.currentUrl = Uri.parse('https://hanime1.me/watch?v=77');
      final url = WebUri(web.currentUrl.toString());
      web.params.onLoadStart?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(web.loads, hasLength(loads));
      web.challenge = false;
      await _pump(tester, 40);
      expect(find.text('Detail 77'), findsOneWidget);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(web.loads, hasLength(loads));
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a stale getUrl cannot replace the requested native video with home',
    (tester) async {
      plugin.sourceValues['video.defaultMode'] = 'website';
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      web.currentUrl = Uri.parse('https://hanime1.me/watch?v=77');
      final url = WebUri(web.currentUrl.toString());
      web.params.onLoadStart?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester);
      web.nextUrl = Future.value(WebUri('https://hanime1.me/'));
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      expect(web.loads.last.queryParameters['v'], '77');
      web.finishLastLoad();
      await _pump(tester, 20);
      expect(find.text('Detail 77'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed native profile video stays native and can fall back at the same URL',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      plugin.failDetail = true;
      web.currentUrl = Uri.parse('https://hanime1.me/watch?v=77');
      final url = WebUri(web.currentUrl.toString());
      web.params.onLoadStart?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester, 20);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      expect(find.text(t.videoPlayback.catalogFallback), findsOneWidget);
      await _chooseMode(tester, t.videoPlayback.website);
      expect(web.loads.last.path, '/watch');
      expect(web.loads.last.queryParameters['v'], '77');
      web.finishLastLoad();
      await _pump(tester);
      plugin.failDetail = false;
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      await _pump(tester, 20);
      expect(find.text('Detail 77'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'back from a failed native subscription video restores its subscription parent',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('订阅'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      plugin.failDetail = true;
      web.currentUrl = Uri.parse('https://hanime1.me/watch?v=77');
      final url = WebUri(web.currentUrl.toString());
      web.params.onLoadStart?.call(web.wrapped, url);
      web.params.onLoadStop?.call(web.wrapped, url);
      await _pump(tester, 20);
      expect(find.text(t.videoPlayback.catalogFallback), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(web.loads.last.path, '/subscriptions');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a late challenge during native playback offers verification', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('Home card'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester, 20);
    web.challenge = true;
    final loads = web.loads.length;
    await _pump(tester, 60);
    expect(find.text(t.videoPlayback.continueVerification), findsOneWidget);
    await tester.tap(find.text(t.videoPlayback.continueVerification));
    await _pump(tester);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(web.loads, hasLength(loads));
    web.challenge = false;
    await _pump(tester, 40);
    expect(find.text('Detail 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a challenge arriving after a load error remains actionable', (
    tester,
  ) async {
    final web = _WebPlatform()..siteReady = false;
    InAppWebViewPlatform.instance = web;
    await _mount(tester, _Plugin());
    web.currentUrl = web.loads.last;
    web.params.onLoadStart?.call(
      web.wrapped,
      WebUri(web.currentUrl.toString()),
    );
    await _pump(tester, 320);
    expect(find.text(t.videoPlayback.catalogFallback), findsOneWidget);
    final loadCount = web.loads.length;
    web.challenge = true;
    await _pump(tester, 60);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(find.text(t.videoPlayback.catalogFallback), findsNothing);
    expect(web.loads.length, loadCount);
    expect(web.creations, 1);
    web.challenge = false;
    web.siteReady = true;
    await _verificationAction(tester, 'check');
    await _pump(tester);
    expect(find.text('Home card'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('all source options reach their declared host boundaries', (
    tester,
  ) async {
    plugin.sourceValues = {
      'video.defaultMode': 'website',
      'video.parseTimeoutSeconds': '15',
      'video.preferredSource': 'highest',
      'video.refreshExpiredSources': false,
    };
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w is NativeVideoMenu && w.selected == 'website',
      ),
      findsOneWidget,
    );
    expect(plugin.calls.where((call) => call.$1 == 'catalog'), isEmpty);
    await _chooseMode(tester, t.videoPlayback.nativeCatalog);
    await _pump(tester);
    await tester.tap(find.text('Home card'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester, 20);
    final player = tester.widget<NativeVideoPage>(find.byType(NativeVideoPage));
    expect(player.preferredSource, 'highest');
    expect(player.refreshSession, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final entry in ['home', 'ranking', 'search', 'detail']) {
    testWidgets('$entry verification stays interactive and resumes natively', (
      tester,
    ) async {
      if (entry == 'home') web.challenge = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      if (entry != 'home') {
        web.challenge = true;
        if (entry == 'ranking') {
          await tester.tap(find.text('排行'));
        } else if (entry == 'detail') {
          await tester.tap(find.text('Home card'));
        } else {
          await tester.tap(find.byTooltip(t.videoPlayback.search));
          await _pump(tester);
          await tester.enterText(find.byType(TextField), 'test');
          await tester.testTextInput.receiveAction(TextInputAction.search);
        }
        await _pump(tester);
        web.finishLastLoad();
        await _pump(tester);
      }
      final loadCount = web.loads.length;
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      expect(find.text(t.videoPlayback.catalogFallback), findsNothing);
      final browser = find.byKey(const ValueKey('website-document'));
      final pointer = tester.widget<IgnorePointer>(
        find.ancestor(of: browser, matching: find.byType(IgnorePointer)).first,
      );
      final viewport = tester.getSize(browser);
      expect(
        find.ancestor(
          of: browser,
          matching: find.byWidgetPredicate(
            (widget) => widget is Opacity && widget.opacity < 1,
          ),
        ),
        findsNothing,
      );
      expect(pointer.ignoring, isFalse);
      await _pump(tester, 650);
      expect(tester.getSize(browser), viewport);
      await _verificationAction(tester, 'help');
      expect(
        find.textContaining(t.videoPlayback.verificationSlow),
        findsOneWidget,
      );
      await tester.tap(find.text(t.videoPlayback.acknowledge));
      await _pump(tester);
      expect(
        web.loads,
        hasLength(loadCount),
      ); // Never auto-reload verification.
      expect(web.creations, 1); // Same browser and cookie store throughout.
      web.challenge = false;
      await _verificationAction(tester, 'check');
      await _pump(tester, 20);
      expect(find.text(t.videoPlayback.verificationTitle), findsNothing);
      if (entry == 'detail') {
        expect(find.byType(NativeVideoPage), findsOneWidget);
      } else {
        expect(
          find.text(entry == 'ranking' ? 'Rank card' : 'Home card'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is NativeVideoMenu && w.selected == 'native',
          ),
          findsOneWidget,
        );
      }
      expect(web.loads, hasLength(loadCount));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'challenge is shown before load-stop and website mode is retained',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.website);
      web.currentUrl = web.loads.last;
      web.challenge = true;
      web.params.onLoadStart?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester, 60);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      web.challenge = false;
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'website',
        ),
        findsOneWidget,
      );
      expect(find.text('Home card'), findsNothing);
      expect(plugin.calls.where((call) => call.$1 == 'catalog'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('late challenge detection cannot replace the new tab', (
    tester,
  ) async {
    final lateState = Completer<dynamic>();
    web.nextSiteState = lateState.future;
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester, 1);
    await tester.tap(find.text('排行'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester);
    lateState.complete({'url': 'https://hanime1.me/', 'challengeShell': true});
    await _pump(tester);
    expect(find.text('Rank card'), findsOneWidget);
    expect(find.text(t.videoPlayback.verificationTitle), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'player More exit cannot restore a catalog that is still animating out',
    (tester) async {
      final originalVideo = VideoPlayerPlatform.instance;
      final media = _ReturnVideoPlatform();
      VideoPlayerPlatform.instance = media;
      addTearDown(() => VideoPlayerPlatform.instance = originalVideo);
      plugin.playable = true;
      // A cold detail entry has no fresh catalog cache to hide an unwanted
      // restoration load after the player route completes.
      await _mount(
        tester,
        plugin,
        nestedRoot: true,
        initialUrl: Uri.parse('https://hanime1.me/watch?v=1'),
      );
      final catalog = find.byType(NativeVideoCatalogPage);
      final catalogState = tester.state(catalog);
      final catalogRoute = ModalRoute.of(tester.element(catalog))!;
      web.finishLastLoad();
      await _pump(tester, 20);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(media.activePlayers, 1);
      await tester.tap(find.byTooltip(t.videoPlayback.playbackSettings));
      await _pump(tester, 3);
      final panel = find.byType(VideoPlaybackQuickPanel);
      final exit = find.widgetWithText(ListTile, t.sourceShell.exitSource);
      await tester.scrollUntilVisible(
        exit,
        300,
        scrollable: find
            .descendant(of: panel, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      final loads = web.loads.length;
      final parses = plugin.calls.length;
      await tester.tap(exit);
      await tester.pump();
      expect(
        catalogState.mounted,
        isTrue,
        reason: 'inspect during the 2s exit transition',
      );
      expect(catalogRoute.isActive, isFalse);
      expect(
        web.loads,
        hasLength(loads),
        reason: 'a popped catalog must not restore home while still mounted',
      );
      expect(plugin.calls, hasLength(parses));
      await _pump(tester, 25);
      await tester.runAsync(() async {});
      await tester.pump();
      expect(find.text('Open fixture source'), findsOneWidget);
      expect(find.byType(NativeVideoPage), findsNothing);
      expect(find.byType(NativeVideoCatalogPage), findsNothing);
      expect(media.activePlayers, 0);
      expect(web.loads, hasLength(loads));
      expect(plugin.calls, hasLength(parses));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('late source refresh cannot navigate after leaving the player', (
    tester,
  ) async {
    final originalVideo = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _ReturnVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = originalVideo);
    plugin.playable = true;
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('Home card'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester, 20);
    final player = tester.widget<NativeVideoPage>(find.byType(NativeVideoPage));
    final origin = Completer<dynamic>();
    web.nextTimeOrigin = origin.future;
    Object? failure;
    final refresh = player.refreshSession!().then<void>(
      (_) {},
      onError: (Object error) {
        failure = error;
      },
    );
    await _pump(tester, 1);
    Navigator.of(tester.element(find.byType(NativeVideoPage))).pop();
    await _pump(tester, 12);
    expect(find.byType(NativeVideoPage), findsNothing);
    final count = web.loads.length;
    origin.complete(123);
    await _pump(tester, 12);
    await refresh;
    expect(
      web.loads.length,
      count,
      reason:
          'a source refresh from the departed player must not navigate over its restored parent',
    );
    expect(failure, isA<StateError>());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'episode preparation reads a newly committed ready DOM without waiting for slow page resources',
    (tester) async {
      plugin.playable = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      final player = tester.widget<NativeVideoPage>(
        find.byType(NativeVideoPage),
      );
      final next = Uri.parse('https://hanime1.me/watch?v=2');
      var complete = false;
      final pending = player.loadEpisode!(next).then((result) {
        complete = true;
        return result;
      });
      await _pump(tester);
      web.currentUrl = next;
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(next.toString()),
      );
      await _pump(tester, 15);
      final completedBeforeResources = complete;
      web.finishLastLoad();
      await _pump(tester, 15);
      final result = await pending;
      expect(result.session.watchUrl, next);
      expect(
        completedBeforeResources,
        true,
        reason:
            'new ready DOM is sufficient; full onLoadStop may wait on media or ad resources',
      );
      result.operations?.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'manual playback document reads queue instead of failing when another read is active',
    (tester) async {
      plugin.playable = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester, 20);
      final player = tester.widget<NativeVideoPage>(
        find.byType(NativeVideoPage),
      );
      final second = Uri.parse('https://hanime1.me/watch?v=2'),
          third = Uri.parse('https://hanime1.me/watch?v=3');
      final a = player.loadEpisode!(second), b = player.loadEpisode!(third);
      await _pump(tester);
      expect(web.loads.last, second);
      expect(
        web.loads.where((u) => u == third),
        isEmpty,
        reason:
            'A concurrent request waits instead of navigating or throwing busy',
      );
      web.currentUrl = second;
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(second.toString()),
      );
      await _pump(tester, 20);
      final ar = await a;
      expect(ar.session.watchUrl, second);
      expect(web.loads.last, third);
      web.currentUrl = third;
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(third.toString()),
      );
      await _pump(tester, 20);
      final br = await b;
      expect(br.session.watchUrl, third);
      final wrong = Uri.parse('https://hanime1.me/watch?v=4');
      web.domSnapshot = {'documentUrl': second.toString()};
      final rejected = expectLater(
        player.loadEpisode!(wrong),
        throwsFormatException,
      );
      await _pump(tester);
      web.currentUrl = wrong;
      web.params.onPageCommitVisible?.call(
        web.wrapped,
        WebUri(wrong.toString()),
      );
      await _pump(tester, 25);
      await rejected;
      ar.operations?.dispose();
      br.operations?.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('source refresh verification returns to the same native detail', (
    tester,
  ) async {
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('Home card'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester, 20);
    expect(find.text('Detail 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, t.common.retry));
    await _pump(tester);
    web.challenge = true;
    web.finishLastLoad();
    await _pump(tester);
    expect(find.text(t.videoPlayback.continueVerification), findsOneWidget);
    final loads = web.loads.length;
    await tester.tap(find.text(t.videoPlayback.continueVerification));
    await _pump(tester);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    expect(web.loads, hasLength(loads));
    web.challenge = false;
    await _pump(tester, 40);
    expect(find.text('Detail 1'), findsOneWidget);
    expect(find.byType(NativeVideoPage), findsOneWidget);
    expect(web.loads, hasLength(loads));
    expect(web.creations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'only explicit reload restarts a challenge using the same browser',
    (tester) async {
      web.challenge = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      final loads = web.loads.length;
      final viewport = tester.getSize(
        find.byKey(const ValueKey('website-document')),
      );
      await _verificationAction(tester, 'reload');
      await tester.tap(find.widgetWithText(TextButton, t.common.retry));
      await _pump(tester);
      expect(web.loads, hasLength(loads + 1));
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('website-document'))),
        viewport,
      );
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(web.loads, hasLength(loads + 1));
      web.challenge = false;
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      expect(find.text(t.videoPlayback.verificationTitle), findsNothing);
      await tester.tap(find.text('排行'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Rank card'), findsOneWidget);
      expect(web.creations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a late reload confirmation cannot restart an already completed verification',
    (tester) async {
      web.challenge = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      final stops = web.stops;
      await _verificationAction(tester, 'reload');
      web.challenge = false;
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      await tester.tap(find.widgetWithText(TextButton, t.common.retry));
      await _pump(tester);
      expect(web.loads, hasLength(1));
      expect(web.stops, stops);
      expect(find.text('Home card'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'frame policy permits verification but not third-party top pages',
    (tester) async {
      await _mount(tester, plugin);
      final policy = web.params.shouldOverrideUrlLoading!;
      Future<NavigationActionPolicy?> decide(String url, bool main) => policy(
        web.wrapped,
        NavigationAction(
          request: URLRequest(url: WebUri(url)),
          isForMainFrame: main,
        ),
      );
      expect(
        await decide('https://challenges.cloudflare.com/turnstile', false),
        NavigationActionPolicy.ALLOW,
      );
      expect(await decide('about:srcdoc', false), NavigationActionPolicy.ALLOW);
      expect(
        await decide('https://challenges.cloudflare.com/', true),
        NavigationActionPolicy.CANCEL,
      );
      expect(
        await decide('https://example.com/frame', false),
        NavigationActionPolicy.ALLOW,
      );
      expect(
        await decide('https://example.com/ad', true),
        NavigationActionPolicy.CANCEL,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('temporary verification parameters preserve the requested page', (
    tester,
  ) async {
    web.challenge = true;
    await _mount(tester, plugin);
    web.currentUrl = Uri.parse('https://hanime1.me/?__cf_chl_rt_tk=temporary');
    final temporary = WebUri(web.currentUrl.toString());
    web.params.onLoadStart?.call(web.wrapped, temporary);
    web.params.onLoadStop?.call(web.wrapped, temporary);
    await _pump(tester);
    expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
    web.challenge = false;
    web.params.onLoadStop?.call(web.wrapped, temporary);
    await _pump(tester);
    expect(find.text('Home card'), findsOneWidget);
    final url = plugin.calls
        .lastWhere((call) => call.$1 == 'catalog')
        .$2['pageUrl'];
    expect(url, 'https://hanime1.me/');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'verification notice fits a phone with large accessibility text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      web.challenge = true;
      await _mount(tester, plugin, textScale: 2);
      web.finishLastLoad();
      await _pump(tester, 650);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('website-document')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unknown account entry reads identity before requesting a login route',
    (tester) async {
      web.signedOutEntry = false;
      plugin.catalog = (core) async => {
        'data': {
          ..._catalog('Identity frame')['data'] as Map<String, dynamic>,
          'account': {
            'status': 'signedIn',
            'isOwnProfile': true,
            'profileUrl': 'https://hanime1.me/user/42',
            'name': 'Account',
          },
        },
      };
      await _mount(tester, plugin, nativePersonal: true, nativeAuth: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('我的'));
      await _pump(tester);
      expect(web.loads.last.path, '/');
      expect(web.loads.any((uri) => uri.path == '/login'), isFalse);
      web.finishLastLoad();
      await _pump(tester);
      expect(web.loads.last.path, '/user/42');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'account task isolates private reads and survives verification and expired login',
    (tester) async {
      web.profileHref = '/user/42';
      plugin.catalog = (core) async {
        final path = Uri.parse(core['pageUrl'] as String).path;
        return {
          'data': {
            ..._catalog('Account library')['data'] as Map<String, dynamic>,
            'account': path == '/login'
                ? {'status': 'signedOut'}
                : {
                    'status': 'signedIn',
                    'isOwnProfile': true,
                    'profileUrl': 'https://hanime1.me/user/42',
                    'settingsUrl': 'https://hanime1.me/user/42/edit',
                    'name': 'Account',
                    'links': [
                      {'title': 'Library', 'url': 'https://hanime1.me/user/42'},
                    ],
                  },
            if (path == '/login') 'auth': {'supported': true, 'mode': 'login'},
          },
        };
      };
      await _mount(tester, plugin, nativePersonal: true, nativeAuth: true);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('我的'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text(t.videoSiteAccount.title));
      await _pump(tester);
      expect(web.loads.last.path, '/user/42/edit');
      final callsBefore = plugin.calls.length;
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byType(NativeVideoAccountForm), findsOneWidget);
      expect(web.accountReads, greaterThan(0));
      expect(
        plugin.calls.length,
        callsBefore,
        reason: 'Account metadata bypasses getCatalog and its cache',
      );
      expect(
        jsonEncode(
          plugin.calls.map((call) => call.$2).toList(),
        ).contains('private@example.test'),
        isFalse,
      );
      final state = tester.state<NativeVideoAccountFormState>(
        find.byType(NativeVideoAccountForm),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Unsaved fixture',
      );
      web.challenge = true;
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      expect(find.byType(NativeVideoAccountForm), findsNothing);
      expect(
        find.byType(NativeVideoAccountForm, skipOffstage: false),
        findsOneWidget,
      );
      web.challenge = false;
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      expect(
        identical(tester.state(find.byType(NativeVideoAccountForm)), state),
        isTrue,
      );
      expect(find.text('Unsaved fixture'), findsOneWidget);
      tester
          .widget<NativeVideoAccountForm>(find.byType(NativeVideoAccountForm))
          .onRefresh();
      await _pump(tester);
      web.currentUrl = Uri.parse('https://hanime1.me/login');
      web.params.onLoadStart?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      web.params.onLoadStop?.call(
        web.wrapped,
        WebUri(web.currentUrl.toString()),
      );
      await _pump(tester);
      expect(find.byType(NativeVideoAuthForm), findsOneWidget);
      expect(
        identical(
          tester.state(
            find.byType(NativeVideoAccountForm, skipOffstage: false),
          ),
          state,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'My opens the actual site profile first without changing browsing preference',
    (tester) async {
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      web.profileHref = '/user/42';
      await tester.tap(find.text('我的'));
      await _pump(tester);
      expect(find.text(t.videoPlayback.watchHistory), findsNothing);
      expect(web.loads.last.path, '/user/42');
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byTooltip(t.videoPlayback.browserActions), findsOneWidget);
      await web.navigateWebsite(Uri.parse('https://hanime1.me/'));
      await _pump(tester);
      expect(find.text('Home card'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'native',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'wide search preserves cancellation, author mode, filters and return origin',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, plugin, filters: _filters);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byTooltip(t.settings.title), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('video-search.entry'))).width,
        greaterThan(220),
      );
      final menu = tester.widget<NativeVideoMenu>(find.byType(NativeVideoMenu));
      expect(menu.label, isEmpty);
      expect(menu.width, 44);
      await tester.tap(find.text('排行'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      final count = web.loads.length;
      await tester.tap(find.byKey(const ValueKey('video-search.entry')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-search.input')),
        'Discard',
      );
      await tester.tap(find.byTooltip(t.videoSearch.cancel));
      await tester.pumpAndSettle();
      expect(web.loads.length, count);
      await tester.tap(find.byKey(const ValueKey('video-search.entry')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-search.input')),
        'Creator',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, t.videoFilters.authors));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _pump(tester);
      expect(web.loads.last.queryParameters['query'], 'Creator');
      expect(web.loads.last.queryParameters['type'], 'artist');
      expect(web.loads.last.queryParameters['sort'], 'views');
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byTooltip(t.common.back));
      await _pump(tester);
      expect(
        tester.widget<VideoSearchEntry>(find.byType(VideoSearchEntry)).query,
        isEmpty,
      );
      expect(find.text('Rank card'), findsOneWidget);
      expect(
        web.loads.length,
        count + 1,
        reason: 'return reuses the prior catalog cache',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'artist search retains source count text without video metrics or invented profiles',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final works = Uri.parse(
        'https://hanime1.me/search?query=studio-alias&genre=3DCG',
      );
      plugin.catalog = (core) async {
        final page = Uri.parse(core['pageUrl'] as String);
        if (page.queryParameters['type'] != 'artist') {
          return _catalog('Home card');
        }
        return {
          'data': {
            'sections': [],
            'videos': [
              {
                'role': 'artist',
                'entityKey': '',
                'artistId': '',
                'profileId': '',
                'profileUrl': '',
                'nameSearchUrl': works.toString(),
                'pages': <String, String>{},
                'name': 'Public studio',
                'title': 'Public studio',
                'subtitle': '12 個影片',
                'pageUrl': works.toString(),
                'avatarUrl': '',
                'coverUrl': '',
                'followed': false,
                'identityState': 'unresolved',
                'kind': 'creatorSearch',
              },
            ],
            'paging': {
              'page': 1,
              'totalPages': 1,
              'previousUrl': '',
              'nextUrl': '',
            },
            'categories': [],
            'searchFilters': {},
            'title': '',
          },
        };
      };
      await _mount(tester, plugin, filters: _filters, textScale: 2);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('video-search.entry')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-search.input')),
        'Studio',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, t.videoFilters.authors));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _pump(tester);
      expect(web.loads.last.queryParameters['type'], 'artist');
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text('Public studio'), findsOneWidget);
      final facts = find.byType(VideoCardFacts);
      expect(
        find.descendant(of: facts, matching: find.text('12 個影片')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: facts, matching: find.byType(Text)),
        findsOneWidget,
        reason: 'the source work count is a byline, with no video statistics',
      );
      expect(
        tester.widget<VideoCardFacts>(facts).metadata.hasCardStatistics,
        false,
      );
      expect(find.text(t.videoMetadata.views(value: '12 個影片')), findsNothing);
      expect(find.byType(NativeVideoPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Public studio'));
      await _pump(tester);
      expect(web.loads.last, works);
      expect(web.loads.any((uri) => uri.path.startsWith('/user/')), false);
      expect(web.creatorResolutions, 0);
      expect(web.directoryReads, 0);
      expect(find.byType(NativeVideoPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'empty results retain removable conditions and clearing filters preserves the query',
    (tester) async {
      plugin.catalog = (_) async => {
        'data': {'videos': [], 'sections': []},
      };
      await _mount(tester, plugin, filters: _filters);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('排行'));
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('video-search.entry')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('video-search.input')),
        'Series',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _pump(tester);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byTooltip(t.videoFilters.removeFilter), findsNWidgets(2));
      await tester.tap(find.byTooltip(t.videoFilters.removeFilter).first);
      await _pump(tester);
      expect(web.loads.last.queryParameters['query'], 'Series');
      expect(web.loads.last.queryParameters['sort'], isNull);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byTooltip(t.videoFilters.removeFilter), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoFilters.removeFilter));
      await _pump(tester);
      expect(web.loads.last.queryParameters['query'], isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'quick filters commit one field and outside dismissal never selects a tab',
    (tester) async {
      await _mount(tester, plugin, filters: _filters);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('video-filter-open.genre')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video-filter.apply')), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, '3DCG'));
      await _pump(tester);
      expect(web.loads.last.queryParameters['genre'], '3DCG');
      web.finishLastLoad();
      await _pump(tester);
      final count = web.loads.length;
      await tester.tap(find.byKey(const ValueKey('video-filter-open.sort')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(30, 40));
      await tester.pumpAndSettle();
      expect(web.loads.length, count);
      await tester.tap(find.byKey(const ValueKey('video-filter-open.sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Views'));
      await _pump(tester);
      expect(web.loads.last.queryParameters['genre'], '3DCG');
      expect(web.loads.last.queryParameters['sort'], 'views');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'local history stays separate from the site profile and restores after playback',
    (tester) async {
      final record = VideoWatchRecord(
        watchUrl: Uri.parse('https://hanime1.me/watch?v=1'),
        title: 'Recent watch',
        position: const Duration(seconds: 20),
        duration: const Duration(minutes: 2),
        updatedAt: DateTime.utc(2026, 10, 22),
        completed: false,
      );
      SharedPreferences.setMockInitialValues({
        'breeze.video.history.v1.hanime-test': jsonEncode([record.toJson()]),
      });
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('我的'));
      web.finishLastLoad();
      await _pump(tester);
      expect(find.byTooltip(t.settings.title), findsNothing);
      await tester.tap(find.byType(NativeVideoMenu));
      await _pump(tester, 3);
      await tester.tap(find.text(t.videoCommunity.preferences).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoPlayback.localWatchHistory).last);
      await _pump(tester);
      expect(find.text(t.videoPlayback.watchHistory), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recent watch'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Recent watch'));
      await _pump(tester);
      expect(web.loads.last.queryParameters['v'], '1');
      web.finishLastLoad();
      await _pump(tester, 20);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      if (find.byType(NativeVideoPage).evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip(t.common.back).hitTestable().last);
      } else {
        await tester.pageBack();
      }
      await _pump(tester);
      expect(find.text(t.videoPlayback.watchHistory), findsOneWidget);
      expect(find.text('Recent watch'), findsOneWidget);
      await tester.tap(find.byTooltip(t.videoPlayback.clearWatchHistory));
      await _pump(tester);
      await tester.tap(find.widgetWithText(TextButton, t.common.cancel));
      await _pump(tester);
      expect(await VideoWatchHistory.read('hanime-test'), hasLength(1));
      await tester.tap(find.byTooltip(t.videoPlayback.clearWatchHistory));
      await _pump(tester);
      await tester.tap(find.widgetWithText(TextButton, t.common.delete));
      await _pump(tester);
      expect(await VideoWatchHistory.read('hanime-test'), isEmpty);
      expect(find.text(t.videoPlayback.historyEmpty), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'switching to native during website navigation never parses the old page',
    (tester) async {
      plugin.sourceValues['video.defaultMode'] = 'website';
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await _chooseMode(tester, t.videoPlayback.website);
      web.finishLastLoad();
      await _pump(tester);
      final ranking = Uri.parse('https://hanime1.me/search?sort=views');
      await web.navigateWebsite(ranking, finish: false);
      await _pump(tester);
      final previousLoads = web.loads.length;
      // The platform still reports the home document while ranking is loading.
      expect(web.currentUrl!.path, '/');
      await _chooseMode(tester, t.videoPlayback.nativeCatalog);
      expect(web.loads, hasLength(previousLoads));
      expect(plugin.calls.where((call) => call.$1 == 'catalog'), isEmpty);
      expect(find.text('Home card'), findsNothing);
      web.finishWebsiteNavigation(ranking);
      await _pump(tester);
      expect(find.text('Rank card'), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final sections in [false, true]) {
    testWidgets(
      '${sections ? 'section' : 'grid'} cards fit larger accessibility text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        plugin.catalog = (_) async {
          final data = _catalog(
            'A long descriptive title which needs two lines to display',
          );
          final card = (data['data']['videos'] as List).first as Map;
          card['subtitle'] = 'Author name';
          if (sections) {
            data['data']['sections'] = [
              {'title': 'Latest', 'videos': data['data']['videos']},
            ];
          }
          return data;
        };
        await _mount(tester, plugin, textScale: 2);
        web.finishLastLoad();
        await _pump(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('late parser result cannot replace a newly selected tab', (
    tester,
  ) async {
    final delayed = Completer<Map<String, dynamic>>();
    plugin.catalog = (core) => Uri.parse(core['pageUrl'] as String).path == '/'
        ? delayed.future
        : Future.value(_catalog('New ranking'));
    await _mount(tester, plugin);
    web.finishLastLoad();
    await _pump(tester);
    await tester.tap(find.text('排行'));
    await _pump(tester);
    web.finishLastLoad();
    await _pump(tester);
    delayed.complete(_catalog('Old home'));
    await _pump(tester);
    expect(find.text('New ranking'), findsOneWidget);
    expect(find.text('Old home'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final stalledDom in [false, true]) {
    testWidgets(
      'stalled ${stalledDom ? 'DOM' : 'plugin'} has a bounded website fallback',
      (tester) async {
        web.hangSnapshot = stalledDom;
        if (!stalledDom) {
          plugin.catalog = (_) => Completer<Map<String, dynamic>>().future;
        }
        await _mount(tester, plugin);
        web.finishLastLoad();
        await _pump(tester, 200);
        expect(find.text(t.videoPlayback.catalogFallback), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(
          find.widgetWithText(OutlinedButton, t.videoPlayback.website),
        );
        await _pump(tester);
        expect(web.loads.last, Uri.parse('https://hanime1.me/'));
        web.finishLastLoad();
        await _pump(tester);
        expect(find.text(t.videoPlayback.catalogFallback), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w is NativeVideoMenu && w.selected == 'website',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'card, episode, tag and website actions keep the correct video identity',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      expect(web.loads.last.queryParameters['v'], '1');
      web.finishLastLoad();
      await _pump(tester, 20);
      expect(find.byType(NativeVideoPage), findsOneWidget);
      expect(find.text('Detail 1'), findsOneWidget);
      await tester.ensureVisible(find.text('Episode 2'));
      await tester.tap(find.text('Episode 2'));
      await _pump(tester);
      expect(web.loads.last.queryParameters['v'], '2');
      web.finishLastLoad();
      await _pump(tester, 20);
      expect(find.text('Detail 2'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'Sample tag'));
      await _pump(tester);
      final tagWeb = web.documents.last;
      expect(tagWeb.loads.last.queryParameters['query'], 'Sample tag');
      tagWeb.finishLastLoad();
      await _pump(tester);
      await tester.tap(find.text('Home card'));
      await _pump(tester);
      tagWeb.finishLastLoad();
      await _pump(tester, 20);
      await tester.tap(
        find.widgetWithText(TextButton, t.videoPlayback.backToWeb),
      );
      await _pump(tester);
      expect(tagWeb.loads.last.queryParameters['v'], '1');
      tagWeb.finishLastLoad();
      await _pump(tester);
      expect(find.byType(NativeVideoPage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is NativeVideoMenu && w.selected == 'website',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final retry in [false, true]) {
    testWidgets(
      'separate verification window pauses host observation and return retry=$retry is explicit',
      (tester) async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          ),
        );
        web.challenge = true;
        web.verificationWindowResult = Completer<bool>();
        await _mount(tester, plugin);
        web.finishLastLoad();
        await _pump(tester);
        final loads = web.loads.length;
        expect(find.byType(VideoVerificationGate), findsOneWidget);
        await tester.tap(
          find.widgetWithText(FilledButton, t.videoPlayback.verificationWindow),
        );
        await _pump(tester);
        expect(web.verificationWindows, [Uri.parse('https://hanime1.me/')]);
        final reads = web.stateReads;
        for (var tick = 0; tick < 4; tick++) {
          await tester.pump(const Duration(seconds: 5));
          await tester.pump();
        }
        expect(
          web.stateReads,
          reads,
          reason: 'The original browser is not probed during the native window',
        );
        expect(web.loads.length, loads);
        web.verificationWindowResult!.complete(retry);
        await _pump(tester, 3);
        expect(web.loads.length, loads + (retry ? 1 : 0));
        if (retry) expect(web.loads.last, Uri.parse('https://hanime1.me/'));
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(
          web.stateReads,
          greaterThan(reads),
          reason: 'Observation resumes after the user returns',
        );
        expect(web.loads.length, loads + (retry ? 1 : 0));
        expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
        expect(
          web.creations,
          1,
          reason: 'The original browser and source state remain intact',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
  testWidgets(
    'verification observation keeps an opened UIKit actions menu usable',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('breeze.video.control.99001');
      var dismissals = 0;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dismissMenu') dismissals++;
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        messenger.setMockMethodCallHandler(channel, null);
      });
      web.challenge = true;
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      expect(find.text(t.videoPlayback.verificationTitle), findsOneWidget);
      final menuFinder = find.byWidgetPredicate(
        (widget) =>
            widget is NativeVideoMenu &&
            widget.tooltip == t.videoPlayback.verificationActions,
      );
      final menu = tester.widget<NativeVideoMenu>(menuFinder);
      final platformView = tester.widget<UiKitView>(
        find.descendant(of: menuFinder, matching: find.byType(UiKitView)),
      );
      // Wire the real control's channel at the platform boundary. This tests
      // the host's actual dismiss command, not just the menu widget's presence.
      platformView.onPlatformViewCreated!(99001);
      await tester.pump();
      menu.onOpened!();
      await tester.pump();
      final reads = web.stateReads;
      final loads = web.loads.length;
      for (var tick = 0; tick < 4; tick++) {
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
      expect(web.stateReads, greaterThan(reads));
      expect(web.loads.length, loads);
      expect(
        dismissals,
        0,
        reason: 'Read-only verification polling must not dismiss the user menu',
      );
      web.params.onLoadStart!(web.wrapped, WebUri('https://hanime1.me/'));
      await tester.pump();
      expect(
        dismissals,
        1,
        reason: 'A real main-document reload still dismisses the open menu',
      );
      menu.onClosed!();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'UIKit catalog menu owns dismissal without a competing Flutter barrier',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await _mount(tester, plugin);
      web.finishLastLoad();
      await _pump(tester);
      final menu = tester.widget<NativeVideoMenu>(find.byType(NativeVideoMenu));
      expect(menu.controller!.ownsBarrier, true);
      for (var n = 0; n < 10; n++) {
        menu.onOpened!();
        await _pump(tester);
        expect(
          find.byKey(const ValueKey('catalog-native-menu-barrier')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('video-host-menu')), findsNothing);
        menu.onClosed!();
        await _pump(tester);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
