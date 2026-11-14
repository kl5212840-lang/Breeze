import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/service/update/app_update_reminder_preferences.dart';
import 'package:zephyr/service/update/app_update_version.dart';
import 'package:zephyr/service/update/check_update.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stable version comparison ignores build metadata', () {
    final stable = AppUpdateVersion.parse('v3.0.41')!;
    expect(stable.compareTo(AppUpdateVersion.parse('3.0.41+2369')!), 0);
    expect(stable.compareTo(AppUpdateVersion.parse('3.0.41-rc.1')!), 1);
    expect(stable.compareTo(AppUpdateVersion.parse('3.0.42-rc.1')!), -1);
    expect(stable.compareTo(AppUpdateVersion.parse('3.0.9')!), 1);
    expect(AppUpdateVersion.parse('Unknown'), isNull);
    expect(AppUpdateVersion.parse('v3.0'), isNull);
    expect(AppUpdateVersion.parse('v3.0.41-'), isNull);
  });

  test('startup respects device switch, cooldown and clock changes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppUpdateReminderPreferences.load();
    final first = DateTime.utc(2026, 11, 11);
    expect(prefs.enabled, isTrue);
    expect(await prefs.beginAutomaticCheck(first), isTrue);
    expect(await prefs.beginAutomaticCheck(first), isFalse);
    expect(
      await prefs.beginAutomaticCheck(first.add(const Duration(hours: 5))),
      isFalse,
    );
    expect(
      await prefs.beginAutomaticCheck(
        first.add(AppUpdateReminderPreferences.automaticCheckInterval),
      ),
      isTrue,
    );
    expect(await prefs.beginAutomaticCheck(first), isTrue);
    await prefs.setEnabled(false);
    final reopened = await AppUpdateReminderPreferences.load();
    expect(reopened.enabled, isFalse);
    expect(
      await reopened.beginAutomaticCheck(first.add(const Duration(days: 1))),
      isFalse,
    );
    expect(reopened.canNotify(AppUpdateVersion.parse('v3.0.42')!), isFalse);
  });

  test(
    'previous notification suppresses repeats and stale mirror versions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppUpdateReminderPreferences.load();
      final first = AppUpdateVersion.parse('v3.0.41')!;
      expect(prefs.canNotify(first), isTrue);
      expect(await prefs.markNotified(first), isTrue);
      final reopened = await AppUpdateReminderPreferences.load();
      expect(
        reopened.canNotify(AppUpdateVersion.parse('V3.0.41+12')!),
        isFalse,
      );
      expect(reopened.canNotify(AppUpdateVersion.parse('v3.0.40')!), isFalse);
      expect(reopened.canNotify(AppUpdateVersion.parse('v3.0.42')!), isTrue);
    },
  );

  test(
    'accepts canonical upstream alias and enforces release and APK paths',
    () {
      const repo = 'deretame/Breeze';
      final fixture =
          jsonDecode(
                File(
                  'update-tag-version/latest-release.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        AppUpdateRelease.tryParse(fixture, repo: 'kl5212840-lang/Breeze'),
        isNull,
      );
      expect(
        AppUpdateRelease.tryParse({...fixture, 'draft': true}, repo: repo),
        isNull,
      );
      expect(
        AppUpdateRelease.tryParse({...fixture, 'prerelease': true}, repo: repo),
        isNull,
      );
      final canonical = (fixture['html_url'] as String).replaceFirst(
        repo,
        'breeze-project-org/Breeze',
      );
      final release = AppUpdateRelease.tryParse({
        ...fixture,
        'html_url': canonical,
      }, repo: repo)!;
      expect(
        AppUpdateRelease.androidAsset(
          release,
          repo: repo,
          abi: 'arm64-v8a',
        )?.pathSegments.last,
        contains('arm64-v8a'),
      );
      expect(
        AppUpdateRelease.androidAsset(release, repo: repo, abi: 'x86'),
        isNull,
      );
      final arm64 = release.assets.firstWhere(
        (asset) => asset.browserDownloadUrl.contains('arm64-v8a'),
      );
      final wrongAsset = arm64.copyWith(
        browserDownloadUrl: arm64.browserDownloadUrl.replaceFirst(
          '/download/${release.tagName}/',
          '/download/v3.0.0/',
        ),
      );
      expect(
        AppUpdateRelease.androidAsset(
          release.copyWith(assets: [wrongAsset]),
          repo: repo,
          abi: 'arm64-v8a',
        ),
        isNull,
      );
    },
  );
}
