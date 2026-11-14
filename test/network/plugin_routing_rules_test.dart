import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/source_network_policy.dart';

void main() {
  final omo = routingSources.first;
  RoutingPlan direct() => RoutingPlan(choices: {omo.id: PluginRoute.direct});

  test(
    'default adds no rules; all seven public sources use public hosts',
    () {
      expect(RoutingPlan().shadowrocketRules, isEmpty);
      expect(routingSources.length, 7);
      expect(routingSources.map((s) => s.id).toSet().length, 7);
      for (final source in routingSources) {
        for (final host in source.domains) {
          expect(normalizeRoutingDomain(host), host);
        }
      }
      expect(
        direct().shadowrocketRules,
        contains('DOMAIN,www.omofuna.com,DIRECT'),
      );
      expect(direct().shadowrocketRules, isNot(contains('DOMAIN-SUFFIX')));
      expect(direct().shadowrocketRules, isNot(contains('github')));
    },
  );

  test('manual blocks share merge markers and contain only current rules', () {
    expect(
      direct().shadowrocketRuleBlock,
      '$routingRuleBlockStart\n${direct().shadowrocketRules}\n$routingRuleBlockEnd',
    );
    expect(
      RoutingPlan().shadowrocketRuleBlock,
      '$routingRuleBlockStart\n$routingRuleBlockEnd',
    );
    expect(
      mergeShadowrocketConfig('[Rule]\nFINAL,PROXY\n', direct()),
      contains(direct().shadowrocketRuleBlock),
    );
  });

  test('shared host conflict is explicit; same policy deduplicates', () {
    final other = routingSources[1];
    final plan = direct().withSource(other.id, PluginRoute.proxy, [
      'www.omofuna.com',
    ]);
    expect(() => plan.rules, throwsA(isA<RoutingConflict>()));
    final same = plan.withSource(other.id, PluginRoute.direct, [
      'www.omofuna.com',
    ]);
    expect(
      'DOMAIN,www.omofuna.com,DIRECT'.allMatches(same.shadowrocketRules).length,
      1,
    );
  });

  test('export never includes an unselected plugin from a previous plan', () {
    final old = direct().withSource(
      routingSources[1].id,
      PluginRoute.proxy,
      [],
    );
    final selected = old.onlySources({omo.id});
    expect(selected.shadowrocketRules, contains('www.omofuna.com'));
    expect(selected.shadowrocketRules, isNot(contains('picaapi')));
  });

  test(
    'custom domains cannot inject rules, credentials, URLs, IPs or suffixes',
    () {
      for (final host in [
        '*.example.com',
        'https://example.com/a?token=secret',
        'example.com:443',
        '127.0.0.1',
        '192.168.1.1',
        'host.local',
        'a@example.com',
        'example.com,DIRECT',
        'example.com\nFINAL,PROXY',
        '-bad.example.com',
        'example..com',
      ]) {
        expect(
          () => normalizeRoutingDomain(host),
          throwsFormatException,
          reason: host,
        );
      }
      expect(
        normalizeRoutingDomain(' MEDIA.Example.com '),
        'media.example.com',
      );
    },
  );

  for (final eol in ['\n', '\r\n']) {
    test(
      'merge preserves servers/DNS/other sections and is idempotent ($eol)',
      () {
        final original = [
          '[General]',
          'dns-server = system',
          '',
          '[Proxy]',
          'My Node = dummy',
          '',
          '[Rule]',
          '# custom rule',
          'DOMAIN,example.net,DIRECT',
          'FINAL,PROXY',
          '',
          '[Host]',
          'example.org = 1.2.3.4',
          '',
        ].join(eol);
        final once = mergeShadowrocketConfig(original, direct());
        expect(mergeShadowrocketConfig(once, direct()), once);
        expect(mergeShadowrocketConfig(once, RoutingPlan()), original);
        expect(
          once.substring(0, once.indexOf('[Rule]')),
          original.substring(0, original.indexOf('[Rule]')),
        );
        expect(
          once.substring(once.indexOf('[Host]')),
          original.substring(original.indexOf('[Host]')),
        );
        expect(
          once.indexOf('DOMAIN,www.omofuna.com,DIRECT'),
          lessThan(once.indexOf('FINAL,PROXY')),
        );
        expect(once.contains('\r\r'), isFalse);
      },
    );
  }

  test('BOM, case and no final newline do not break the config', () {
    const original = '\uFEFF[rule]';
    final merged = mergeShadowrocketConfig(original, direct());
    expect(merged.startsWith('$original\n# BEGIN BREEZE'), isTrue);
    expect(mergeShadowrocketConfig(merged, direct()), merged);
  });

  test('ambiguous configs fail without a partial rewrite', () {
    for (final original in [
      'ss://opaque',
      '[General]\na=b',
      '[Rule]\n[Rule]\nFINAL,PROXY',
      '[Rule]\n# BEGIN BREEZE NETWORK RULES v1\nFINAL,DIRECT',
      '[Rule]\n\u0000',
    ]) {
      expect(
        () => mergeShadowrocketConfig(original, direct()),
        throwsFormatException,
      );
    }
  });

  test(
    'export intentions never change saved request proxy preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      await SourceNetworkPolicies.save(
        omo.id,
        const SourceNetworkPreference(
          mode: SourceNetworkMode.proxy,
          address: '127.0.0.1:1082',
        ),
      );
      await RoutingPlanStore.save(direct());
      expect((await RoutingPlanStore.read()).fingerprint, direct().fingerprint);
      expect(
        (await SourceNetworkPolicies.read(omo.id)).address,
        '127.0.0.1:1082',
      );
      expect(await RoutingPlanStore.lastExport(), isNull);
      await RoutingPlanStore.recordExport(direct());
      expect(await RoutingPlanStore.lastExport(), direct().fingerprint);
      final changed = direct().withSource(omo.id, PluginRoute.proxy, []);
      expect(changed.fingerprint, isNot(await RoutingPlanStore.lastExport()));
      final values = (await SharedPreferences.getInstance()).getKeys();
      expect(values.any((key) => key.contains('configContents')), isFalse);
    },
  );
}
