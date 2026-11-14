import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/omofun_account_details_page.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/setting/common/plugin_user_info_card.dart';
import 'package:zephyr/page/video/omo_network.dart' show omoNetworkSource;
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';
class _Api extends RustLibApi {
  final calls=<String>[];
  @override Future<bool> crateApiQjsIsQjsRuntimeInitialized({required String name}) async=>true;
  @override Future<String> crateApiQjsQjsCurrentBundle({required String runtimeName}) async=>jsonEncode('identity-host');
  @override Future<Uint8List> crateApiQjsQjsTaskCall({required String runtimeName,required String taskGroupKey,required bool isOnce,String? bundleJs,String? bundleUrl,required String fnPath,required String argsJson}) async {
    calls.add(fnPath);
    final result=switch(fnPath) {
      'init'=>{'ok':true},
      'getSettingsBundle'=>{'data':{'mediaType':'video','canLogin':false,'canShowUserInfo':false,'values':{}}},
      'getCapabilitiesBundle'=>{'scheme':{'actions':[]}},
      _=>throw StateError('Unexpected identity host operation $fnPath'),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(result)));
  }
  @override dynamic noSuchMethod(Invocation invocation)=>throw StateError('Unexpected native API ${invocation.memberName}');
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();final api=_Api();
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,channels=<MethodChannel>[];
  final home=Uri.parse('https://www.omofuna.com');
  setUpAll(() async {SharedPreferences.setMockInitialValues({});await TestObjectBoxHelper.setUpTestObjectBox();RustLib.initMock(api:api);});
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});api.calls.clear();pluginSessionWriteFence.advance(omoNetworkSource);
    replaceActivePluginAccount(omoNetworkSource,{'account.backup':{'version':1,'origin':home.origin,'cookies':[
      {'name':'session','value':'synthetic-current','domain':home.host,'path':'/','secure':true,'httpOnly':true,'expires':null}]}});
    await PluginAccountProfiles.rememberCurrent(omoNetworkSource,identity:'42',label:'Actual member',serverIdentity:'42',origin:home.origin,kind:'web',select:true);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,(call) async {
      if(call.method=='create') {final args=call.arguments as Map;final channel=MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);messenger.setMockMethodCallHandler(channel,(_) async=>null);}
      return null;
    });
  });
  tearDown(() {messenger.setMockMethodCallHandler(SystemChannels.platform_views,null);
    for(final channel in channels)messenger.setMockMethodCallHandler(channel,null);channels.clear();});
  for(final style in ['system','breeze']) {
    testWidgets('Omo $style actual My identity is shared by formal settings and saved accounts, with return preserved',(tester) async {
      tester.view.physicalSize=const Size(390,1100);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final preference=ValueNotifier(style),registry=PluginRegistryCubit();
      final site=OmoSiteClient(home:home,request:(operation,_) async=>operation=='account'
        ? {'kind':'account','account':{'id':'42','name':'Actual member','group':'Member'}}
        : {'kind':'history','rawCount':0,'items':[],'hasMore':false});
      addTearDown(preference.dispose);addTearDown(registry.close);addTearDown(site.dispose);
      await tester.pumpWidget(BlocProvider.value(value:registry,child:AppInterfaceStyleScope(style:preference,
        child:MaterialApp(home:VideoNetworkScope(source:omoNetworkSource,network:Future.value(null),
          child:Scaffold(body:OmoAccountPage(source:omoNetworkSource,client:site,active:true,onLocalHistory:(){})))))));
      await tester.pumpAndSettle();expect(find.text('Actual member'),findsOneWidget);
      final avatar=find.byType(OmoAccountAvatar);
      expect(tester.widget<OmoAccountAvatar>(avatar).source,omoNetworkSource);
      expect(tester.widget<OmoAccountAvatar>(avatar).size,52);
      expect(tester.widget<VideoThumbnail>(find.descendant(of:avatar,matching:find.byType(VideoThumbnail))).source,omoNetworkSource);
      expect(tester.widget<CollectionCoverPrivacyScope>(find.descendant(of:avatar,matching:find.byType(CollectionCoverPrivacyScope))).enabled,isFalse,
        reason:'a source account portrait is not a protected record cover');

      expect(PluginAccountIdentities.current(omoNetworkSource)?.serverIdentity,'42');
      final settings = find.widgetWithText(ListTile, t.plugin.pluginSettings);
      await tester.scrollUntilVisible(
        settings,
        250,
        scrollable: find.descendant(
          of: find.byType(OmoAccountPage),
          matching: find.byType(Scrollable),
        ).first,
      );
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(PluginSettingsPage),findsOneWidget);
      expect(find.byType(PluginUserInfoCard),findsOneWidget);
      expect(tester.widget<PluginUserInfoCard>(find.byType(PluginUserInfoCard)).verified,isTrue);
      expect(find.text('ID: 42'),findsNothing);
      expect(tester.widget<PluginUserInfoCard>(find.byType(PluginUserInfoCard)).accountIdentity,isEmpty);
      expect(find.byKey(const ValueKey('plugin-account-authenticated')),findsOneWidget);
      expect(find.text(t.plugin.accountSummaryHint),findsNothing);
      expect(find.text(t.plugin.noCheckinReceipt),findsNothing);
      expect(find.descendant(of:find.byType(PluginSettingsContent),matching:find.text('Actual member')),findsOneWidget);
      expect(api.calls.where((fn)=>fn=='getUserInfoBundle'),isEmpty,reason:'the plugin has no API identity capability');
      await tester.tap(find.text(t.plugin.switchAccount));await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage),findsOneWidget);
      expect(find.text(t.accountProfiles.current),findsOneWidget);expect(find.text(t.accountProfiles.needsVerification),findsNothing);
      await tester.binding.handlePopRoute();await tester.pumpAndSettle();
      expect(find.byType(PluginUserInfoCard),findsOneWidget);
      await tester.binding.handlePopRoute();await tester.pumpAndSettle();
      expect(site.account?.id,'42');expect(find.text('Actual member'),findsOneWidget);
      expect(tester.takeException(),isNull);
    },variant:TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
