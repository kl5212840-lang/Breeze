import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/search_scope_preferences.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/page/setting/global/search_scope_settings_page.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

import '../test_helper.dart';

Map<String, Object> _video(String kind, {bool native = true}) => {
  'type': 'openVideoLibrary',
  'payload': {
    'url': 'https://video.example/',
    'nativeSearch': native,
    'protocol': 2,
    'catalogFnPath': 'getCatalog',
    'detailFnPath': 'getVideoDetail',
    'playbackFnPath': 'getPlayback',
    'capabilities': {'search': kind},
  },
};

Map<String, dynamic> _hybrid(String name) => {
  'name': name,
  'breezeExperience': {'aggregateMedia': 'comic', 'publicSearchFields': 1},
  'breezeVideoModules': [_video('full'), _video('none', native: false)],
};

const _videoOnly = '99999999-eeee-4444-8888-333333333333';
const _disabled = '99999999-aaaa-4444-8888-333333333333';
const _comic = SearchScopePreferences.comic;
const _videoScope = SearchScopePreferences.video;
const _aggregate = SearchScopePreferences.aggregate;

Future<void> _save(
  String surface,
  KeywordSearchScope value, {
  String? source,
}) => SearchScopePreferences.save(
  source: source,
  surface: surface,
  value: value.name,
  supported: KeywordSearchScope.values.map((scope) => scope.name),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'stores default search scopes by source and media with validation',
    () async {
      await _save(_comic, KeywordSearchScope.author, source: bikaPlusSourceId);
      await _save(
        _videoScope,
        KeywordSearchScope.title,
        source: bikaPlusSourceId,
      );
      await _save(_aggregate, KeywordSearchScope.all);
      expect(
        await SearchScopePreferences.read(
          source: bikaPlusSourceId,
          surface: _comic,
        ),
        'author',
      );
      expect(
        await SearchScopePreferences.read(
          source: bikaPlusSourceId,
          surface: _videoScope,
        ),
        'title',
      );
      expect(await SearchScopePreferences.read(surface: _aggregate), 'all');
      expect(
        await SearchScopePreferences.read(
          source: _videoOnly,
          surface: _videoScope,
        ),
        isNull,
      );
      await expectLater(
        SearchScopePreferences.save(
          source: bikaPlusSourceId,
          surface: _videoScope,
          value: 'author',
          supported: ['all', 'title'],
        ),
        throwsArgumentError,
      );
      expect(
        await SearchScopePreferences.read(
          source: bikaPlusSourceId,
          surface: _videoScope,
        ),
        'title',
      );
    },
  );

  test('settings choices only include usable search contracts', () {
    final hybrid = searchScopeSettingsOptions(
      bikaPlusSourceId,
      _hybrid('Bika fixture'),
    );
    expect(hybrid[_comic], contains(KeywordSearchScope.author));
    expect(hybrid[_comic], isNot(contains(KeywordSearchScope.title)));
    expect(hybrid[_videoScope], defaultKeywordSearchScopes);
    for (final kind in ['website', 'none']) {
      expect(
        searchScopeSettingsOptions(_videoOnly, {
          'function': [
            {'action': _video(kind)},
          ],
        }),
        isEmpty,
      );
    }
    expect(
      searchScopeSettingsOptions(_videoOnly, {
        'function': [
          {'action': _video('full')},
        ],
      }).keys,
      [_videoScope],
    );
  });

  testWidgets(
    'app settings opens scope page and updates enabled plugin kinds',
    (tester) async {
      void seed(
        String source,
        Map<String, dynamic> info, {
        bool enabled = true,
      }) {
        objectbox.pluginInfoBox.put(
          PluginInfo(
            uuid: source,
            version: '1.0.0',
            originScript: 'fixture',
            insertedAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            isEnabled: enabled,
            isDeleted: false,
            lastLoadSuccess: true,
            debug: false,
            getInfoJson: jsonEncode(info),
          ),
        );
      }

      seed(bikaPlusSourceId, _hybrid('Bika hybrid'));
      seed(_videoOnly, {
        'name': 'Video only',
        'function': [
          {'action': _video('full')},
        ],
      });
      seed(_disabled, _hybrid('Disabled fixture'), enabled: false);
      await PluginRegistryService.I.init();
      await _save(_comic, KeywordSearchScope.author, source: bikaPlusSourceId);
      await _save(
        _videoScope,
        KeywordSearchScope.title,
        source: bikaPlusSourceId,
      );
      final settings = GlobalSettingCubit();
      addTearDown(settings.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: const MaterialApp(home: GlobalSettingPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.search.title));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScopeSettingsPage), findsOneWidget);
      expect(find.text('Bika hybrid'), findsOneWidget);
      expect(find.text('Video only'), findsOneWidget);
      expect(find.text('Disabled fixture'), findsNothing);
      final bika = find.byKey(
        const ValueKey(('search-settings.plugin', bikaPlusSourceId)),
      );
      final rows = tester
          .widgetList<SettingChoiceTile<KeywordSearchScope>>(
            find.descendant(
              of: bika,
              matching: find.byType(SettingChoiceTile<KeywordSearchScope>),
            ),
          )
          .toList();
      expect(rows.map((row) => row.value), [
        KeywordSearchScope.author,
        KeywordSearchScope.title,
      ]);
      await tester.tap(
        find.descendant(of: bika, matching: find.text(t.bookshelf.mediaComics)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sourceShell.searchScopeTags).hitTestable());
      await tester.pumpAndSettle();
      expect(
        await SearchScopePreferences.read(
          source: bikaPlusSourceId,
          surface: _comic,
        ),
        'tags',
      );
      expect(
        await SearchScopePreferences.read(
          source: bikaPlusSourceId,
          surface: _videoScope,
        ),
        'title',
      );

      final video = objectbox.pluginInfoBox.getAll().firstWhere(
        (row) => row.uuid == _videoOnly,
      );
      await PluginRegistryService.I.upsert(video..isEnabled = false);
      await tester.pumpAndSettle();
      expect(find.text('Video only'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
