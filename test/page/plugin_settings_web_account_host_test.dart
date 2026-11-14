import 'dart:io';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/setting/common/plugin_user_info_card.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/native_video_auth_form.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';

final _home = Uri.parse('https://site.example/');
const _declaredLoginSource = 'vendor-declared-web-login';
const _declaredLoginLabel = 'Vendor web login';

class _Api extends RustLibApi {
  int imageCalls = 0;
  bool declaredWebAccount = false;
  String? webLoginFunction;
  bool webLoginField = false;
  bool webLoginChangesSession = false;
  Completer<Map<String, dynamic>>? webLoginResponse;
  final webLoginCalls = <String>[];

  Map<String, dynamic> get _webLoginDeclaration => {
    'fnPath': webLoginFunction,
    if (webLoginChangesSession) 'sessionChange': true,
  };

  @override Future<Uint8List> crateApiQjsQjsFetchImage({required String runtimeName, required String taskGroupKey, required bool isOnce, String? bundleJs, String? bundleUrl, required String fnPath, required String argsJson}) async {imageCalls++;throw StateError('Omo does not declare fetchImageBytes');}
  @override Future<bool> crateApiQjsIsQjsRuntimeInitialized({required String name}) async=>true;
  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async => true;
  @override Future<String> crateApiQjsQjsCurrentBundle({required String runtimeName}) async=>jsonEncode('cold-settings');
  @override Future<Uint8List> crateApiQjsQjsTaskCall({required String runtimeName,required String taskGroupKey,
    required bool isOnce,String? bundleJs,String? bundleUrl,required String fnPath,required String argsJson}) async {
    if (fnPath == webLoginFunction) {
      webLoginCalls.add(fnPath);
      final value = await webLoginResponse!.future;
      return Uint8List.fromList(utf8.encode(jsonEncode(value)));
    }
    final value = switch(fnPath) {
      'init' => {},
      'getSettingsBundle' => {
        'data':{'mediaType':'video','canLogin':false,'canShowUserInfo':false,'values':{},
          if (declaredWebAccount) 'accountSync':{'version':1,'origin':_home.origin,'readFn':'read','saveFn':'save','forgetFn':'forget'}},
        if (webLoginFunction != null && webLoginField)
          'scheme': {
            'sections': [
              {
                'title': 'Vendor settings',
                'fields': [
                  {
                    ..._webLoginDeclaration,
                    'key': 'vendor.signIn',
                    'label': _declaredLoginLabel,
                    'kind': 'switch',
                    'persist': false,
                  },
                ],
              },
            ],
          },
      },
      'getCapabilitiesBundle' => {
        'scheme': {
          'actions': [
            if (webLoginFunction != null && !webLoginField)
              {..._webLoginDeclaration, 'title': _declaredLoginLabel},
          ],
        },
      },
      _ => throw StateError('No plugin API identity: $fnPath'),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(value)));
  }
  @override dynamic noSuchMethod(Invocation invocation)=>throw StateError('Unexpected native call ${invocation.memberName}');
}
class _Web extends InAppWebViewPlatform {
  late PlatformInAppWebViewWidgetCreationParams params;
  late final controller = _Controller(this);
  dynamic get wrapped => params.controllerFromPlatform!(controller);
  int reads = 0, creations = 0, disposals = 0;
  bool nativeLoginSupported = false;
  final loads = <Uri>[];
  List<Cookie>? restorationCookies;
  final cookieWriteGenerations = <int>[];
  Future<dynamic>? next;
  dynamic reply = {'kind':'account','account':{'id':'42','name':'Cold actual member','group':'Member','points':12}};
  @override PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(PlatformInAppWebViewWidgetCreationParams params) => _Widget(params,this);
  @override PlatformCookieManager createPlatformCookieManager(PlatformCookieManagerCreationParams params) => _CookieManager(params);
}
// Registration needs the platform adapter to exist; merely reading identity
// must not enumerate or mutate account cookies when no restore is queued.
class _CookieManager extends PlatformCookieManager {
  _CookieManager(super.params):super.implementation();

