import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_generation_records.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'records preserve exact domains and can be reopened after generation',
    () async {
      final source = routingSources.first;
      final at = DateTime.utc(2026, 10, 31, 2);
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(source.id, PluginRoute.direct, [
          'media.example.com',
        ]),
        [source.id],
        now: at,
      );
      final record = (await RoutingGenerationRecords.read()).single;
      expect(record.source.name, source.name);
      expect(record.generatedAt, at);
      expect(record.ruleBlock, contains('DOMAIN,media.example.com,DIRECT'));
      expect(record.source.domains.length, source.domains.length + 1);
      expect(record.route, PluginRoute.direct);
    },
  );

  test(
    'updating one plugin preserves other records without duplicates',
    () async {
      final first = routingSources[0], second = routingSources[1];
      await RoutingGenerationRecords.record(
        RoutingPlan()
            .withSource(first.id, PluginRoute.direct, [])
            .withSource(second.id, PluginRoute.proxy, []),
        [first.id, second.id],
        now: DateTime.utc(2026, 10, 30),
      );
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(first.id, PluginRoute.proxy, []),
        [first.id],
        now: DateTime.utc(2026, 10, 31),
      );
      final records = await RoutingGenerationRecords.read();
      expect(records.length, 2);
      expect(records.first.source.id, first.id);
      expect(records.first.route, PluginRoute.proxy);
      expect(records.last.source.id, second.id);
      expect(records.last.route, PluginRoute.proxy);
      expect((await RoutingPlanStore.read()).choices, isEmpty);
    },
  );

  test('concurrent generation keeps both plugin snapshots', () async {
    await Future.wait([
      for (final source in routingSources.take(2))
        RoutingGenerationRecords.record(
          RoutingPlan().withSource(source.id, PluginRoute.direct, []),
          [source.id],
        ),
    ]);
    expect((await RoutingGenerationRecords.read()).length, 2);
  });

  test(
    'config checks retain generated targets and import only explicit new records',
    () async {
      final a = routingSources[0], b = routingSources[1];
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(a.id, PluginRoute.direct, []),
        [a.id],
        now: DateTime.utc(2026, 10, 30),
      );
      final before = await RoutingGenerationRecords.read();
      final at = DateTime.utc(2026, 11, 3);
      await RoutingGenerationRecords.applyConfigurationInspection(
        expected: before,
        recovered: [
          RoutingGenerationRecord(
            source: a,
            route: PluginRoute.proxy,
            generatedAt: at,
            origin: RoutingRecordOrigin.configuration,
          ),
          RoutingGenerationRecord(
            source: b,
            route: PluginRoute.proxy,
            generatedAt: at,
            origin: RoutingRecordOrigin.configuration,
          ),
        ],
        statuses: {a.id: 'different', b.id: 'matching'},
        checkedAt: at,
      );
      final records = {
        for (final r in await RoutingGenerationRecords.read()) r.source.id: r,
      };
      expect(records[a.id]!.route, PluginRoute.direct);
      expect(records[a.id]!.origin, RoutingRecordOrigin.generated);
      expect(records[a.id]!.configurationStatus, 'different');
      expect(records[a.id]!.generatedAt, before.single.generatedAt);
      expect(records[b.id]!.origin, RoutingRecordOrigin.configuration);
      expect(records[b.id]!.configurationStatus, 'matching');
      expect(records[b.id]!.checkedAt, at);
      // A newly generated target is unverified, even when its content is equal.
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(a.id, PluginRoute.direct, []),
        [a.id],
        now: at,
      );
      expect(
        (await RoutingGenerationRecords.read())
            .firstWhere((r) => r.source.id == a.id)
            .checkedAt,
        isNull,
      );
      expect(
        (await RoutingGenerationRecords.read())
            .firstWhere((r) => r.source.id == b.id)
            .checkedAt,
        at,
      );
    },
  );

  test(
    'late inspection never validates a generation made after opening the picker',
    () async {
      final a = routingSources.first;
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(a.id, PluginRoute.direct, []),
        [a.id],
        now: DateTime.utc(2026, 11, 1),
      );
      final before = await RoutingGenerationRecords.read();
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(a.id, PluginRoute.proxy, []),
        [a.id],
        now: DateTime.utc(2026, 11, 2),
      );
      await RoutingGenerationRecords.applyConfigurationInspection(
        expected: before,
        recovered: [],
        statuses: {a.id: 'matching'},
        checkedAt: DateTime.utc(2026, 11, 3),
      );
      final current = (await RoutingGenerationRecords.read()).single;
      expect(current.route, PluginRoute.proxy);
      expect(current.configurationStatus, isNull);
    },
  );

  test(
    'invalid inspection leaves existing records byte for byte intact',
    () async {
      final a = routingSources.first;
      await RoutingGenerationRecords.record(
        RoutingPlan().withSource(a.id, PluginRoute.direct, []),
        [a.id],
      );
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      await expectLater(
        RoutingGenerationRecords.applyConfigurationInspection(
          expected: await RoutingGenerationRecords.read(),
          recovered: [],
          statuses: {a.id: 'active'},
          checkedAt: DateTime.now(),
        ),
        throwsFormatException,
      );
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
    },
  );
}
