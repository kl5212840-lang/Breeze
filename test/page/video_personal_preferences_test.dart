import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/plugin_portable_scope.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/video/video_personal_preferences.dart';
import 'package:zephyr/service/collection_view_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'view, filter and pinned tags retain certified plugin ownership',
    () async {
      const scope =
          'plugin|hanime|https://hanime1.me/user/1|https://hanime1.me/user/1/likes';
      for (final key in [
        CollectionViewPreferences.keyFor(scope),
        '${VideoPersonalPreferences.prefix}${Uri.encodeComponent(scope)}',
        'breeze.bookshelf.facet-tags.v1.${Uri.encodeComponent(scope)}',
      ]) {
        expect(PortablePreferences.owns(key), true);
        expect(pluginPortableScope({'key': key})?.source, 'hanime');
      }
      await VideoPersonalPreferences.write(scope, {
        'query': 'first',
        'sort': 'source',
        'facets': {},
      });
      final first = VideoPersonalPreferences.write(scope, {
        'query': 'second',
        'sort': 'title',
        'facets': {
          'tags': ['A'],
        },
      });
      final latest = VideoPersonalPreferences.write(scope, {
        'query': 'latest',
        'sort': 'source',
        'facets': {},
      });
      await Future.wait([first, latest]);
      expect((await VideoPersonalPreferences.read(scope))['query'], 'latest');
      expect(
        await VideoPersonalPreferences.read(
          scope.replaceFirst('/user/1|', '/user/2|'),
        ),
        isEmpty,
      );
    },
  );
}
