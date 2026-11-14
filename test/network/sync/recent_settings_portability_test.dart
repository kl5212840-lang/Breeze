import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/routing_portable_preferences.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/network/sync/sync_direction.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_catalog.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/routing_saved_rules.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_presentation.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import '../../test_helper.dart';
import 'sync_installed_fixture.dart';

const _source = '1e600cff-8ebe-4517-8aa4-6678aec46424';
const _blockScope = '$_source|cloudFavorite';
const _pinScope = 'source-results|$_blockScope';
class _Remote implements ComicSyncRemoteAdapter {
  final files = <String, List<int>>{};
  @override Future<void> ensureRemoteReady() async {}
  @override Future<void> testConnection() async {}
  @override Future<String> downloadRemoteMd5() async => '';
  @override Future<void> uploadRemoteMd5(String value) async {}
  @override Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override Future<List<int>> downloadRemoteFile(String path) async => files[path]!;
  @override Future<void> uploadRemoteFile(String path, List<int> bytes, {String contentType = 'application/octet-stream'}) async { files[path] = List.of(bytes); }
  @override Future<void> deleteRemoteFiles(List<String> paths) async { for (final path in paths) { files.remove(path); } }
}
Future<List<int>> _identity(List<int> bytes) async => bytes;
const _codec = VideoLibrarySyncCodec(encode: _identity, decode: _identity);

