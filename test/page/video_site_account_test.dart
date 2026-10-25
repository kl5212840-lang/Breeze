import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_site_account.dart';
import 'package:zephyr/page/video/video_site_forms.dart';

void main() {
  final linkedom = Directory(
    '${Directory.current.parent.path}/Breeze-plugin-Hanime1-native/node_modules/linkedom',
  );
  test(
    'account scripts isolate forms, hidden values and recovery navigation',
    () async {
      final page = Uri.parse('https://hanime1.me/user/7/edit');
      final process = await Process.start('node', [
        'test/script/video_account_dom_check.cjs',
        linkedom.path,
      ]);
      process.stdin.write(
        jsonEncode({
          'accountRead': videoAccountReadScript(page),
          'profileLink': videoSiteProfileLinkScript,
          'profileSubmit': videoAccountSubmitScript(
            page: page,
            operation: 'profile',
            values: const {
              'name': 'Changed fixture',
              'email': 'changed@example.test',
            },
          ),
          'passwordSubmit': videoAccountSubmitScript(
            page: page,
            operation: 'password',
            values: const {
              'password_old': 'synthetic-old-password',
              'password_new': 'synthetic-new-password',
              'password_new_confirm': 'synthetic-new-password',
            },
          ),
          'passwordMismatch': videoAccountSubmitScript(
            page: page,
            operation: 'password',
            values: const {
              'password_old': 'synthetic-old-password',
              'password_new': 'synthetic-new-password',
              'password_new_confirm': 'different',
            },
          ),
          'logoutSubmit': videoAccountSubmitScript(
            page: page,
            operation: 'logout',
          ),
          'recoveryRead': videoRecoveryMetadataScript,
          'recoverySubmit': videoRecoverySubmitScript(
            page: Uri.parse('https://hanime1.me/password/reset'),
            email: 'fixture@example.test',
          ),
        }),
      );
      await process.stdin.close();
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      expect(exitCode, 0, reason: await errors);
      final result = jsonDecode(await output) as Map;
      expect(result['structuralChecks'], 21);
      expect(result['networkRequests'], 0);
      expect(result['realWritesVerified'], isFalse);
    },
    skip: linkedom.existsSync()
        ? false
        : 'Requires the optional Hanime plugin development DOM dependency.',
  );
}
