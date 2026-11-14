import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';

void main() {
  final home = Uri.parse('https://www.omofuna.com/');
  Map<String, dynamic> account(String id) => {
    'kind': 'account',
    'account': {'id': id, 'name': '显示昵称', 'group': '游客'},
  };
  test('comment likes call the real endpoint once and reject stale-account responses', () async {
    final calls = <String>[];
    final pending = Completer<Map<String, dynamic>>();
    final client = OmoSiteClient(home: home, request: (operation, args) async {
      calls.add(operation);
      if (operation == 'account') return account('1');
      expect(args['commentId'], '82');
      return pending.future;
    });
    await client.readAccount();
    final writing = client.setCommentLike('82', true);
    await expectLater(client.setCommentLike('82', true), throwsA(isA<OmoSiteException>()));
    client.invalidateAccount();
    pending.complete({'kind':'mutation','accepted':true});
    await expectLater(writing, throwsA(isA<OmoSiteException>()));
    expect(calls, ['account','commentLike']);
    client.dispose();
  });
  test(
    'confirmed login reader updates the shared account without discarding it first',
    () async {
      final client = OmoSiteClient(
        home: home,
        request: (_, _) async => account('1'),
      );
      await client.readAccount();
      final signedIn = Completer<Map<String, dynamic>>();
      final pending = client.readAccount(read: (_, _) => signedIn.future);
      expect(client.account?.id, '1');
      signedIn.complete(account('2'));
      expect((await pending)?.id, '2');
      client.dispose();
    },
  );
  test('a stale signed-out read cannot clear a newer account', () async {
    final first = Completer<Map<String, dynamic>>();
    var calls = 0;
    final client = OmoSiteClient(
      home: home,
      request: (_, _) async => ++calls == 1 ? first.future : account('2'),
    );
    final old = client.readAccount();
    expect((await client.readAccount())?.id, '2');
    first.complete({'kind': 'signedOut'});
    await old;
    expect(client.account?.id, '2');
    expect(client.account?.group, '游客');
    client.dispose();
  });
  test(
    'an uncertain favorite write is read back without a duplicate mutation',
    () async {
      final calls = <String>[];
      final client = OmoSiteClient(
        home: home,
        request: (op, _) async {
          calls.add(op);
          if (op == 'account') return account('1');
          if (op == 'favoriteAdd') throw TimeoutException('Lost response');
          return {'kind': 'favoriteState', 'favorite': true};
        },
      );
      await client.readAccount();
      expect(await client.setFavorite('18454', true), isTrue);
      expect(calls, ['account', 'favoriteAdd', 'favoriteState']);
      client.dispose();
    },
  );
  test(
    'an accepted HTTP result does not override a failed state readback',
    () async {
      final client = OmoSiteClient(
        home: home,
        request: (op, _) async {
          if (op == 'account') return account('1');
          if (op == 'favoriteAdd') {
            return {'kind': 'mutation', 'accepted': true};
          }
          return {'kind': 'favoriteState', 'favorite': false};
        },
      );
      await client.readAccount();
      await expectLater(
        client.setFavorite('18454', true),
        throwsA(isA<OmoSiteException>()),
      );
      client.dispose();
    },
  );
}
