import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_catalog.dart';
import 'package:zephyr/network/routing/routing_saved_rules.dart';

class _FailSavedWrite extends InMemorySharedPreferencesStore {
  _FailSavedWrite() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      key.endsWith(RoutingSavedRulesStore.storageKey)
      ? false
      : super.setValue(valueType, key, value);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final a = routingSources.first, b = routingSources[1];
  RoutingPlan plan(
    RoutingSource source,
    PluginRoute route, [
    List<String> extras = const [],
  ]) => RoutingPlan().withSource(source.id, route, extras);

  test('settled write barriers do not retain an earlier caller clock', () {
    String? persisted;
    var wrote = false;
    fakeAsync((clock) {
      SharedPreferences.setMockInitialValues({});
      RoutingSavedRulesStore.save(
        plan: plan(a, PluginRoute.direct),
        sources: [a],
        expectedRevisions: {},
      ).then((_) async {
        persisted = (await SharedPreferences.getInstance()).getString(
          RoutingSavedRulesStore.storageKey,
        );
        wrote = true;
      });
      clock.flushMicrotasks();
      expect(wrote, isTrue);
    });
    expect(persisted, isNotNull);
    fakeAsync((clock) {
      // A fresh preference instance mirrors the next widget-test host.
      SharedPreferences.setMockInitialValues({
        RoutingSavedRulesStore.storageKey: persisted!,
      });
      var read = false;
      RoutingSavedRulesStore.read().then((snapshot) {
        expect(snapshot.sources[a.id]!.route, PluginRoute.direct);
        read = true;
      });
      clock.flushMicrotasks();
      expect(
        read,
        isTrue,
        reason:
            'a completed write cannot schedule this read on the previous clock',
      );
    });
  });

  test(
    'v3 confirmations remain draft; explicit saved rules reopen in default domains',
    () async {
      await RoutingDomainCatalogStore.saveScannedSource(
        RoutingSource(a.id, a.name, ['fresh.source.tv']),
      );
      await RoutingDomainCatalogStore.confirmDomain(
        a.id,
        'fresh.source.tv',
        true,
      );
      expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
      final draft = (await RoutingDomainCatalogStore.read()).withSource(
        a.id,
        PluginRoute.proxy,
        ['manual.source.tv'],
      );
      await RoutingSavedRulesStore.save(
        plan: draft,
        sources: [a],
        expectedRevisions: {},
      );
      final reopened = await RoutingDomainCatalogStore.read();
      final source = reopened.sources.firstWhere((source) => source.id == a.id);
      expect(
        source.domains,
        containsAll([...a.domains, 'fresh.source.tv', 'manual.source.tv']),
      );
      expect(reopened.candidatesFor(source), isEmpty);
      expect(reopened.choices[a.id], PluginRoute.proxy);
      expect(
        reopened.extraDomains[a.id],
        isNull,
        reason: 'saved hosts are not another manual draft field',
      );
    },
  );

  test(
    'a new explicit snapshot supersedes old v3 manual and confirmed draft fields',
    () async {
      final legacy = RoutingPlan().withSource(a.id, PluginRoute.proxy, [
        'discard.source.tv',
      ]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'breeze.routing.domains.v3',
        jsonEncode(legacy.toJson()),
      );
      expect(
        (await RoutingDomainCatalogStore.read()).extraDomains[a.id],
        contains('discard.source.tv'),
      );
      await RoutingSavedRulesStore.save(
        plan: plan(a, PluginRoute.direct),
        sources: [a],
        expectedRevisions: {},
      );
      final reopened = await RoutingDomainCatalogStore.read();
      expect(reopened.domainsFor(a), isNot(contains('discard.source.tv')));
      expect(reopened.choices[a.id], PluginRoute.direct);
    },
  );

  test(
    'independent source saves merge and stale editors cannot replace a newer save',
    () async {
      await Future.wait([
        RoutingSavedRulesStore.save(
          plan: plan(a, PluginRoute.direct),
          sources: [a],
          expectedRevisions: {},
        ),
        RoutingSavedRulesStore.save(
          plan: plan(b, PluginRoute.proxy),
          sources: [b],
          expectedRevisions: {},
        ),
      ]);
      final initial = await RoutingSavedRulesStore.read();
      expect(initial.sources.keys, containsAll([a.id, b.id]));
      await RoutingSavedRulesStore.save(
        plan: plan(a, PluginRoute.existing),
        sources: [a],
        expectedRevisions: initial.revisions,
      );
      await expectLater(
        RoutingSavedRulesStore.save(
          plan: plan(a, PluginRoute.proxy),
          sources: [a],
          expectedRevisions: initial.revisions,
        ),
        throwsA(isA<RoutingSavedRulesChanged>()),
      );
      final reopened = await RoutingSavedRulesStore.read();
      expect(reopened.sources[a.id]!.route, PluginRoute.existing);
      expect(reopened.sources[b.id]!.route, PluginRoute.proxy);
    },
  );

  test('failed storage never reports or installs a saved snapshot', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _FailSavedWrite();
    try {
      await expectLater(
        RoutingSavedRulesStore.save(
          plan: plan(a, PluginRoute.direct),
          sources: [a],
          expectedRevisions: {},
        ),
        throwsStateError,
      );
      expect((await RoutingSavedRulesStore.read()).sources, isEmpty);
    } finally {
      SharedPreferencesStorePlatform.instance = previous;
    }
  });

  test(
    'freshness changing across the platform write rolls back only that snapshot',
    () async {
      await RoutingSavedRulesStore.save(
        plan: plan(b, PluginRoute.proxy),
        sources: [b],
        expectedRevisions: {},
      );
      var validations = 0;
      await expectLater(
        RoutingSavedRulesStore.save(
          plan: plan(a, PluginRoute.direct),
          sources: [a],
          expectedRevisions: {},
          validateFresh: () async {
            if (++validations == 2)
              throw StateError('new observation or plugin generation');
          },
        ),
        throwsStateError,
      );
      final reopened = await RoutingSavedRulesStore.read();
      expect(reopened.sources.containsKey(a.id), isFalse);
      expect(reopened.sources[b.id]!.route, PluginRoute.proxy);
      expect(validations, 2);
    },
  );

  test(
    'future formats reject reads and saves without overwriting the data',
    () async {
      final raw = jsonEncode({
        'version': 999,
        'sources': {'future': 'untouched'},
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(RoutingSavedRulesStore.storageKey, raw);
      await expectLater(RoutingSavedRulesStore.read(), throwsFormatException);
      await expectLater(
        RoutingSavedRulesStore.save(
          plan: plan(a, PluginRoute.direct),
          sources: [a],
          expectedRevisions: {},
        ),
        throwsFormatException,
      );
      expect(prefs.getString(RoutingSavedRulesStore.storageKey), raw);
    },
  );

  test(
    'saved conflicting exact hosts are rejected without replacing other sources',
    () async {
      await RoutingSavedRulesStore.save(
        plan: plan(a, PluginRoute.direct, ['shared.source.tv']),
        sources: [a],
        expectedRevisions: {},
      );
      await expectLater(
        RoutingSavedRulesStore.save(
          plan: plan(b, PluginRoute.proxy, ['shared.source.tv']),
          sources: [b],
          expectedRevisions: {},
        ),
        throwsA(isA<RoutingConflict>()),
      );
      final reopened = await RoutingSavedRulesStore.read();
      expect(reopened.sources.containsKey(b.id), isFalse);
      expect(reopened.sources[a.id]!.route, PluginRoute.direct);
    },
  );
}
