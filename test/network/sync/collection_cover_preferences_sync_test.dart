import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

void main() {
  final controller = CollectionCoverPrivacyController.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller.state.value = const CollectionCoverPrivacySettings();
  });
  test(
    'restoring style never changes device protection or local images',
    () async {
      await controller.ensureLoaded();
      await controller.setEnabled(true);
      await controller.setStyle(CollectionCoverStyle.custom);
      var preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        LocalAppearanceImages.preferencesKey,
        '{"collection-cover":"private-device-a.jpg"}',
      );
      final snapshot = await PortablePreferences.capture();
      final encoded = jsonEncode(snapshot.toJson());
      expect(encoded, contains(CollectionCoverPrivacyController.styleKey));
      expect(
        encoded,
        isNot(contains(CollectionCoverPrivacyController.enabledKey)),
      );
      expect(encoded, isNot(contains(LocalAppearanceImages.preferencesKey)));
      expect(encoded, isNot(contains('private-device-a')));
      final settingsOff = PortablePreferences.forSync(
        snapshot,
        includeSettings: false,
      );
      expect(
        jsonEncode(settingsOff.toJson()),
        isNot(contains(CollectionCoverPrivacyController.styleKey)),
      );

      SharedPreferences.setMockInitialValues({
        CollectionCoverPrivacyController.enabledKey: false,
        LocalAppearanceImages.preferencesKey:
            '{"collection-cover":"private-device-b.jpg"}',
      });
      controller.state.value = const CollectionCoverPrivacySettings();
      await controller.ensureLoaded();
      await PortablePreferences.restore(
        PortablePreferencesSnapshot.fromJson(jsonDecode(encoded)),
        replace: true,
      );
      preferences = await SharedPreferences.getInstance();
      expect(controller.state.value.enabled, isFalse);
      expect(controller.state.value.style, CollectionCoverStyle.custom);
      expect(
        preferences.getBool(CollectionCoverPrivacyController.enabledKey),
        isFalse,
      );
      expect(
        preferences.getString(LocalAppearanceImages.preferencesKey),
        '{"collection-cover":"private-device-b.jpg"}',
      );
    },
  );

  test(
    'replace without a style resets only style before notifying listeners',
    () async {
      await controller.ensureLoaded();
      await controller.setEnabled(true);
      await controller.setStyle(CollectionCoverStyle.custom);
      controller.localImagePath.value = '/device-b/local-cover-fixture.jpg';
      addTearDown(() => controller.localImagePath.value = null);
      var notifications = 0;
      void restored() {
        notifications++;
        expect(controller.state.value.style, CollectionCoverStyle.blur);
        expect(controller.state.value.enabled, isTrue);
        expect(
          controller.localImagePath.value,
          '/device-b/local-cover-fixture.jpg',
        );
      }

      PortablePreferences.changes.addListener(restored);
      addTearDown(() => PortablePreferences.changes.removeListener(restored));
      await PortablePreferences.restore(
        PortablePreferencesSnapshot(),
        replace: true,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.containsKey(CollectionCoverPrivacyController.styleKey),
        isFalse,
      );
      expect(
        preferences.getBool(CollectionCoverPrivacyController.enabledKey),
        isTrue,
      );
      expect(notifications, 1);
    },
  );

  test(
    'invalid remote style and local preference keys are rejected before writes',
    () async {
      await controller.ensureLoaded();
      await controller.setStyle(CollectionCoverStyle.glass);
      final snapshot = await PortablePreferences.capture();
      final raw =
          jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>;
      final entries = raw['entries'] as Map<String, dynamic>;
      (entries.values.single as Map<String, dynamic>)['value'] =
          'unknown-effect';
      expect(
        () => PortablePreferencesSnapshot.fromJson(raw),
        throwsFormatException,
      );
      expect(
        PortablePreferences.owns(CollectionCoverPrivacyController.enabledKey),
        isFalse,
      );
      expect(
        PortablePreferences.owns(LocalAppearanceImages.preferencesKey),
        isFalse,
      );
      expect(controller.state.value.style, CollectionCoverStyle.glass);
    },
  );
}
