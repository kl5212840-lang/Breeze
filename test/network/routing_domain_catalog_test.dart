import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_catalog.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'extraction and confirmation persist independently of generation',
    () async {
      final base = routingSources[4];
      await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(base.id, base.name, ['fresh.source.tv', 'empty.invalid']),
      );
      var restored = await RoutingDomainCatalogStore.read();
      expect(restored.pendingFor(base), ['fresh.source.tv']);
      expect(restored.domainsFor(base), base.domains.toList()..sort());
      expect(
        restored.scannedDomains[base.id],
        isNot(contains('empty.invalid')),
      );
      await RoutingDomainCatalogStore.confirmDomain(
        base.id,
        'fresh.source.tv',
        true,
      );
      restored = await RoutingDomainCatalogStore.read();
      expect(restored.domainsFor(base), contains('fresh.source.tv'));
      expect(restored.pendingFor(base), isEmpty);
      await RoutingDomainCatalogStore.confirmDomain(
        base.id,
        'fresh.source.tv',
        false,
      );
      expect((await RoutingDomainCatalogStore.read()).pendingFor(base), [
        'fresh.source.tv',
      ]);
    },
  );

  test(
    'simultaneous source refreshes and confirmations do not overwrite each other',
    () async {
      const a = RoutingSource('external-a', 'A', ['a.source.tv']);
      const b = RoutingSource('external-b', 'B', ['b.source.tv']);
      await Future.wait([
        RoutingDomainCatalogStore.saveScannedSource(a),
        RoutingDomainCatalogStore.saveScannedSource(b),
      ]);
      await Future.wait([
        RoutingDomainCatalogStore.confirmDomain(a.id, a.domains.single, true),
        RoutingDomainCatalogStore.confirmDomain(b.id, b.domains.single, true),
      ]);
      final restored = await RoutingDomainCatalogStore.read();
      expect(restored.scannedDomains[a.id], a.domains);
      expect(restored.scannedDomains[b.id], b.domains);
      expect(restored.confirmedDomains[a.id], a.domains);
      expect(restored.confirmedDomains[b.id], b.domains);
    },
  );

  test(
    'a late generation draft cannot resurrect a replaced extraction',
    () async {
      final base = routingSources.first;
      final stale = await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(base.id, base.name, ['old.source.tv']),
      );
      await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(base.id, base.name, ['new.source.tv']),
      );
      await expectLater(
        RoutingDomainCatalogStore.saveSources(stale, {base.id}),
        throwsStateError,
      );
      expect((await RoutingDomainCatalogStore.read()).scannedDomains[base.id], [
        'new.source.tv',
      ]);
    },
  );

  test(
    'legacy extracted hosts require review while manual entries remain included',
    () async {
      final base = routingSources.first;
      SharedPreferences.setMockInitialValues({
        'breeze.routing.domains.v3': jsonEncode({
          'scannedDomains': {
            base.id: ['old.source.tv', 'empty.invalid'],
          },
          'extraDomains': {
            base.id: ['manual.source.tv'],
          },
        }),
      });
      final restored = await RoutingDomainCatalogStore.read();
      expect(restored.pendingFor(base), ['old.source.tv']);
      expect(restored.domainsFor(base), contains('manual.source.tv'));
      expect(restored.domainsFor(base), isNot(contains('old.source.tv')));
      expect(restored.domainsFor(base), isNot(contains('empty.invalid')));
    },
  );

  test(
    'refresh replaces extracted hosts without approving new ones or removing manual domains',
    () async {
      final base = routingSources.first;
      var saved = await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(base.id, base.name, ['before.source.tv']),
      );
      saved = await RoutingDomainCatalogStore.confirmDomain(
        base.id,
        'before.source.tv',
        true,
      );
      await RoutingDomainCatalogStore.saveSources(
        saved.withSource(base.id, PluginRoute.direct, ['manual.source.tv']),
        {base.id},
      );
      await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(base.id, base.name, ['after.source.tv']),
      );
      final restored = await RoutingDomainCatalogStore.read();
      expect(restored.domainsFor(base), contains('manual.source.tv'));
      expect(restored.domainsFor(base), isNot(contains('before.source.tv')));
      expect(restored.domainsFor(base), isNot(contains('after.source.tv')));
      expect(restored.pendingFor(base), ['after.source.tv']);
      await expectLater(
        RoutingDomainCatalogStore.confirmDomain(
          base.id,
          'before.source.tv',
          true,
        ),
        throwsFormatException,
      );
    },
  );
}
