import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';

void main() {
  const sources = {'a': '甲', 'b': '乙', 'c': '丙'};
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'breeze.video.library.v1': 'untouched-content',
    }),
  );

  test(
    'known reorder retains unavailable IDs and their visibility on reinstall',
    () {
      final old = BookshelfSourcePreferences(
        order: ['a', 'missing', 'b'],
        hidden: ['missing'],
      );
      final next = old.withKnownOrder(['b', 'a']);
      expect(next.order, ['b', 'missing', 'a']);
      expect(next.hidden, {'missing'});
      expect(next.arrange({'a': '甲', 'b': '乙'}).keys, ['b', 'a']);
      expect(
        next.arrange({
          'a': '甲',
          'missing': '重装插件',
          'b': '乙',
        }, includeHidden: true).keys,
        ['b', 'missing', 'a'],
      );
      expect(
        next
            .arrange({'a': '甲', 'missing': '重装插件', 'b': '乙'})
            .containsKey('missing'),
        false,
      );
    },
  );

  test('new sources append visibly without changing explicit hidden IDs', () {
    final prefs = BookshelfSourcePreferences(order: ['b', 'a'], hidden: ['a']);
    expect(prefs.arrange(sources), {'b': '乙', 'c': '丙'});
    expect(
      BookshelfSourcePreferences.decode(prefs.encode()).encode(),
      prefs.encode(),
    );
  });

  test(
    'empty All ID cannot be hidden and malformed preferences fail locally',
    () {
      expect(BookshelfSourcePreferences(hidden: ['', '  ', 'a']).hidden, {'a'});
      expect(BookshelfSourcePreferences.decode('{bad').order, isEmpty);
      expect(
        BookshelfSourcePreferences.decode(
          '{"version":2,"order":[],"hidden":[]}',
        ).hidden,
        isEmpty,
      );
      expect(BookshelfSourcePreferences().arrange(sources), sources);
    },
  );

  test(
    'serialized saves across instances retain latest independent medium preferences',
    () async {
      final first = BookshelfSourcePreferenceStore(),
          second = BookshelfSourcePreferenceStore();
      final a = first.save(
        BookshelfSourceMedium.comic,
        BookshelfSourcePreferences(order: ['a', 'b']),
      );
      final b = second.save(
        BookshelfSourceMedium.comic,
        BookshelfSourcePreferences(order: ['b', 'a'], hidden: ['a']),
      );
      final video = first.save(
        BookshelfSourceMedium.video,
        BookshelfSourcePreferences(order: ['omo']),
      );
      await Future.wait([a, b, video]);
      final restored = await BookshelfSourcePreferenceStore().read(
        BookshelfSourceMedium.comic,
      );
      expect(restored.order, ['b', 'a']);
      expect(restored.hidden, {'a'});
      expect((await second.read(BookshelfSourceMedium.video)).order, ['omo']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('breeze.video.library.v1'), 'untouched-content');
      expect(prefs.getKeys(), {
        'breeze.video.library.v1',
        BookshelfSourcePreferenceStore.key(BookshelfSourceMedium.comic),
        BookshelfSourcePreferenceStore.key(BookshelfSourceMedium.video),
      });
    },
  );
}
