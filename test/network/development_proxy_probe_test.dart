import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/development_proxy_probe.dart';

void main() {
  test(
    'a failed external check does not reject a working configured proxy',
    () async {
      final hosts = <String>[];
      final connected = await probeDevelopmentProxy((target) async {
        hosts.add(target.host);
        return target.host == 'www.gstatic.com' ? 502 : 200;
      });
      expect(connected, isTrue);
      expect(hosts.toSet(), {'www.apple.com', 'www.gstatic.com'});
    },
  );

  test('early failure waits for a later successful target', () async {
    final later = Completer<int>();
    var completed = false;
    final pending =
        probeDevelopmentProxy((target) {
      if (target.host == 'www.apple.com') {
            return Future.error(StateError('refused'));
      }
          return later.future;
        }).then((value) {
          completed = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    later.complete(204);
    expect(await pending, isTrue);
  });

  test('an unavailable proxy is not enabled', () async {
    expect(
      await probeDevelopmentProxy((_) => Future.error(StateError('refused'))),
      isFalse,
    );
    expect(await probeDevelopmentProxy((_) async => 502), isFalse);
    expect(await probeDevelopmentProxy((_) async => 407), isFalse);
  });

  test(
    'successful transport does not wait for the other unreachable service',
    () async {
      final unavailable = Completer<int>();
      final pending = probeDevelopmentProxy(
        (target) => target.host == 'www.apple.com'
            ? Future.value(200)
            : unavailable.future,
      );
      expect(await pending, isTrue);
      unavailable.completeError(StateError('unavailable'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('both hung targets finish within the probe budget', () async {
    expect(
      await probeDevelopmentProxy(
        (_) => Completer<int>().future,
        timeout: const Duration(milliseconds: 20),
      ),
      isFalse,
    );
  });
}
