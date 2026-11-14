import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_rule_output.dart';

void main() {
  final a = routingSources[0], b = routingSources[1];
  RoutingPlan plan(PluginRoute route) => RoutingPlan()
      .withSource(a.id, route, [])
      .withSource(b.id, PluginRoute.proxy, []);
  test('only explicit selection is emitted, even with historical choices', () {
    final out = selectedRoutingRuleBlocks(plan(PluginRoute.direct), [a.id]);
    expect(out, contains('# ${a.name} - BEGIN BREEZE PLUGIN ${a.id}'));
    expect(out, contains('# ${a.name} - END BREEZE PLUGIN ${a.id}'));
    expect(out, contains('DOMAIN,www.omofuna.com,DIRECT'));
    expect(out, isNot(contains('picaapi')));
    expect(
      () => selectedRoutingRuleBlocks(plan(PluginRoute.direct), []),
      throwsFormatException,
    );
  });
  test('NekoBox domains preserve exact matching, outbound and selection', () {
    const shared = RoutingSource('custom', 'Another plugin', [
      'www.omofuna.com',
      'cdn.example.org',
    ]);
    final mixed = RoutingPlan(customSources: {shared.id: shared})
        .withSource(a.id, PluginRoute.direct, [])
        .withSource(b.id, PluginRoute.proxy, [])
        .withSource(shared.id, PluginRoute.direct, []);
    final direct = selectedNekoBoxDomains(mixed, [
      a.id,
      b.id,
      shared.id,
    ], route: PluginRoute.direct).split('\n');
    expect(direct, contains('full:www.omofuna.com'));
    expect(direct, contains('full:cdn.example.org'));
    expect(
      direct.where((line) => line == 'full:www.omofuna.com'),
      hasLength(1),
    );
    expect(direct.any((line) => line.contains('picaapi')), isFalse);
    expect(direct.every((line) => line.startsWith('full:')), isTrue);
    expect(
      direct.any((line) => line.contains('DOMAIN,') || line.contains('#')),
      isFalse,
    );
    final proxy = selectedNekoBoxDomains(mixed, [
      a.id,
      b.id,
    ], route: PluginRoute.proxy);
    expect(proxy, contains('full:picaapi.picacomic.com'));
    expect(proxy, isNot(contains('omofuna')));
    expect(proxy, isNot(contains('cdn.example.org')));
    expect(
      selectedNekoBoxDomains(mixed, [a.id], route: PluginRoute.direct),
      isNot(contains('cdn.example.org')),
    );
  });
  test(
    'NekoBox refuses empty, stale, mixed-policy conflicts and missing hosts',
    () {
      final current = plan(PluginRoute.direct);
      for (final ids in [
        <String>[],
        ['missing'],
      ]) {
        expect(
          () => selectedNekoBoxDomains(current, ids, route: PluginRoute.direct),
          throwsFormatException,
        );
      }
      expect(
        () => selectedNekoBoxDomains(current, [a.id], route: PluginRoute.proxy),
        throwsFormatException,
      );
      expect(
        () => selectedNekoBoxDomains(current, [
          a.id,
        ], route: PluginRoute.existing),
        throwsFormatException,
      );
      const source = RoutingSource('overlap', 'Overlap', ['www.omofuna.com']);
      final conflict = RoutingPlan(customSources: {source.id: source})
          .withSource(a.id, PluginRoute.direct, [])
          .withSource(source.id, PluginRoute.proxy, []);
      expect(
        () => selectedNekoBoxDomains(conflict, [
          a.id,
          source.id,
        ], route: PluginRoute.direct),
        throwsA(isA<RoutingConflict>()),
      );
      const empty = RoutingSource('empty', 'Empty', []);
      expect(
        () => selectedNekoBoxDomains(
          RoutingPlan(
            customSources: {empty.id: empty},
          ).withSource(empty.id, PluginRoute.direct, []),
          [empty.id],
          route: PluginRoute.direct,
        ),
        throwsFormatException,
      );
    },
  );
  for (final nl in ['\n', '\r\n']) {
    test(
      'selected update is idempotent and leaves other plugin blocks intact ($nl)',
      () {
        final original =
            '[General]${nl}dns-server=system$nl[Rule]${nl}FINAL,PROXY$nl[Host]${nl}a=b$nl';
        final first = mergeSelectedRoutingRules(
          original,
          plan(PluginRoute.direct),
          [b.id],
        );
        final second = mergeSelectedRoutingRules(
          first,
          plan(PluginRoute.direct),
          [a.id],
        );
        final updated = mergeSelectedRoutingRules(
          second,
          plan(PluginRoute.proxy),
          [a.id],
        );
        final bBlock = selectedRoutingRuleBlocks(plan(PluginRoute.direct), [
          b.id,
        ]).replaceAll('\n', nl);
        expect(updated, contains(bBlock));
        expect(updated, contains('DOMAIN,www.omofuna.com,PROXY'));
        expect(updated, isNot(contains('DOMAIN,www.omofuna.com,DIRECT')));
        expect(
          mergeSelectedRoutingRules(updated, plan(PluginRoute.proxy), [a.id]),
          updated,
        );
        expect(updated.endsWith('[Host]${nl}a=b$nl'), isTrue);
        expect(updated.contains('\r\r'), isFalse);
      },
    );
  }
  test(
    'legacy migration changes selected hosts only and preserves unselected rules',
    () {
      final old = mergeShadowrocketConfig(
        '[Rule]\nFINAL,PROXY\n',
        plan(PluginRoute.direct),
      );
      final updated = mergeSelectedRoutingRules(old, plan(PluginRoute.proxy), [
        a.id,
      ]);
      expect('DOMAIN,www.omofuna.com,'.allMatches(updated).length, 1);
      expect(updated, contains('DOMAIN,picaapi.picacomic.com,PROXY'));
      expect(updated, contains(routingRuleBlockStart));
    },
  );
  test('unnamed owned blocks are updated without leaving duplicate rules', () {
    final original =
        '[Rule]\n# BEGIN BREEZE PLUGIN ${a.id}\n# ${a.name}\nDOMAIN,www.omofuna.com,DIRECT\n# END BREEZE PLUGIN ${a.id}\nFINAL,PROXY\n';
    final output = mergeSelectedRoutingRules(
      original,
      plan(PluginRoute.proxy),
      [a.id],
    );
    expect('DOMAIN,www.omofuna.com,'.allMatches(output).length, 1);
    expect(output, contains('# ${a.name} - BEGIN BREEZE PLUGIN ${a.id}'));
    expect(output, contains('# ${a.name} - END BREEZE PLUGIN ${a.id}'));
    expect(
      mergeSelectedRoutingRules(output, plan(PluginRoute.proxy), [a.id]),
      output,
    );
  });
  test('malformed blocks and duplicate sections fail without rewriting', () {
    for (final original in [
      '[Rule]\n[Rule]\n',
      '[Rule]\n# BEGIN BREEZE PLUGIN ${a.id}\nFINAL,PROXY\n',
    ]) {
      expect(
        () => mergeSelectedRoutingRules(original, plan(PluginRoute.direct), [
          a.id,
        ]),
        throwsFormatException,
      );
    }
  });
}
