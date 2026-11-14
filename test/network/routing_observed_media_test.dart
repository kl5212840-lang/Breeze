import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_catalog.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/routing_rule_output.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = routingSources.first;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'parsed media and real redirects are host-only, source scoped and require review',
    () async {
      await RoutingObservedMediaDomains.observeResolved(
        source: source.id,
        media: [
          Uri.parse('https://v.fengbao14.com/private/master.m3u8?token=SECRET'),
        ],
      );
      await RoutingObservedMediaDomains.observe(
        source: source.id,
        requested: Uri.parse(
          'https://v.fengbao14.com/private/segment.ts?token=SECRET',
        ),
        responseUrl: Uri.parse(
          'https://edge.actual-cdn.tv/private/segment.ts?signature=SECRET',
        ),
        status: 200,
      );
      var plan = await RoutingDomainCatalogStore.read();
      expect(plan.pendingFor(source), [
        'edge.actual-cdn.tv',
        'v.fengbao14.com',
      ]);
      expect(plan.domainsFor(source), isNot(contains('v.fengbao14.com')));
      expect(plan.choices, isEmpty);
      expect((await RoutingObservedMediaDomains.read()).keys, [source.id]);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(RoutingObservedMediaDomains.storageKey)!;
      expect(raw, isNot(contains('SECRET')));
      expect(raw, isNot(contains('private')));
      expect(raw, isNot(contains('https:')));
      expect(raw, contains('response'));
      await RoutingDomainCatalogStore.confirmDomain(
        source.id,
        'v.fengbao14.com',
        true,
      );
      plan = (await RoutingDomainCatalogStore.read()).withSource(
        source.id,
        PluginRoute.direct,
        ['manual.source.tv'],
      );
      await RoutingDomainCatalogStore.saveSources(plan, {source.id});
      final other = routingSources[1];
      final otherBlock = routingRuleBlockFor(
        other,
        PluginRoute.proxy,
        other.domains,
      );
      final original =
          '[Proxy]\nNODE=original-private-config\n[Rule]\n$otherBlock\nFINAL,PROXY\n[Host]\ncustom=value\n';
      final merged = mergeSelectedRoutingRules(original, plan, [source.id]);
      expect(merged, contains('DOMAIN,v.fengbao14.com,DIRECT'));
      expect(merged, contains('DOMAIN,manual.source.tv,DIRECT'));
      expect(merged, isNot(contains('DOMAIN,edge.actual-cdn.tv')));
      expect(merged, isNot(contains('DOMAIN-SUFFIX')));
      expect(merged, contains(otherBlock));
      expect(merged, contains('NODE=original-private-config'));
      expect(merged, endsWith('[Host]\ncustom=value\n'));
      // Runtime snapshots remain separate from literal plugin declarations.
      final base =
          jsonDecode(prefs.getString('breeze.routing.domains.v3')!) as Map;
      expect('${base['scannedDomains']}', isNot(contains('v.fengbao14.com')));
    },
  );

  test(
    'failed and unsafe requests cannot add candidates; segments coalesce writes',
    () async {
      for (final url in [
        'http://plain.source.tv/a',
        'https://127.0.0.1/a',
        'https://user:secret@cdn.source.tv/a',
        'https://cdn.source.tv:8443/a',
        'https://empty.invalid/a',
        'https://github.com/a',
        'https://host.local/a',
      ]) {
        await RoutingObservedMediaDomains.observeResolved(
          source: source.id,
          media: [Uri.parse(url)],
        );
      }
      await RoutingObservedMediaDomains.observe(
        source: source.id,
        requested: Uri.parse('https://failed.source.tv/a'),
        responseUrl: Uri.parse('https://failed.source.tv/a'),
        status: 403,
      );
      expect(await RoutingObservedMediaDomains.read(), isEmpty);
      final requests = List.generate(
        20,
        (i) => RoutingObservedMediaDomains.observe(
          source: source.id,
          requested: Uri.parse('https://live.source.tv/segment$i.ts?secret=$i'),
          responseUrl: Uri.parse(
            'https://live.source.tv/segment$i.ts?secret=$i',
          ),
          status: 206,
        ),
      );
      await Future.wait(requests);
      final prefs = await SharedPreferences.getInstance();
      final first = prefs.getString(RoutingObservedMediaDomains.storageKey);
      await RoutingObservedMediaDomains.observe(
        source: source.id,
        requested: Uri.parse('https://live.source.tv/next.ts'),
        responseUrl: Uri.parse('https://live.source.tv/next.ts'),
        status: 200,
      );
      expect(prefs.getString(RoutingObservedMediaDomains.storageKey), first);
      expect(
        (await RoutingObservedMediaDomains.read())[source.id]!.single.host,
        'live.source.tv',
      );
    },
  );

  test(
    'late observations fence generation drafts while refresh preserves manual choices',
    () async {
      await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(source.id, source.name, ['literal.source.tv']),
      );
      var draft = await RoutingDomainCatalogStore.read();
      draft = draft.withSource(source.id, PluginRoute.proxy, [
        'manual.source.tv',
      ]);
      await RoutingDomainCatalogStore.saveSources(draft, {source.id});
      await RoutingObservedMediaDomains.observeResolved(
        source: source.id,
        media: [Uri.parse('https://fresh.source.tv/media')],
      );
      await expectLater(
        RoutingDomainCatalogStore.saveSources(draft, {source.id}),
        throwsA(isA<RoutingCatalogChanged>()),
      );
      await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(source.id, source.name, ['new-literal.source.tv']),
      );
      var fresh = await RoutingDomainCatalogStore.read();
      expect(fresh.pendingFor(source), [
        'fresh.source.tv',
        'new-literal.source.tv',
      ]);
      expect(fresh.extraDomains[source.id], ['manual.source.tv']);
      expect(fresh.choices, isEmpty);
      await Future.wait([
        RoutingDomainCatalogStore.confirmDomain(
          source.id,
          'fresh.source.tv',
          true,
        ),
        RoutingObservedMediaDomains.observeResolved(
          source: source.id,
          media: [Uri.parse('https://second.source.tv/media')],
        ),
      ]);
      fresh = await RoutingDomainCatalogStore.read();
      expect(fresh.domainsFor(source), contains('fresh.source.tv'));
      expect(fresh.pendingFor(source), contains('second.source.tv'));
    },
  );

  test(
    'saved domains survive time and overflow never evicts an earlier snapshot',
    () async {
      final now = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        RoutingObservedMediaDomains.storageKey: jsonEncode({
          source.id: [
            {
              'host': 'expired.source.tv',
              'at': now
                  .subtract(const Duration(days: 31))
                  .millisecondsSinceEpoch,
              'evidence': ['resolved'],
            },
            {
              'host': 'fresh.source.tv',
              'at': now
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
              'evidence': ['response'],
            },
          ],
        }),
      });
      expect(
        (await RoutingObservedMediaDomains.read())[source.id]!.map(
          (r) => r.host,
        ),
        ['expired.source.tv', 'fresh.source.tv'],
      );
      for (var i = 0; i < 10; i++) {
        await RoutingObservedMediaDomains.observeResolved(
          source: source.id,
          media: List.generate(
            8,
            (j) => Uri.parse('https://edge${i * 8 + j}.source.tv/media'),
          ),
        );
      }
      expect(
        (await RoutingObservedMediaDomains.read())[source.id],
        hasLength(82),
      );
      final before = (await SharedPreferences.getInstance()).getString(
        RoutingObservedMediaDomains.storageKey,
      );
      expect(
        await RoutingObservedMediaDomains.observeHosts(
          source.id,
          List.generate(
            RoutingObservedMediaDomains.maxHosts + 1,
            (index) => 'overflow$index.source.tv',
          ),
        ),
        isFalse,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          RoutingObservedMediaDomains.storageKey,
        ),
        before,
      );
    },
  );

  test(
    'only a complete successful probe replaces its source snapshot',
    () async {
      final other = routingSources[1];
      await RoutingObservedMediaDomains.observeHosts(source.id, [
        'old.source.tv',
      ]);
      await RoutingObservedMediaDomains.observeHosts(other.id, [
        'other.source.tv',
      ]);
      await RoutingDomainCatalogStore.confirmDomain(
        source.id,
        'old.source.tv',
        true,
      );
      final initial = (await RoutingDomainCatalogStore.read()).withSource(
        source.id,
        PluginRoute.direct,
        ['manual.source.tv'],
      );
      await RoutingDomainCatalogStore.saveSources(initial, {source.id});
      await RoutingObservedMediaDomains.commitProbe(
        source: source.id,
        domains: ['partial.source.tv'],
        complete: false,
      );
      expect(
        (await RoutingObservedMediaDomains.read())[source.id]!.map(
          (row) => row.host,
        ),
        containsAll(['old.source.tv', 'partial.source.tv']),
      );
      await expectLater(
        RoutingObservedMediaDomains.commitProbe(
          source: source.id,
          domains: [],
          complete: true,
        ),
        throwsFormatException,
      );
      await RoutingObservedMediaDomains.commitProbe(
        source: source.id,
        domains: ['current.source.tv'],
        complete: true,
      );
      final snapshot = await RoutingObservedMediaDomains.read();
      expect(snapshot[source.id]!.map((row) => row.host), [
        'current.source.tv',
      ]);
      expect(snapshot[other.id]!.single.host, 'other.source.tv');
      final plan = await RoutingDomainCatalogStore.read();
      expect(plan.extraDomains[source.id], ['manual.source.tv']);
      expect(plan.pendingFor(source), contains('current.source.tv'));
      expect(plan.domainsFor(source), isNot(contains('current.source.tv')));
    },
  );

  test(
    'probe scopes stage data and discard errors and late callbacks',
    () async {
      final late = Completer<void>();
      late Future<bool> oldCallback;
      final staged = await RoutingObservedMediaDomains.capture(
        source.id,
        () async {
          await RoutingObservedMediaDomains.observeHosts(source.id, [
            'staged.source.tv',
          ]);
          oldCallback = late.future.then(
            (_) => RoutingObservedMediaDomains.observeHosts(source.id, [
              'late.source.tv',
            ]),
          );
          return 'public result';
        },
      );
      expect(staged.value, 'public result');
      expect(staged.domains, ['staged.source.tv']);
      expect(await RoutingObservedMediaDomains.read(), isEmpty);
      late.complete();
      expect(await oldCallback, isFalse);
      await expectLater(
        RoutingObservedMediaDomains.capture<void>(source.id, () async {
          await RoutingObservedMediaDomains.observeHosts(source.id, [
            'cancelled.source.tv',
          ]);
          throw StateError('cancelled');
        }),
        throwsStateError,
      );
      expect(await RoutingObservedMediaDomains.read(), isEmpty);
      await RoutingObservedMediaDomains.observeHosts(source.id, [
        'passive.source.tv',
      ]);
      expect(
        (await RoutingObservedMediaDomains.read())[source.id]!.single.host,
        'passive.source.tv',
      );
    },
  );
}
