import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/navigation/legacy_navigation_settings.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  for (final entry in {
    0: 10,
    1: 10,
    2: 11,
    3: 10,
    4: 12,
    10: 10,
    11: 11,
    12: 12,
    13: 13,
  }.entries) {
    test(
      'legacy startup ${entry.key} keeps its destination as ${entry.value}',
      () async {
        final raw = {
          'oldPageRollbackEnabled': true,
          'welcomePageNum': entry.key,
        };
        final decoded = GlobalSettingState.fromJson(raw);
        expect(decoded.oldPageRollbackEnabled, isFalse);
        expect(decoded.welcomePageNum, entry.value);
        expect(raw['oldPageRollbackEnabled'], isTrue);
        final user = objectbox.userSettingBox.get(1)!;
        user.globalSettingData = jsonEncode(raw);
        objectbox.userSettingBox.put(user);
        final settings = GlobalSettingCubit();
        try {
          await settings.initBox();
          expect(settings.state.welcomePageNum, entry.value);
          expect(settings.state.oldPageRollbackEnabled, isFalse);
          final persisted =
              jsonDecode(objectbox.userSettingBox.get(1)!.globalSettingData!)
                  as Map;
          expect(persisted['oldPageRollbackEnabled'], isFalse);
          expect(persisted['welcomePageNum'], entry.value);
          settings.updateState(
            (current) => current.copyWith(
              oldPageRollbackEnabled: true,
              welcomePageNum: entry.key,
            ),
          );
          expect(settings.state.oldPageRollbackEnabled, isFalse);
          expect(settings.state.welcomePageNum, entry.value);
          settings.applySyncedState(
            GlobalSettingState(
              oldPageRollbackEnabled: true,
              welcomePageNum: entry.key,
            ),
          );
          expect(settings.state.oldPageRollbackEnabled, isFalse);
          expect(
            objectbox.userSettingBox.get(1)!.globalSetting.welcomePageNum,
            entry.value,
          );
        } finally {
          await settings.close();
        }
      },
    );
  }

  test(
    'missing or false legacy flag never reinterprets an ambiguous old value',
    () {
      for (final raw in [
        <String, dynamic>{'welcomePageNum': 2},
        <String, dynamic>{'oldPageRollbackEnabled': false, 'welcomePageNum': 2},
      ]) {
        expect(normalizeLegacyNavigationJson(raw), same(raw));
        expect(GlobalSettingState.fromJson(raw).welcomePageNum, 2);
      }
    },
  );
}
