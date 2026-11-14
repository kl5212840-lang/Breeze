import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/source_network_policy.dart';

void main() {
  const a = 'ccc2fe17-c0a8-4fd8-a596-835772686404';
  const b = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceNetworkPolicies.initialize(() => const ProxySettingState());
  });

  test(
    'validated development proxy reaches inherited source visits without saving user settings',
    () async {
      SourceNetworkPolicies.initialize(
        () => const ProxySettingState(),
        developmentProxy: 'http://proxy.example.invalid:17897',
      );
      final leases = await Future.wait([
        SourceNetworkPolicies.acquire(a),
        SourceNetworkPolicies.acquire(b),
      ]);
      try {
        expect(
          leases.map((l) => l.snapshot.proxy),
          everyElement('http://proxy.example.invalid:17897'),
        );
        expect(await SourceNetworkPolicies.hasBuiltInProxy(a), isFalse);
        expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      } finally {
        for (final lease in leases) {
          await lease.close();
        }
      }
      SourceNetworkPolicies.initialize(() => const ProxySettingState());
      expect((await SourceNetworkPolicies.resolve(a)).proxy, isEmpty);
    },
  );

  test(
    'development fallback preserves explicit user and source routes',
    () async {
      SourceNetworkPolicies.initialize(
        () => const ProxySettingState(),
        developmentProxy: 'http://proxy.example.invalid:17897',
      );
      await SourceNetworkPolicies.save(
        a,
        const SourceNetworkPreference(mode: SourceNetworkMode.system),
      );
      await SourceNetworkPolicies.save(
        b,
        const SourceNetworkPreference(
          mode: SourceNetworkMode.proxy,
          address: '127.0.0.1:1082',
          socks: true,
        ),
      );
      expect((await SourceNetworkPolicies.resolve(a)).proxy, isEmpty);
      expect(
        (await SourceNetworkPolicies.resolve(b)).proxy,
        'socks5://127.0.0.1:1082',
      );
      await SourceNetworkPolicies.save(a, const SourceNetworkPreference());
      SourceNetworkPolicies.initialize(
        () => const ProxySettingState(enabled: true, address: '127.0.0.1:1083'),
        developmentProxy: 'http://proxy.example.invalid:17897',
      );
      expect(
        (await SourceNetworkPolicies.resolve(a)).proxy,
        'http://127.0.0.1:1083',
      );
    },
  );

  test(
    'parallel visits freeze independent routes until every owner closes',
    () async {
      await SourceNetworkPolicies.save(
        a,
        const SourceNetworkPreference(
          mode: SourceNetworkMode.proxy,
          address: '127.0.0.1:1082',
        ),
      );
      await SourceNetworkPolicies.save(
        b,
        const SourceNetworkPreference(
          mode: SourceNetworkMode.proxy,
          address: '127.0.0.1:1083',
          socks: true,
        ),
      );
      final leases = await Future.wait([
        SourceNetworkPolicies.acquire(a),
        SourceNetworkPolicies.acquire(a),
        SourceNetworkPolicies.acquire(b),
      ]);
      expect(leases[0].snapshot.runtimeName, leases[1].snapshot.runtimeName);
      expect(leases[0].snapshot.proxy, 'http://127.0.0.1:1082');
      expect(leases[2].snapshot.proxy, 'socks5://127.0.0.1:1083');
      await SourceNetworkPolicies.save(
        a,
        const SourceNetworkPreference(mode: SourceNetworkMode.system),
      );
      await leases[0].close();
      await leases[0].close();
      expect(
        (await SourceNetworkPolicies.resolve(a)).proxy,
        'http://127.0.0.1:1082',
      );
      await leases[1].close();
      expect((await SourceNetworkPolicies.resolve(a)).proxy, '');
      expect(
        (await SourceNetworkPolicies.resolve(b)).proxy,
        'socks5://127.0.0.1:1083',
      );
      await leases[2].close();
    },
  );

  test(
    'legacy Omo preference migrates without altering account storage',
    () async {
      SharedPreferences.setMockInitialValues({
        'breeze.omo.network.v1':
            '{"mode":"proxy","address":"proxy.example.invalid:17897","socks":false}',
      });
      expect(
        (await SourceNetworkPolicies.resolve(a)).proxy,
        'http://proxy.example.invalid:17897',
      );
      final name = (await SourceNetworkPolicies.resolve(a)).runtimeName;
      expect(SourceNetworkPolicies.canonicalSource(name), a);
      expect(
        SourceNetworkPolicies.canonicalSource('legacy@net.123456789abc'),
        'legacy@net.123456789abc',
      );
      await SourceNetworkPolicies.save(
        a,
        const SourceNetworkPreference(mode: SourceNetworkMode.system),
      );
      expect((await SourceNetworkPolicies.resolve(a)).proxy, '');
    },
  );

  test(
    'HTTPS proxy inheritance preserves TLS endpoint and active visits',
    () async {
      var global = const ProxySettingState(
        enabled: true,
        address: 'https://127.0.0.1:8443',
      );
      SourceNetworkPolicies.initialize(() => global);
      final old = await SourceNetworkPolicies.acquire(a);
      expect(old.snapshot.proxy, 'https://127.0.0.1:8443');
      global = global.copyWith(address: 'https://proxy.example');
      expect(
        (await SourceNetworkPolicies.resolve(a)).proxy,
        old.snapshot.proxy,
      );
      expect(
        (await SourceNetworkPolicies.resolve(b)).proxy,
        'https://proxy.example',
      );
      await old.close();
      expect(
        (await SourceNetworkPolicies.resolve(a)).proxy,
        'https://proxy.example',
      );
      await SourceNetworkPolicies.save(
        a,
        const SourceNetworkPreference(
          mode: SourceNetworkMode.proxy,
          address: 'https://proxy.example:9443',
        ),
      );
      expect(
        (await SourceNetworkPolicies.resolve(a)).proxy,
        'https://proxy.example:9443',
      );
      await SourceNetworkPolicies.save(
        a,
        const SourceNetworkPreference(mode: SourceNetworkMode.system),
      );
      expect((await SourceNetworkPolicies.resolve(a)).proxy, isEmpty);
      for (final address in [
        'https://user:pass@proxy.example:8443',
        'https://proxy.example:8443/path',
        'ftp://proxy.example:8443',
      ]) {
        expect(
          () => SourceNetworkPreference.proxyUrl(address, false),
          throwsFormatException,
        );
      }
      expect(
        () => SourceNetworkPreference.proxyUrl(
          'https://proxy.example:8443',
          true,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'invalid explicit and stored configuration never silently select direct',
    () async {
      await expectLater(
        SourceNetworkPolicies.save(
          a,
          const SourceNetworkPreference(
            mode: SourceNetworkMode.proxy,
            address: 'bad-address',
          ),
        ),
        throwsFormatException,
      );
      SharedPreferences.setMockInitialValues({
        SourceNetworkPolicies.storageKey(a): '{}',
      });
      await expectLater(
        SourceNetworkPolicies.resolve(a),
        throwsFormatException,
      );
      await expectLater(
        SourceNetworkPolicies.acquire(a),
        throwsFormatException,
      );
    },
  );
}