  // CookieManager.instance() outlives each individual fixture's WebView.
  _Web get host => InAppWebViewPlatform.instance as _Web;
  @override Future<List<Cookie>> getCookies({required WebUri url,
    PlatformInAppWebViewController? iosBelow11WebViewController,
    PlatformInAppWebViewController? webViewController}) async =>
      host.restorationCookies ??
      (throw StateError('Cold identity reads must not capture cookies'));

  @override
  Future<bool> setCookie({
    required WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    int? maxAge,
    bool? isSecure,
    bool? isHttpOnly,
    HTTPCookieSameSitePolicy? sameSite,
    PlatformInAppWebViewController? iosBelow11WebViewController,
    PlatformInAppWebViewController? webViewController,
  }) async {
    final cookies = host.restorationCookies;
    if (cookies == null) throw StateError('No account restore queued');
    host.cookieWriteGenerations.add(
      pluginSessionWriteFence.generation(omoNetworkSource),
    );
    cookies.add(Cookie(
      name: name,
      value: value,
      path: path,
      domain: domain,
      expiresDate: expiresDate,
      isSecure: isSecure,
      isHttpOnly: isHttpOnly,
    ));
    return true;
  }
}
class _Widget extends PlatformInAppWebViewWidget {
  _Widget(super.params,this.host):super.implementation();
  final _Web host;
  @override Widget build(BuildContext context) {host.params=params;return _Document(host:host);}
  @override T controllerFromPlatform<T>(PlatformInAppWebViewController controller)=>params.controllerFromPlatform!(controller) as T;
  @override void dispose(){host.disposals++;}
}
class _Document extends StatefulWidget {
  const _Document({required this.host});final _Web host;
  @override State<_Document> createState()=>_DocumentState();
}
class _DocumentState extends State<_Document> {
  @override void initState(){super.initState();widget.host.creations++;
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)widget.host.params.onWebViewCreated?.call(widget.host.wrapped);});}
  @override Widget build(BuildContext context)=>const SizedBox();
}
class _Controller extends PlatformInAppWebViewController {
  _Controller(this.host):super.implementation(const PlatformInAppWebViewControllerCreationParams(id:'cold-account'));
  final _Web host;
  @override Future<void> loadUrl({required URLRequest urlRequest,Uri? iosAllowingReadAccessTo,WebUri? allowingReadAccessTo}) async {
    final uri=Uri.parse(urlRequest.url.toString());host.loads.add(uri);
    host.params.onLoadStop?.call(host.wrapped,WebUri(uri.toString()));
  }
  @override Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({required String functionBody,
    Map<String,dynamic> arguments=const {},ContentWorld? contentWorld}) async {
    if (functionBody.contains('return {supported:false}')) {
      return CallAsyncJavaScriptResult(value: {'supported': host.nativeLoginSupported});
    }
    expect(functionBody,contains('("account",{"includeProfile":true},'));
    host.reads++;
    return CallAsyncJavaScriptResult(value:await (host.next??Future.value(host.reply)));
  }
}
class _NoCookies implements VideoAccountCookies {
  @override Future<List<Map<String,dynamic>>> read(Uri origin) async=>throw StateError('No cookie capture');
  @override Future<void> set(Uri origin,Map<String,dynamic> cookie) async=>throw StateError('No login/restore');
  @override Future<void> delete(Uri origin,Map<String,dynamic> cookie) async=>throw StateError('No logout');
}
class _PortraitImages extends Fake implements HttpClient {
  final requests = <_PortraitRequest>[];
  final bytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==');
  @override Future<HttpClientRequest> getUrl(Uri uri) async {
    final request = _PortraitRequest(uri, bytes); requests.add(request); return request;
  }
  @override void close({bool force=false}) {}
}
class _PortraitRequest extends Fake implements HttpClientRequest {
  _PortraitRequest(this.uri,this.bytes);
  final Uri uri; final Uint8List bytes;
  @override final _PortraitHeaders headers = _PortraitHeaders();
  @override Future<HttpClientResponse> close() async => _PortraitResponse(bytes);
}
class _PortraitHeaders extends Fake implements HttpHeaders {
  final values=<String,Object>{};
  @override void set(String name,Object value,{bool preserveHeaderCase=false}) {values[name.toLowerCase()]=value;}
  @override void add(String name,Object value,{bool preserveHeaderCase=false}) {values[name.toLowerCase()]=value;}
}
class _PortraitResponse extends Stream<List<int>> implements HttpClientResponse {
  _PortraitResponse(this.bytes); final Uint8List bytes;
  @override int get statusCode=>200;
  @override int get contentLength=>bytes.length;
  @override HttpClientResponseCompressionState get compressionState=>HttpClientResponseCompressionState.notCompressed;
  @override StreamSubscription<List<int>> listen(void Function(List<int>)? onData,{Function? onError,void Function()? onDone,bool? cancelOnError}) =>
    Stream<List<int>>.value(bytes).listen(onData,onError:onError,onDone:onDone,cancelOnError:cancelOnError);
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final api=_Api();
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityStatus = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  final channels=<MethodChannel>[];
  late InAppWebViewPlatform? previous;
  late _Web web;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();RustLib.initMock(api:api);
    await PluginRegistryService.I.upsert(PluginInfo(uuid:omoNetworkSource,version:'cold-settings',originScript:'fixture',
      insertedAt:DateTime.utc(2026),updatedAt:DateTime.utc(2026),isEnabled:true,isDeleted:false,lastLoadSuccess:true,debug:false,
      getInfoJson:jsonEncode({'name':'Omo','function':[{'action':{'type':'openVideoLibrary','payload':{'url':_home.toString()}}}]})));
    await PluginRegistryService.I.upsert(PluginInfo(
      uuid: _declaredLoginSource,
      version: 'cold-settings',
      originScript: 'vendor fixture',
      insertedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      isEnabled: true,
      isDeleted: false,
      lastLoadSuccess: true,
      debug: false,
    ));
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp((){
    SharedPreferences.setMockInitialValues({});api.imageCalls=0;api.declaredWebAccount=false;pluginSessionWriteFence.advance(omoNetworkSource);
    api.webLoginFunction = null;
    api.webLoginField = false;
    api.webLoginChangesSession = false;
    api.webLoginResponse = null;
    api.webLoginCalls.clear();
    previous=InAppWebViewPlatform.instance;web=_Web();InAppWebViewPlatform.instance=web;
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(connectivityStatus, (_) async => null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call) async {
      if(call.method=='create'){final args=call.arguments as Map;final channel=MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);messenger.setMockMethodCallHandler(channel,(_) async=>null);}return null;
    });
  });
  tearDown((){
    if (previous != null) InAppWebViewPlatform.instance=previous;
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityStatus, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);
    for(final channel in channels)messenger.setMockMethodCallHandler(channel,null);channels.clear();
  });
  Future<void> pullSettingsRefresh(WidgetTester tester) async {
    expect(find.byTooltip(t.common.refresh), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('plugin-settings-sections')),
      const Offset(0, 350),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> mount(WidgetTester tester, {bool settle = true, String source = omoNetworkSource}) async {
    final registry=PluginRegistryCubit(),style=ValueNotifier('breeze');addTearDown(registry.close);addTearDown(style.dispose);
    await tester.pumpWidget(BlocProvider.value(value:registry,child:AppInterfaceStyleScope(style:style,
      child:MaterialApp(home:VideoNetworkScope(source:source,network:Future.value(null),
        child:PluginSettingsPage(from:source,pluginUuid:source,
          pluginRuntimeName:source,pluginDisplayName:'Omo'))))));
    for (var i=0; i<8; i++) { await tester.pump(const Duration(milliseconds:10)); }
    if (settle) await tester.pumpAndSettle();
  }

  for (final mode in ['stale action', 'stale field', 'current read', 'declared change', 'standard change']) {
    testWidgets('declared web login handles $mode', (tester) async {
      const source = _declaredLoginSource;
      final response = Completer<Map<String, dynamic>>();
      api.webLoginResponse = response;
      api.webLoginField = mode == 'stale field';
      api.webLoginFunction = mode == 'standard change'
          ? 'loginWithPassword'
          : 'vendor.openLogin';
      api.webLoginChangesSession = mode == 'declared change';

      final routeCalls = <List<String>>[];
      final registry = PluginRegistryCubit();
      final style = ValueNotifier('breeze');
      final router = RootStackRouter.build(routes: [
        NamedRouteDef(
          name: 'DeclaredLoginSettingsFixture',
          path: '/',
          initial: true,
          builder: (_, _) => const PluginSettingsPage(
            from: source,
            pluginUuid: source,
            pluginRuntimeName: source,
            pluginDisplayName: 'Vendor',
          ),
        ),
        NamedRouteDef(
          name: WebViewRoute.name,
          path: '/web-login',
          builder: (_, data) {
            routeCalls.add(data.argsAs<WebViewRouteArgs>().info);
            return const Scaffold(body: Text('Vendor login destination'));
          },
        ),
      ]);
      addTearDown(router.dispose);
      addTearDown(registry.close);
      addTearDown(style.dispose);
      await tester.pumpWidget(BlocProvider.value(
        value: registry,
        child: AppInterfaceStyleScope(
          style: style,
          child: MaterialApp.router(routerConfig: router.config()),
        ),
      ));
      await tester.pumpAndSettle();
      final generation = pluginSessionWriteFence.generation(source);
      await tester.tap(find.text(_declaredLoginLabel));
      await tester.pump();
      expect(api.webLoginCalls, [api.webLoginFunction]);

      final stale = mode.startsWith('stale');
      if (stale) await runPluginSessionChange(source, () async {});
      const title = 'Open vendor login';
      const url = 'https://vendor.example/sign-in';
      response.complete({
        'openTitle': title,
        'openUrl': url,
        'setCookieFnPath': 'vendor.setCookie',
      });
      await tester.pumpAndSettle();

      expect(routeCalls, stale ? isEmpty : [[title, url]]);
      expect(find.text('Vendor login destination'), stale ? findsNothing : findsOneWidget);
      expect(
        pluginSessionWriteFence.generation(source),
        generation + (mode == 'current read' ? 0 : 2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('a signed-out video settings account opens its formal sign-in directly',
      (tester) async {
    web.reply = {'kind': 'signedOut'};
    web.nativeLoginSupported = true;
    replaceActivePluginAccount(omoNetworkSource, {
      'account.credentials': {
        'version': 1,
        'deleted': false,
        'origin': _home.origin,
        'account': 'unselected-video-fixture',
        'password': 'unselected-fixture-password',
      },
    });
    addTearDown(() => replaceActivePluginAccount(omoNetworkSource, {}));
    await mount(tester);
    final signIn = find.byKey(const ValueKey('plugin-settings-direct-login'));
    expect(signIn, findsOneWidget);
    expect(find.text(t.plugin.switchAccount), findsOneWidget);
    expect(web.loads, [_home]);
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    final route = tester.widget<OmoSiteWebPage>(find.byType(OmoSiteWebPage));
    expect(route.url, _home.resolve('/user/login'));
    expect(route.recoveryUsername, '');
    expect(web.loads.last, route.url);
    final form = tester.widget<NativeVideoAuthForm>(find.byType(NativeVideoAuthForm));
    expect(form.credentials, isNull);
    expect(
      tester.widgetList<EditableText>(find.byType(EditableText))
          .map((field) => field.controller.text),
      everyElement(isEmpty),
    );
    Navigator.of(tester.element(find.byType(OmoSiteWebPage))).pop();
    await tester.pumpAndSettle();
    expect(signIn, findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final mode in ['owned', 'borrowed', 'signed-in']) {
    final borrow = mode == 'borrowed', signedIn = mode == 'signed-in';
    testWidgets('formal login ${signedIn ? 'reads an already authenticated document before requiring a login form' : borrow ? 'borrows the same-source visit' : 'creates an owned source visit without an inherited scope'}', (tester) async {
      if (!signedIn) web.reply = {'kind': 'signedOut'};
      const channel = MethodChannel('breeze.video.network');
      final opened = <Map<dynamic, dynamic>>[], closed = <String>[];
      SourceNetworkPolicies.initialize(() => const ProxySettingState());
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'supported') return true;
        final args = call.arguments as Map;
        if (call.method == 'open') {
          opened.add(args);
          return 'formal-source-visit';
        }
        if (call.method == 'close') closed.add(args['context'] as String);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final borrowed = borrow ? OmoNetworkContext('borrowed-source-visit', source: omoNetworkSource) : null;
      addTearDown(() async { await borrowed?.close(); });
      final site = OmoSiteClient(home: _home, request: (_, _) async => throw StateError('The login route must read its own browser, not a detached client'));
      addTearDown(site.dispose);
      final nav = GlobalKey<NavigatorState>();
      Future<void>? visit;
      Widget entry = Builder(builder: (context) => TextButton(
        onPressed: () { visit = openOmoSitePage(context, site, title: 'Login', path: '/user/login', credentialSource: omoNetworkSource); },
        child: const Text('Open source login'),
      ));
      if (borrowed != null) entry = VideoNetworkScope(source: omoNetworkSource, network: Future.value(borrowed), child: entry);
      await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: Scaffold(body: entry)));
      await tester.tap(find.text('Open source login'));
      await tester.pumpAndSettle();
      if (signedIn) {
        await visit;
        expect(site.account?.id, '42', reason: 'the actual same-browser identity read wins over the unavailable login form');
        expect(web.reads, 1);
        expect(web.loads, [_home.resolve('/user/login')]);
        expect(find.byType(OmoSiteWebPage), findsNothing);
        expect(find.text('Open source login'), findsOneWidget);
        expect(closed, ['formal-source-visit']);
        expect(tester.takeException(), isNull);
        return;
      }
      final browser = tester.widget<VideoSiteBrowser>(find.byType(VideoSiteBrowser, skipOffstage: false));
      expect(browser.source, omoNetworkSource);
      expect(browser.networkContext, borrow ? borrowed!.token : 'formal-source-visit');
      expect(web.loads, [_home.resolve('/user/login')]);
      expect(opened, borrow ? isEmpty : hasLength(1));
      if (!borrow) {
        expect(opened.single['source'], omoNetworkSource);
        expect(opened.single['siteOrigins'], [_home.origin]);
      }
      expect(closed, isEmpty);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await visit;
      expect(closed, borrow ? isEmpty : ['formal-source-visit'], reason: 'a login route closes only the source visit it owns');
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
  testWidgets('direct cold formal settings reads its own source store despite canShowUserInfo false',(tester) async {
    expect(PluginAccountIdentities.current(omoNetworkSource),isNull);
    await mount(tester);
    expect(web.creations,1);expect(web.loads,[_home]);expect(web.reads,1);
    expect(PluginAccountSyncCoordinator.instance.hasProfileAccess(omoNetworkSource),isTrue,
      reason:'the cold same-store reader also supports explicit saved-account switching');
    expect(tester.widget<VideoSiteBrowser>(find.byType(VideoSiteBrowser,skipOffstage:false)).source,omoNetworkSource);
    expect(find.text('Cold actual member'),findsOneWidget);
    expect(find.text('${t.omoAccount.points}: 12'),findsOneWidget);
    expect(tester.widget<PluginUserInfoCard>(find.byType(PluginUserInfoCard)).verified,isTrue);
    web.reply={'kind':'permissionDenied'};
    await pullSettingsRefresh(tester);await tester.pumpAndSettle();
    expect(find.text('Cold actual member'),findsOneWidget);expect(find.text(t.plugin.userInfoLoadFailed),findsOneWidget);
    web.next=Completer<dynamic>().future;
    await pullSettingsRefresh(tester);await tester.pump();
    await tester.pump(const Duration(seconds:21));await tester.pumpAndSettle();
    expect(find.text('Cold actual member'),findsOneWidget);
    expect(tester.element(find.byType(PluginSettingsContent)).read<PluginSettingsCubit>().state.loadingUserInfo,isFalse);
    await tester.pumpWidget(const SizedBox());await tester.pump();
    expect(web.disposals,1);
    expect(PluginAccountSyncCoordinator.instance.hasProfileAccess(omoNetworkSource),isFalse);
    expect(tester.takeException(),isNull);
  },variant:TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets('existing source reader is freshly queried without creating another browser',(tester) async {
    var reads=0;
    final coordinator=PluginAccountSyncCoordinator.instance;
    final lease=await coordinator.registerStoredSession(source:omoNetworkSource,origin:_home,cookies:_NoCookies(),
      authenticated:() async=>true,identity:() async {reads++;return const PluginAccountAuthentication(serverIdentity:'warm-42',label:'Fresh live reader');});
    addTearDown(()=>coordinator.unregister(omoNetworkSource,lease));
    PluginAccountIdentities.confirm(omoNetworkSource,const PluginAccountAuthentication(serverIdentity:'warm-42',label:'Earlier receipt'),
      generation:pluginSessionWriteFence.generation(omoNetworkSource));
    await mount(tester);
    expect(reads,1);expect(find.text('Fresh live reader'),findsOneWidget);expect(find.text('Earlier receipt'),findsNothing);
    expect(web.creations,0);expect(web.reads,0);expect(tester.takeException(),isNull);
    coordinator.unregister(omoNetworkSource,lease);
    await pullSettingsRefresh(tester);await tester.pumpAndSettle();
    expect(web.creations,1);expect(web.reads,1);
    expect(find.text('Cold actual member'),findsOneWidget);
    expect(find.text('Fresh live reader'),findsNothing);
    coordinator.unregister(omoNetworkSource,lease);
    expect(coordinator.hasProfileAccess(omoNetworkSource),isTrue,
      reason:'a late old-owner close cannot retire the cold replacement lease');
  },variant:TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets(
    'cold settings accepts its restored owner and fences an external switch',
    (tester) async {
      const source = omoNetworkSource;
      final setting = objectbox.userSettingBox.get(1)!;
      final previous = setting.globalSetting;
      final previousBackup = readHostPluginConfiguration(source)['account.backup'];
      addTearDown(() async {
        objectbox.userSettingBox.put(setting..globalSetting = previous);
        await savePluginConfigValue(source, 'account.backup', previousBackup);
      });
      setting.globalSetting = previous.copyWith(
        syncSetting: previous.syncSetting.copyWith(syncPlugins: true),
      );
      objectbox.userSettingBox.put(setting);
      await savePluginConfigValue(source, 'account.backup', {
        'version': 1,
        'origin': _home.origin,
        'cookies': [
          {
            'name': 'session',
            'value': 'restored-fixture-session',
            'domain': _home.host,
            'path': '/',
            'httpOnly': true,
            'secure': true,
          },
        ],
      });
      await PluginAccountSyncCoordinator.instance.markRestorePending({source});
      web.restorationCookies = [];
      final initial = pluginSessionWriteFence.generation(source);

      await mount(tester);
      expect(web.cookieWriteGenerations, [initial + 1]);
      expect(pluginSessionWriteFence.generation(source), initial + 2);
      expect(web.reads, 1);
      expect(find.text('Cold actual member'), findsOneWidget);
      expect(PluginAccountIdentities.current(source)?.serverIdentity, '42');

      final delayed = Completer<dynamic>();
      web.next = delayed.future;
      await pullSettingsRefresh(tester);
      await tester.pump();
      expect(web.reads, 2);
      final changing = pluginSessionWriteFence.beginSessionChange(source);
      delayed.complete({
        'kind': 'account',
        'account': {'id': '42', 'name': 'Old account reply'},
      });
      await tester.pump();
      pluginSessionWriteFence.seal(source, changing);
      await tester.pumpAndSettle();
      expect(find.text('Old account reply'), findsNothing);
      expect(PluginAccountIdentities.current(source), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('leaving settings fences a delayed cold account response',(tester) async {
    final gate=Completer<dynamic>();web.next=gate.future;
    await mount(tester, settle:false);
    expect(web.reads,1);
    await tester.pumpWidget(const SizedBox());await tester.pump();
    gate.complete({'kind':'account','account':{'id':'old','name':'Late old account'}});
    await tester.pump();
    expect(PluginAccountIdentities.current(omoNetworkSource),isNull);
    expect(web.disposals,1);expect(tester.takeException(),isNull);
  },variant:TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets('formal Omo portrait uses source image transport and refreshes unchanged URL without plugin image capability', (tester) async {
    final images=_PortraitImages();
    web.reply={'kind':'account','account':{'id':'4242','name':'Actual portrait member','avatar':'https://images.example/formal-avatar.png'}};
    await HttpOverrides.runZoned(() async {
      await mount(tester);
      for(var i=0;i<8;i++) {
        await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:20)));
        await tester.pump();
      }
      expect(find.byType(PluginUserInfoCard),findsOneWidget);
      final thumbnail=tester.widget<VideoThumbnail>(find.byType(VideoThumbnail));
      expect(thumbnail.source,omoNetworkSource);expect(thumbnail.referrer,_home.replace(path:''));
      expect(thumbnail.refreshHealthyOnTokenChange,isTrue);
      expect(tester.widget<CollectionCoverPrivacyScope>(find.descendant(of:find.byType(PluginUserInfoCard),
        matching:find.byType(CollectionCoverPrivacyScope))).enabled,isFalse);
      expect(images.requests,hasLength(1));
      expect(images.requests.single.headers.values['referer'],_home.replace(path:'').toString());
      expect(tester.widget<RawImage>(find.byType(RawImage)).image,isNotNull);
      expect(api.imageCalls,0,reason:'the source has no fetchImageBytes API');
      await pullSettingsRefresh(tester);await tester.pumpAndSettle();
      for(var i=0;i<8;i++) {
        await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:20)));
        await tester.pump();
      }
      expect(images.requests,hasLength(2));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image,isNotNull);
      expect(api.imageCalls,0);expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());await tester.pump();
    },createHttpClient:(_)=>images);
  },variant:TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('declared Hanime Web account uses its confirmed origin image transport without inventing an image API', (tester) async {
    const source='1e600cff-8ebe-4517-8aa4-6678aec46424';
    api.declaredWebAccount=true;
    pluginSessionWriteFence.advance(source);
    final coordinator=PluginAccountSyncCoordinator.instance;
    final lease=await coordinator.registerStoredSession(source:source,origin:_home,cookies:_NoCookies(),
      authenticated:() async=>true,identity:() async=>PluginAccountAuthentication(serverIdentity:'88',
        label:'Fresh Hanime member',avatarUrl:'https://images.example/hanime-account.png',origin:_home.origin));
    addTearDown(()=>coordinator.unregister(source,lease));
    final images=_PortraitImages();
    await HttpOverrides.runZoned(() async {
      await mount(tester,source:source);
      for(var i=0;i<8;i++) {
        await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:20)));
        await tester.pump();
      }
      expect(find.text('Fresh Hanime member'),findsOneWidget);
      expect(tester.widget<VideoThumbnail>(find.byType(VideoThumbnail)).source,source);
      expect(images.requests,hasLength(1));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image,isNotNull);
      expect(api.imageCalls,0);expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());await tester.pump();
    },createHttpClient:(_)=>images);
  },variant:TargetPlatformVariant.only(TargetPlatform.iOS));

}
