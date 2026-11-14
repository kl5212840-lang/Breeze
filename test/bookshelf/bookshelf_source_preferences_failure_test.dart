import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/page/bookshelf/service/bookshelf_source_preferences.dart';

class _FailedSourceStore extends InMemorySharedPreferencesStore {
  _FailedSourceStore() : super.empty();
  bool rejectNext = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (rejectNext) { rejectNext = false; return false; }
    return super.setValue(type, key, value);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('download labels are an independent medium using the same preference contract', () async {
    final store = BookshelfSourcePreferenceStore();
    await store.save(BookshelfSourceMedium.comic, BookshelfSourcePreferences(order: ['a','b'], hidden: ['a']));
    await store.save(BookshelfSourceMedium.download, BookshelfSourcePreferences(order: ['b','a'], hidden: ['b']));
    expect((await store.read(BookshelfSourceMedium.comic)).hidden, {'a'});
    expect((await store.read(BookshelfSourceMedium.download)).hidden, {'b'});
    await store.save(BookshelfSourceMedium.download, BookshelfSourcePreferences());
    expect((await store.read(BookshelfSourceMedium.download)).hidden, isEmpty);
    expect((await store.read(BookshelfSourceMedium.comic)).hidden, {'a'});
  });
  test('failed source save restores the prior preference cache and can be retried', () async {
    final previous = SharedPreferencesStorePlatform.instance, backend = _FailedSourceStore();
    SharedPreferencesStorePlatform.instance = backend;
    try {
      final store = BookshelfSourcePreferenceStore();
      await store.save(BookshelfSourceMedium.download, BookshelfSourcePreferences(order: ['a','b']));
      final revision = BookshelfSourcePreferenceStore.changes.value;
      backend.rejectNext = true;
      await expectLater(store.save(BookshelfSourceMedium.download, BookshelfSourcePreferences(order: ['b','a'], hidden: ['a'])), throwsStateError);
      expect((await store.read(BookshelfSourceMedium.download)).order, ['a','b']);
      expect((await store.read(BookshelfSourceMedium.download)).hidden, isEmpty);
      expect(BookshelfSourcePreferenceStore.changes.value, revision);
      await store.save(BookshelfSourceMedium.download, BookshelfSourcePreferences(order: ['b','a']));
      expect((await store.read(BookshelfSourceMedium.download)).order, ['b','a']);
    } finally { SharedPreferencesStorePlatform.instance = previous; }
  });
}
