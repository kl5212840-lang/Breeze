import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise shared_preferences' actual backing-store failure contract.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore() : super.empty();

  final firstStarted = Completer<void>();
  final firstWrite = Completer<void>();
  bool rejectWrites = false;
  int writes = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes++;
    if (writes == 1) {
      firstStarted.complete();
      await firstWrite.future;
    }
    if (rejectWrites) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'diagnostics are opt-in per source and independent of plugin debug',
    () async {
      SharedPreferences.setMockInitialValues({'debugEnabled': true});
      expect(await SourceDiagnosticPreferences.enabled('hanime'), isFalse);
      expect(await SourceDiagnosticPreferences.enabled(''), isFalse);
      await SourceDiagnosticPreferences.setEnabled('hanime', true);
      expect(await SourceDiagnosticPreferences.enabled('hanime'), isTrue);
      expect(
        await SourceDiagnosticPreferences.enabled('another-source'),
        isFalse,
      );
      final store = await SharedPreferences.getInstance();
      expect(store.getBool('debugEnabled'), isTrue);
      await store.reload();
      expect(
        store.getBool(SourceDiagnosticPreferences.storageKey('hanime')),
        isTrue,
      );
    },
  );

  test('newer toggle survives an already in-flight older write', () async {
    final store = _ControlledStore();
    SharedPreferencesStorePlatform.instance = store;
    final oldChoice = SourceDiagnosticPreferences.setEnabled(
      'race-source',
      true,
    );
    await store.firstStarted.future;
    final newChoice = SourceDiagnosticPreferences.setEnabled(
      'race-source',
      false,
    );
    store.firstWrite.complete();
    await Future.wait([oldChoice, newChoice]);
    expect(await SourceDiagnosticPreferences.enabled('race-source'), isFalse);
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    expect(
      preferences.getBool(
        SourceDiagnosticPreferences.storageKey('race-source'),
      ),
      isFalse,
    );
  });

  test(
    'failed persistence throws without publishing a diagnostics change',
    () async {
      final store = _ControlledStore()..rejectWrites = true;
      store.firstWrite.complete();
      SharedPreferencesStorePlatform.instance = store;
      final revision = SourceDiagnosticPreferences.changes.value;
      await expectLater(
        SourceDiagnosticPreferences.setEnabled('failed-source', true),
        throwsStateError,
      );
      expect(SourceDiagnosticPreferences.changes.value, revision);
      expect(
        await SourceDiagnosticPreferences.enabled('failed-source'),
        isFalse,
      );
    },
  );

  test(
    'successful writes notify after persistence and remain source-specific',
    () async {
      final revision = SourceDiagnosticPreferences.changes.value;
      await Future.wait([
        SourceDiagnosticPreferences.setEnabled('source-a', true),
        SourceDiagnosticPreferences.setEnabled('source-b', false),
      ]);
      expect(SourceDiagnosticPreferences.changes.value, revision + 2);
      expect(await SourceDiagnosticPreferences.enabled('source-a'), isTrue);
      expect(await SourceDiagnosticPreferences.enabled('source-b'), isFalse);
      await SourceDiagnosticPreferences.setEnabled('source-a', false);
      expect(await SourceDiagnosticPreferences.enabled('source-a'), isFalse);
    },
  );
}
