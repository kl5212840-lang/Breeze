import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

void main() {
  final home = Uri.parse('https://www.omofuna.com/');
  for (final path in [
    '/uploads/avatar.png',
    'uploads/avatar.png',
    '//www.omofuna.com/uploads/avatar.png',
  ]) {
    test('public relative avatar resolves safely: $path', () {
      expect(
        OmoSiteAccount.fromJson({'id': '1', 'avatar': path}, home: home).avatar,
        home.resolve('/uploads/avatar.png'),
      );
    });
  }
  for (final url in [
    'http://www.omofuna.com/a.png',
    'javascript:alert(1)',
    '//other.example/a.png',
    'https://user:secret@www.omofuna.com/a.png',
  ]) {
    test('unsafe or foreign relative avatar is rejected: $url', () {
      expect(
        OmoSiteAccount.fromJson({'avatar': url}, home: home).avatar,
        isNull,
      );
    });
  }
  test('an explicit HTTPS image CDN remains supported', () {
    expect(
      OmoSiteAccount.fromJson({
        'avatar': 'https://images.example/a.png',
      }, home: home).avatar,
      Uri.parse('https://images.example/a.png'),
    );
  });
  test(
    'an old account response cannot replace a newer identity or avatar',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async => ++calls == 1
            ? pending.future
            : {
                'kind': 'account',
                'account': {'id': '2', 'avatar': '/uploads/new.png'},
              },
      );
      final old = client.readAccount();
      await client.readAccount();
      pending.complete({
        'kind': 'account',
        'account': {'id': '1', 'avatar': '/uploads/old.png'},
      });
      await old;
      expect(client.account?.id, '2');
      expect(client.account?.avatar, home.resolve('/uploads/new.png'));
      client.dispose();
    },
  );
}
