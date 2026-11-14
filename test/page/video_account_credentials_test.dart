import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';

void main() {
  final home = Uri.parse('https://example.test');
  Map<String, Object> entry() => {
    'version': 1,
    'account': 'fixture',
    'password': 'secret',
    'origin': 'https://example.test',
    'updatedAt': 1,
    'deleted': false,
  };
  test('valid credentials require the exact HTTPS origin', () {
    expect(VideoAccountCredentials.decode(entry(), home)?.account, 'fixture');
    expect(
      VideoAccountCredentials.decode(entry(), Uri.parse('https://other.test')),
      isNull,
    );
    expect(
      VideoAccountCredentials.decode(entry(), Uri.parse('http://example.test')),
      isNull,
    );
    expect(
      VideoAccountCredentials.decode({
        ...entry(),
        'origin': 'https://example.test/path',
      }, home),
      isNull,
    );
  });
  test('tombstones and empty credentials never prefill', () {
    expect(
      VideoAccountCredentials.decode({...entry(), 'deleted': true}, home),
      isNull,
    );
    expect(
      VideoAccountCredentials.decode({...entry(), 'account': ' '}, home),
      isNull,
    );
    expect(
      VideoAccountCredentials.decode({...entry(), 'password': ''}, home),
      isNull,
    );
    expect(
      VideoAccountCredentials.decode({...entry(), 'version': 2}, home),
      isNull,
    );
  });
  test('Omo login guard rejects cross-origin and non-login pages', () {
    expect(
      videoCredentialsMayFill(
        home,
        Uri.parse('https://example.test/user/login.html'),
      ),
      isTrue,
    );
    expect(
      videoCredentialsMayFill(
        home,
        Uri.parse('https://other.test/user/login.html'),
      ),
      isFalse,
    );
    expect(
      videoCredentialsMayFill(
        home,
        Uri.parse('http://example.test/user/login.html'),
      ),
      isFalse,
    );
    expect(
      videoCredentialsMayFill(
        home,
        Uri.parse('https://example.test/user/index.html'),
      ),
      isFalse,
    );
  });
  test(
    'Omo fill script fills blank fields without submitting and preserves edits',
    () async {
      final saved = VideoAccountCredentials('fixture', 'secret', home);
      final script = videoCredentialsFillScript(home, saved);
      final js =
          """
class HTMLInputElement { constructor(value='') { this._value=value; } get value() { return this._value; } set value(v) { this._value=v; } dispatchEvent() {} }
class Event { constructor() {} }
let account = new HTMLInputElement(); let password = new HTMLInputElement();
let submits = 0; let form = {querySelector: () => account, submit: () => submits++}; password.form = form;
let location = {origin:'https://example.test', pathname:'/user/login.html'};
let document = {querySelector: () => password};
let result = $script;
let first = [result, account.value, password.value, submits];
account.value='edited'; password.value=''; $script;
let second = [account.value, password.value, submits];
location.origin='https://other.test'; account.value=''; password.value=''; let blocked = $script;
console.log(JSON.stringify([first, second, blocked, account.value, password.value, submits]));
""";
      final result = await Process.run('node', ['-e', js]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(jsonDecode(result.stdout as String), [
        [true, 'fixture', 'secret', 0],
        ['edited', '', 0],
        false,
        '',
        '',
        0,
      ]);
    },
  );
}
