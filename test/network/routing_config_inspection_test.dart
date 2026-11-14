import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_config_inspection.dart';
import 'package:zephyr/network/routing/routing_generation_records.dart';
import 'package:zephyr/network/routing/routing_rule_output.dart';

const a = RoutingSource('plugin-a', 'Plugin A', [
  'api.example.com',
  'img.example.com',
]);
const b = RoutingSource('plugin-b', 'Plugin B', ['other.example.com']);
RoutingGenerationRecord record(
  RoutingSource source, [
  PluginRoute route = PluginRoute.direct,
]) => RoutingGenerationRecord(
  source: source,
  route: route,
  generatedAt: DateTime.utc(2026, 11, 3),
);
String block(RoutingSource source, [PluginRoute route = PluginRoute.direct]) =>
    routingRuleBlockFor(source, route, source.domains);
String config(String body) =>
    '[General]\nmode=rule\n[Rule]\n$body\n[Host]\nignored.example.com=127.0.0.1\n';
RoutingConfigurationMatch state(
  String body, {
  RoutingSource source = a,
  PluginRoute route = PluginRoute.direct,
}) => inspectRoutingConfiguration(config(body), [
  record(source, route),
]).statusBySource[source.id]!;

void main() {
  test(
    'actual generated blocks roundtrip exact identities, names and policies',
    () {
      final expected = [record(a), record(b, PluginRoute.proxy)];
      final inspection = inspectRoutingConfiguration(
        config('${block(a)}\n${block(b, PluginRoute.proxy)}'),
        expected,
      );
      expect(inspection.statusBySource, {
        'plugin-a': RoutingConfigurationMatch.matching,
        'plugin-b': RoutingConfigurationMatch.matching,
      });
      expect(inspection.ownedBlocks.map((value) => value.source.id), [
        'plugin-a',
        'plugin-b',
      ]);
      expect(inspection.ownedBlocks.first.source.name, 'Plugin A');
      expect(inspection.ownedBlocks.first.source.domains, [
        'api.example.com',
        'img.example.com',
      ]);
      expect(inspection.ownedBlocks.last.route, PluginRoute.proxy);
      expect(inspection.conflictingDomains, isEmpty);
      expect(inspection.unknownPolicyDomains, isEmpty);
      expect(inspection.unrecognizedRuleCount, 0);
      expect(expected.first.generatedAt, DateTime.utc(2026, 11, 3));
    },
  );

  test(
    'BOM, CRLF, case, spacing and ordinary comments do not alter content checks',
    () {
      final input =
          '\uFEFF[general] // ignored section note\r\nserver=never retained\r\n[ rUlE ] # section note\r\n'
          '# A renamed plugin - begin breeze plugin PLUGIN-A\r\n'
          '# ordinary comment mentioning Breeze plugin support\r\n'
          '; DOMAIN,api.example.com,PROXY\r\n'
          ' domain , API.EXAMPLE.COM , direct # inline note\r\n'
          'DOMAIN,img.example.com,DIRECT ; inline note\r\n'
          '# a RENAMED plugin - END BREEZE PLUGIN plugin-a\r\n';
      final inspection = inspectRoutingConfiguration(input, [record(a)]);
      expect(
        inspection.statusBySource[a.id],
        RoutingConfigurationMatch.matching,
      );
      expect(inspection.ownedBlocks.single.source.id, a.id);
      expect(inspection.ownedBlocks.single.source.name, 'A renamed plugin');
      expect(inspection.unrecognizedRuleCount, 0);
    },
  );

  test(
    'previously unknown marked source can be recovered without inventing a timestamp',
    () {
      final inspection = inspectRoutingConfiguration(
        config(block(b, PluginRoute.proxy)),
        [],
      );
      expect(inspection.ownedBlocks.single.source.id, b.id);
      expect(inspection.ownedBlocks.single.source.name, b.name);
      expect(inspection.ownedBlocks.single.route, PluginRoute.proxy);
      expect(
        inspection.statusBySource[b.id],
        RoutingConfigurationMatch.matching,
      );
    },
  );

  test(
    'unmarked DOMAIN checks known expectations but never guesses a recoverable plugin',
    () {
      const body =
          'DOMAIN,api.example.com,DIRECT\nDOMAIN,img.example.com,DIRECT';
      final known = inspectRoutingConfiguration(config(body), [record(a)]);
      expect(known.ownedBlocks, isEmpty);
      expect(known.statusBySource[a.id], RoutingConfigurationMatch.matching);
      final unknown = inspectRoutingConfiguration(config(body), []);
      expect(unknown.ownedBlocks, isEmpty);
      expect(unknown.statusBySource, isEmpty);
    },
  );

  test(
    'unnamed legacy plugin markers use known name or their explicit ID, never an inferred comment',
    () {
      const body =
          '# BEGIN BREEZE PLUGIN plugin-a\n# A comment is not an identity\n'
          'DOMAIN,api.example.com,DIRECT\nDOMAIN,img.example.com,DIRECT\n# END BREEZE PLUGIN plugin-a';
      expect(
        inspectRoutingConfiguration(config(body), [
          record(a),
        ]).ownedBlocks.single.source.name,
        a.name,
      );
      expect(
        inspectRoutingConfiguration(
          config(body),
          [],
        ).ownedBlocks.single.source.name,
        a.id,
      );
    },
  );

  test('legacy shared network markers do not manufacture source ownership', () {
    final body =
        '$routingRuleBlockStart\nDOMAIN,api.example.com,DIRECT\nDOMAIN,img.example.com,DIRECT\n$routingRuleBlockEnd';
    final value = inspectRoutingConfiguration(config(body), [record(a)]);
    expect(value.ownedBlocks, isEmpty);
    expect(value.statusBySource[a.id], RoutingConfigurationMatch.matching);
  });

  test(
    'missing means no expected exact host; partially present content is different',
    () {
      expect(state(''), RoutingConfigurationMatch.missing);
      expect(
        state('DOMAIN,unrelated.example.com,DIRECT'),
        RoutingConfigurationMatch.missing,
      );
      expect(
        state('DOMAIN,api.example.com,DIRECT'),
        RoutingConfigurationMatch.different,
      );
      expect(
        state('DOMAIN,api.example.com,PROXY\nDOMAIN,img.example.com,PROXY'),
        RoutingConfigurationMatch.different,
      );
    },
  );

  test(
    'owned extra/missing domains and changed policy are different despite matching rules elsewhere',
    () {
      final extra = RoutingSource(a.id, 'renamed', [
        ...a.domains,
        'extra.example.com',
      ]);
      expect(state(block(extra)), RoutingConfigurationMatch.different);
      expect(
        state(block(RoutingSource(a.id, a.name, [a.domains.first]))),
        RoutingConfigurationMatch.different,
      );
      expect(
        state(block(a, PluginRoute.proxy)),
        RoutingConfigurationMatch.different,
      );
      expect(
        state(
          '${block(RoutingSource(a.id, a.name, ['extra.example.com']))}\n'
          'DOMAIN,api.example.com,DIRECT\nDOMAIN,img.example.com,DIRECT',
        ),
        RoutingConfigurationMatch.different,
      );
      expect(
        state(block(RoutingSource(a.id, 'renamed', a.domains))),
        RoutingConfigurationMatch.matching,
      );
    },
  );

  test(
    'same host with multiple outbounds conflicts even outside an otherwise correct owned block',
    () {
      final value = inspectRoutingConfiguration(
        config('${block(a)}\nDOMAIN,api.example.com,PROXY'),
        [record(a)],
      );
      expect(value.statusBySource[a.id], RoutingConfigurationMatch.conflicting);
      expect(value.conflictingDomains, {'api.example.com'});
      expect(value.ownedBlocks.single.route, PluginRoute.direct);
    },
  );

  test(
    'cross-source conflicts also flag unrecorded owned sources before recovery',
    () {
      const shared = RoutingSource('shared', 'Shared', ['api.example.com']);
      final value = inspectRoutingConfiguration(
        config('${block(a)}\n${block(shared, PluginRoute.proxy)}'),
        [record(a)],
      );
      expect(value.statusBySource, {
        a.id: RoutingConfigurationMatch.conflicting,
        shared.id: RoutingConfigurationMatch.conflicting,
      });
      expect(value.conflictingDomains, {'api.example.com'});
    },
  );

  test(
    'same-policy duplicate rules and shared hosts do not create false conflicts',
    () {
      final value = inspectRoutingConfiguration(
        config('${block(a)}\nDOMAIN,API.EXAMPLE.COM,direct'),
        [record(a)],
      );
      expect(value.statusBySource[a.id], RoutingConfigurationMatch.matching);
      expect(value.conflictingDomains, isEmpty);
    },
  );

  for (final strategy in [
    'AUTO',
    'Proxy group',
    'PROXY-other',
    'PROXY#private-node',
    'REJECT',
    '',
  ]) {
    test('unknown policy is never silently PROXY: $strategy', () {
      const source = RoutingSource('one', 'One', ['api.example.com']);
      final value = inspectRoutingConfiguration(
        config('DOMAIN,api.example.com,$strategy'),
        [record(source, PluginRoute.proxy)],
      );
      expect(
        value.statusBySource[source.id],
        RoutingConfigurationMatch.different,
      );
      expect(value.unknownPolicyDomains, {'api.example.com'});
      expect(value.unrecognizedRuleCount, 1);
      expect(value.ownedBlocks, isEmpty);
    });
  }

  test(
    'unknown and known outbounds for one host conflict rather than guessing a winner',
    () {
      final value = inspectRoutingConfiguration(
        config('DOMAIN,api.example.com,AUTO\nDOMAIN,api.example.com,DIRECT'),
        [record(a)],
      );
      expect(value.statusBySource[a.id], RoutingConfigurationMatch.conflicting);
      expect(value.conflictingDomains, {'api.example.com'});
      expect(value.unknownPolicyDomains, {'api.example.com'});
    },
  );

  test(
    'unsupported options and other rule kinds do not imply complete traffic routing',
    () {
      const source = RoutingSource('one', 'One', ['api.example.com']);
      final value = inspectRoutingConfiguration(
        config(
          'DOMAIN,api.example.com,DIRECT,no-resolve\n'
          'DOMAIN-SUFFIX,example.com,PROXY\nIP-CIDR,10.0.0.0/8,DIRECT\n'
          'RULE-SET,https://private.invalid/secret-token,private-node\nFINAL,PROXY',
        ),
        [record(source)],
      );
      expect(
        value.statusBySource[source.id],
        RoutingConfigurationMatch.different,
      );
      expect(value.unrecognizedRuleCount, 5);
      expect(value.hasUnrecognizedRules, isTrue);
      expect(value.unknownPolicyDomains, isEmpty);
      expect(value.ownedBlocks, isEmpty);
      expect(
        state('DOMAIN-SUFFIX,example.com,PROXY'),
        RoutingConfigurationMatch.missing,
      );
    },
  );

  test(
    'matching exact content still reports unanalysed rules and is not a routing-order verdict',
    () {
      final result = inspectRoutingConfiguration(
        config('FINAL,PROXY\n${block(a)}'),
        [record(a)],
      );
      expect(result.statusBySource[a.id], RoutingConfigurationMatch.matching);
      expect(result.hasUnrecognizedRules, isTrue);
      expect(result.unrecognizedRuleCount, 1);
    },
  );

  test(
    'only Rule is inspected; server data and other sections are never returned',
    () {
      final input =
          '[Proxy]\nprivate-node=password-that-must-not-be-returned\n'
          'DOMAIN,api.example.com,PROXY\n[Rule]\n${block(a)}\n[Host]\nDOMAIN,api.example.com,PROXY';
      final result = inspectRoutingConfiguration(input, [record(a)]);
      expect(result.statusBySource[a.id], RoutingConfigurationMatch.matching);
      expect(result.conflictingDomains, isEmpty);
      expect(result.unrecognizedRuleCount, 0);
      expect(result.ownedBlocks.single.source.name, a.name);
      expect(
        jsonEncode(
          result.ownedBlocks.map((value) => value.source.toJson()).toList(),
        ),
        isNot(contains('password-that')),
      );
    },
  );

  test(
    'custom strategy in an owned block is different, not a malformed file or an inferred PROXY',
    () {
      const strategy = '🚀 自定义节点选择';
      final custom = block(
        a,
        PluginRoute.proxy,
      ).replaceAll(',PROXY', ',$strategy');
      final result = inspectRoutingConfiguration(
        config('$custom\n${block(b)}'),
        [record(a, PluginRoute.proxy), record(b)],
      );
      expect(result.ownedBlocks.map((value) => value.source.id), [b.id]);
      expect(result.statusBySource, {
        a.id: RoutingConfigurationMatch.different,
        b.id: RoutingConfigurationMatch.matching,
      });
      expect(result.unknownPolicyDomains, a.domains.toSet());
      expect(result.conflictingDomains, isEmpty);
      expect(result.unrecognizedRuleCount, 2);
      final summary = jsonEncode({
        'blocks': result.ownedBlocks
            .map((value) => value.source.toJson())
            .toList(),
        'statuses': result.statusBySource.map(
          (id, value) => MapEntry(id, value.name),
        ),
        'unknown': result.unknownPolicyDomains.toList(),
      });
      expect(
        summary,
        isNot(contains(strategy)),
        reason: 'the opaque group name is never retained in the inspection',
      );
    },
  );

  test(
    'an unknown custom-policy source has no recoverable block or invented matching entry',
    () {
      final custom = block(a).replaceAll(',DIRECT', ',My Private Group');
      final result = inspectRoutingConfiguration(
        config('$custom\n${block(b, PluginRoute.proxy)}'),
        [],
      );
      expect(result.ownedBlocks.map((value) => value.source.id), [b.id]);
      expect(result.statusBySource, {b.id: RoutingConfigurationMatch.matching});
      expect(result.unknownPolicyDomains, a.domains.toSet());
      expect(
        () => inspectRoutingConfiguration(config('$custom\n$custom'), []),
        throwsFormatException,
        reason:
            'unrecoverable policy cannot bypass duplicate ownership validation',
      );
    },
  );

  test(
    'mixed known outbounds across separate domains decline only that source recovery',
    () {
      final mixed = block(a).replaceFirst(
        'DOMAIN,img.example.com,DIRECT',
        'DOMAIN,img.example.com,PROXY',
      );
      final result = inspectRoutingConfiguration(
        config('$mixed\n${block(b)}'),
        [record(a), record(b)],
      );
      expect(result.ownedBlocks.map((value) => value.source.id), [b.id]);
      expect(result.statusBySource[a.id], RoutingConfigurationMatch.different);
      expect(result.statusBySource[b.id], RoutingConfigurationMatch.matching);
      expect(result.conflictingDomains, isEmpty);
      expect(result.unknownPolicyDomains, isEmpty);
      expect(
        result.hasUnrecognizedRules,
        isTrue,
        reason:
            'the mixed block is not represented by a uniform source snapshot',
      );
      final unknown = inspectRoutingConfiguration(config(mixed), []);
      expect(unknown.ownedBlocks, isEmpty);
      expect(unknown.statusBySource, isEmpty);
    },
  );

  for (final other in ['PROXY', 'My Private Group']) {
    test(
      'same-host mixed owned policies produce a real conflict without recovery: $other',
      () {
        final mixed =
            '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,DIRECT\n'
            'DOMAIN,api.example.com,$other\n# END BREEZE PLUGIN plugin-a';
        final result = inspectRoutingConfiguration(
          config('$mixed\n${block(b)}'),
          [record(a), record(b)],
        );
        expect(
          result.statusBySource[a.id],
          RoutingConfigurationMatch.conflicting,
        );
        expect(result.conflictingDomains, {'api.example.com'});
        expect(result.ownedBlocks.map((value) => value.source.id), [b.id]);
        expect(result.statusBySource[b.id], RoutingConfigurationMatch.matching);
        if (other != 'PROXY')
          expect(result.unknownPolicyDomains, {'api.example.com'});
      },
    );
  }

  test(
    'unrecoverable ownership still compares its extra domains, rather than falling back to missing',
    () {
      final edited =
          '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,extra.example.com,My Group\n# END BREEZE PLUGIN plugin-a';
      expect(
        inspectRoutingConfiguration(config(edited), [
          record(a),
        ]).statusBySource[a.id],
        RoutingConfigurationMatch.different,
      );
      final result = inspectRoutingConfiguration(
        config('$edited\nDOMAIN,extra.example.com,PROXY'),
        [record(a)],
      );
      expect(result.ownedBlocks, isEmpty);
      expect(
        result.statusBySource[a.id],
        RoutingConfigurationMatch.conflicting,
      );
      expect(result.conflictingDomains, {'extra.example.com'});
    },
  );

  final badBodies = <String>[
    '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,DIRECT',
    '# END BREEZE PLUGIN plugin-a',
    '# BEGIN BREEZE PLUGIN plugin-a\n# BEGIN BREEZE PLUGIN plugin-b\n# END BREEZE PLUGIN plugin-b',
    '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,DIRECT\n# END BREEZE PLUGIN plugin-b',
    '# A - BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,DIRECT\n# B - END BREEZE PLUGIN plugin-a',
    '${block(a)}\n${block(a)}',
    '${block(a)}\n${block(a).replaceAll('plugin-a', 'PLUGIN-A')}',
    '# BEGIN BREEZE PLUGIN plugin-a\n# only comments\n# END BREEZE PLUGIN plugin-a',
    '# BEGIN BREEZE PLUGIN invalid/id\nDOMAIN,api.example.com,DIRECT\n# END BREEZE PLUGIN invalid/id',
    '# BEGIN BREEZE PLUGIN plugin-a EXTRA\nDOMAIN,api.example.com,DIRECT\n# END BREEZE PLUGIN plugin-a',
    '# A -BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,DIRECT\n# A -END BREEZE PLUGIN plugin-a',
    '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,\n# END BREEZE PLUGIN plugin-a',
    '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN-SUFFIX,example.com,DIRECT\n# END BREEZE PLUGIN plugin-a',
    '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,DIRECT,no-resolve\n# END BREEZE PLUGIN plugin-a',
    '# BEGIN BREEZE PLUGIN plugin-a\nDOMAIN,api.example.com,DIRECT\n[Host]\n# END BREEZE PLUGIN plugin-a',
  ];
  for (var i = 0; i < badBodies.length; i++) {
    test('ambiguous or unsupported owned block rejects atomically: $i', () {
      expect(
        () => inspectRoutingConfiguration(config(badBodies[i]), [record(a)]),
        throwsFormatException,
      );
    });
  }

  for (final host in [
    'https://api.example.com',
    '*.example.com',
    '127.0.0.1',
    'host.local',
    '.example.com',
  ]) {
    test('invalid owned public host is rejected: $host', () {
      final body =
          '# BEGIN BREEZE PLUGIN one\nDOMAIN,$host,DIRECT\n# END BREEZE PLUGIN one';
      expect(
        () => inspectRoutingConfiguration(config(body), []),
        throwsFormatException,
      );
      final outside = inspectRoutingConfiguration(
        config('DOMAIN,$host,DIRECT'),
        [record(a)],
      );
      expect(outside.statusBySource[a.id], RoutingConfigurationMatch.missing);
      expect(outside.unrecognizedRuleCount, 1);
    });
  }

  test(
    'one valid Rule section is mandatory, with no owned markers in other sections',
    () {
      for (final text in [
        '',
        '[General]\na=b',
        '[Rule]\n[rule]\n',
        '[Rule]\n[Host]\n[Rule]#comment',
        '[Rule]bad\n',
        '[General]\n${block(a)}\n[Rule]\n',
        '[Rule]\n[Host]\n${block(a)}',
        '[Rule]\n\u0000',
      ]) {
        expect(
          () => inspectRoutingConfiguration(text, []),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'limits apply to UTF-8 bytes, expected/owned sources and source domains',
    () {
      final atLimit = '[Rule]\n#${'x' * (2 * 1024 * 1024 - 8)}';
      expect(utf8.encode(atLimit), hasLength(2 * 1024 * 1024));
      expect(inspectRoutingConfiguration(atLimit, []).ownedBlocks, isEmpty);
      expect(
        () => inspectRoutingConfiguration(
          '[Rule]\n${'x' * (2 * 1024 * 1024)}',
          [],
        ),
        throwsFormatException,
      );
      expect(
        () => inspectRoutingConfiguration(
          '[Rule]\n#${'汉' * (2 * 1024 * 1024 ~/ 3)}',
          [],
        ),
        throwsFormatException,
      );
      expect(
        () => inspectRoutingConfiguration('[Rule]\n#\uFEFF', []),
        throwsFormatException,
      );
      final domains = [for (var i = 0; i < 200; i++) 'd$i.example.com'];
      final source = RoutingSource('limit', 'Limit', domains);
      expect(
        inspectRoutingConfiguration(config(block(source)), [
          record(source),
        ]).ownedBlocks.single.source.domains,
        hasLength(200),
      );
      final excess = RoutingSource('limit', 'Limit', [
        ...domains,
        'overflow.example.com',
      ]);
      expect(
        () => inspectRoutingConfiguration(config(block(excess)), []),
        throwsFormatException,
      );
      expect(
        () => inspectRoutingConfiguration('[Rule]', [record(excess)]),
        throwsFormatException,
      );
      final sources = [
        for (var i = 0; i < 101; i++)
          RoutingSource('p$i', 'Plugin $i', ['d$i.example.com']),
      ];
      expect(
        inspectRoutingConfiguration(
          config(sources.take(100).map((value) => block(value)).join('\n')),
          [],
        ).ownedBlocks,
        hasLength(100),
      );
      expect(
        () => inspectRoutingConfiguration(
          config(sources.map((value) => block(value)).join('\n')),
          [],
        ),
        throwsFormatException,
      );
      expect(
        () => inspectRoutingConfiguration(
          '[Rule]',
          sources.map((value) => record(value)).toList(),
        ),
        throwsFormatException,
      );
      expect(
        () => inspectRoutingConfiguration(
          config(sources.skip(60).map((value) => block(value)).join('\n')),
          sources.take(60).map((value) => record(value)).toList(),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'invalid expected identity, name, policy or duplicate snapshots cannot be silently compared',
    () {
      for (final source in [
        const RoutingSource('bad/id', 'Bad', ['a.example.com']),
        const RoutingSource('bad\n', 'Bad', ['a.example.com']),
        const RoutingSource('valid', '', ['a.example.com']),
        const RoutingSource('valid', 'bad\u202ename', ['a.example.com']),
        const RoutingSource('valid', 'Valid', []),
      ]) {
        expect(
          () => inspectRoutingConfiguration('[Rule]', [record(source)]),
          throwsFormatException,
        );
      }
      expect(
        () => inspectRoutingConfiguration('[Rule]', [
          record(a, PluginRoute.existing),
        ]),
        throwsFormatException,
      );
      expect(
        () => inspectRoutingConfiguration('[Rule]', [record(a), record(a)]),
        throwsFormatException,
      );
    },
  );

  test(
    'inspection snapshots are immutable and do not mutate expected inputs',
    () {
      final domains = ['IMG.EXAMPLE.COM', 'api.example.com'];
      final source = RoutingSource(a.id, a.name, domains);
      final before = domains.toList();
      final value = inspectRoutingConfiguration(config(block(a)), [
        record(source),
      ]);
      expect(domains, before);
      expect(() => value.ownedBlocks.clear(), throwsUnsupportedError);
      expect(
        () =>
            value.ownedBlocks.single.source.domains.add('injected.example.com'),
        throwsUnsupportedError,
      );
      expect(() => value.statusBySource.clear(), throwsUnsupportedError);
      expect(
        () => value.conflictingDomains.add('injected.example.com'),
        throwsUnsupportedError,
      );
      domains.clear();
      expect(value.ownedBlocks.single.source.domains, hasLength(2));
    },
  );
}