Future<void> _seed() async {
  await CollectionViewPreferences.write('plugin|$_source|movie|favorite', 'list');
  await SourceListPreferences.write(_source, true);
  await SourceListBlockPreferences.write(_blockScope, {'Public category'});
  await ShelfFacetPreferences.save(_pinScope, {'Public tag'});
  await BookshelfSourcePreferenceStore().save(BookshelfSourceMedium.download,
    BookshelfSourcePreferences(order: [_source], hidden: [_source]));
  await VideoPlaybackPreferences.save('defaultSpeed', 1.25);
  await RoutingObservedMediaDomains.commitProbe(source: _source, domains: ['media.fixture.tv'], complete: true);
  await RoutingDomainCatalogStore.save(RoutingPlan(extraDomains: {_source: ['static.fixture.tv']}));
  await RoutingSavedRulesStore.save(plan: RoutingPlan(choices: {_source: PluginRoute.proxy}),
    sources: const [RoutingSource(_source, 'Source', ['media.fixture.tv'])], expectedRevisions: {_source: 0});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async { SharedPreferences.setMockInitialValues({}); await installSyncPlugins([_source]); });
  test('real cloud envelope restores recent display, pins, source labels, playback and routing through their readers', () async {
    await _seed();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('breeze.source.network.v1.$_source', '{"mode":"proxy","address":"127.0.0.1:1234"}');
    await prefs.setBool('breeze.local.collection-cover.enabled.v1', true);
    await prefs.setString('breeze.local.account-profile-selection.v1', 'local-account');
    final remote = _Remote();
    await VideoLibrarySync.run(remote, store: VideoLibraryStore(deviceId: 'sender'), codec: _codec, direction: SyncDirection.upload);
    final wire = utf8.decode(remote.files.values.single);
    expect(wire, contains(RoutingObservedMediaDomains.storageKey));
    expect(wire, isNot(contains('127.0.0.1')));
    expect(wire, isNot(contains('local-account')));
    expect(wire, isNot(contains('breeze.local.collection-cover.enabled.v1')));
    SharedPreferences.setMockInitialValues({'breeze.local.account-profile-selection.v1': 'receiver-account', 'breeze.local.collection-cover.enabled.v1': false});
    await VideoLibrarySync.run(remote, store: VideoLibraryStore(deviceId: 'receiver'), codec: _codec,
      upload: false, direction: SyncDirection.restore);
    expect(await CollectionViewPreferences.read('plugin|$_source|movie|favorite'), 'list');
    expect(await SourceListPreferences.read(_source), isTrue);
    expect(await SourceListBlockPreferences.read(_blockScope), {'Public category'});
    expect(await ShelfFacetPreferences.load(_pinScope), {'Public tag'});
    expect((await BookshelfSourcePreferenceStore().read(BookshelfSourceMedium.download)).hidden, {_source});
    expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.25);
    expect((await RoutingObservedMediaDomains.read())[_source]!.single.host, 'media.fixture.tv');
    expect((await RoutingSavedRulesStore.read()).sources[_source]!.route, PluginRoute.proxy);
    expect((await RoutingDomainCatalogStore.read()).sources.singleWhere((s) => s.id == _source).domains, contains('media.fixture.tv'));
    expect((await SharedPreferences.getInstance()).getString('breeze.local.account-profile-selection.v1'), 'receiver-account');
    expect((await SharedPreferences.getInstance()).getBool('breeze.local.collection-cover.enabled.v1'), isFalse);
  });
  test('plugin and app settings switches preserve independent pin scopes and source ownership', () async {
    await _seed();
    final snapshot = await PortablePreferences.capture();
    final pluginOnly = PortablePreferences.forSync(snapshot, includeSettings: false, includePluginSettings: true);
    final appOnly = PortablePreferences.forSync(snapshot, includeSettings: true, includePluginSettings: false);
    bool contains(PortablePreferencesSnapshot value, String key) => value.entries.values.any((row) => row['key'] == key && row['deleted'] != true);
    final pinKey = 'breeze.bookshelf.facet-tags.v1.${Uri.encodeComponent(_pinScope)}';
    expect(contains(pluginOnly, pinKey), isTrue);
    expect(contains(appOnly, pinKey), isFalse);
    expect(pluginPortableScope({'key': pinKey})!.source, _source);
    expect(contains(pluginOnly, SourceListBlockPreferences.key(_blockScope)), isTrue);
    expect(contains(pluginOnly, BookshelfSourcePreferenceStore.key(BookshelfSourceMedium.download)), isFalse);
    expect(contains(appOnly, BookshelfSourcePreferenceStore.key(BookshelfSourceMedium.download)), isTrue);
    expect(contains(appOnly, RoutingObservedMediaDomains.storageKey), isTrue);
    final recordsOnly = PortablePreferences.forSync(snapshot, includeSettings: false, includePluginSettings: false);
    expect(recordsOnly.entries, isEmpty);
  });
  testWidgets('restoring category preferences reloads an already mounted source consumer', (tester) async {
    late PortablePreferencesSnapshot remote;
    await tester.runAsync(() async {
      await SourceListBlockPreferences.write(_blockScope, {'Remote category'});
      remote = await PortablePreferences.capture();
      await SourceListBlockPreferences.write(_blockScope, {'Local category'});
    });
    await tester.pumpWidget(MaterialApp(home: SourceCategoryBlockScope(scope: _blockScope,
      builder: (context, blocked, change) => Text(blocked.join(', ')))));
    await tester.pumpAndSettle();
    expect(find.text('Local category'), findsOneWidget);
    await tester.runAsync(() => PortablePreferences.restore(remote, direction: SyncDirection.restore));
    await tester.pumpAndSettle();
    expect(find.text('Remote category'), findsOneWidget);
    expect(find.text('Local category'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  test('routing rejects private endpoints and unknown fields before restoring any preference', () async {
    await _seed();
    final valid = await PortablePreferences.capture();
    final saved = jsonDecode((await SharedPreferences.getInstance()).getString(RoutingSavedRulesStore.storageKey)!) as Map;
    saved['fingerprint'] = '0' * 64;
    expect(validPortableRoutingValue(RoutingSavedRulesStore.storageKey, jsonEncode(saved)), isFalse,
      reason: 'Only a digest of the actual public saved rules is accepted');
    final damaged = PortablePreferencesSnapshot({for (final entry in valid.entries.entries) entry.key: {
      ...entry.value,
      if (entry.value['key'] == RoutingObservedMediaDomains.storageKey)
        'value': jsonEncode({_source: [{'host': '127.0.0.1', 'at': 1, 'evidence': ['requested'], 'headers': 'must-not-travel'}]}),
    }});
    final before = (await SharedPreferences.getInstance()).getString(RoutingObservedMediaDomains.storageKey);
    await expectLater(PortablePreferences.restore(damaged, replace: true), throwsFormatException);
    expect((await SharedPreferences.getInstance()).getString(RoutingObservedMediaDomains.storageKey), before);
  });
}
