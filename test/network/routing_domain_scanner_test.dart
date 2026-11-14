import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_scanner.dart';

void main() {
  test('declared site origins are exact HTTPS identities, never broad routing suffixes', () {
    expect(routingDeclaredSiteDomains({'version': 1, 'siteOrigins': [
      'https://www.omofuna.com/', 'https://other.source.tv',
      'https://user:password@private.source.tv', 'http://plain.source.tv',
      'https://wild.source.tv/media?secret=1', 'https://127.0.0.1',
      'https://github.com', '*.source.tv',
    ]}), ['other.source.tv', 'www.omofuna.com']);
    expect(routingDeclaredSiteDomains({'version': 2, 'siteOrigins':['https://new.source.tv']}), isEmpty);
  });

  test('omits dependency feature-check and reserved placeholder addresses', () {
    const script = '''
      new Request('https://empty.invalid', {method:'POST'});
      const fixture = 'https://cdn.test/image';
      const documentation = 'https://guide.example/docs';
      const apiHost = 'api.content.tv';
      const content = 'https://cdn.content.tv/image';
    ''';
    expect(scanRoutingDomains(script), ['api.content.tv', 'cdn.content.tv']);
  });

  test('extracts literal content hosts without executing the plugin', () {
    const script = r'''
      module.exports = {
        uuid: '01234567-1234-1234-1234-012345678901',
        home: 'https://media.example.tv/path?token=private',
        api: 'https:\/\/api.example.tv/v1',
        imageHost: 'img.example.tv',
        update: 'https://raw.githubusercontent.com/owner/source/plugin.cjs',
        metric: 'https://www.googletagmanager.com/a',
        local: 'http://127.0.0.1:8080/',
        auth: 'https://user:secret@private.example.tv/',
        dynamic: `https://${host}/video`,
      };
      throw new Error('must never run');
    ''';
    final scanned = scanRoutingPluginFile(script, 'Example.cjs');
    expect(scanned.id, '01234567-1234-1234-1234-012345678901');
    expect(scanned.fromFile, isTrue);
    expect(scanned.name, 'Example');
    expect(scanned.domains, [
      'api.example.tv',
      'img.example.tv',
      'media.example.tv',
    ]);
    expect(scanned.toJson().toString(), isNot(contains('private')));
  });

  test(
    'invalid and oversized files fail; obfuscated files do not invent hosts',
    () {
      expect(
        () => scanRoutingPluginFile('[Rule]\nFINAL,PROXY', 'bad.cjs'),
        throwsFormatException,
      );
      expect(
        () => scanRoutingDomains('x' * (4 * 1024 * 1024 + 1)),
        throwsFormatException,
      );
      expect(
        scanRoutingPluginFile(
          'module.exports={home:decode(secret)}',
          'dynamic.cjs',
        ).domains,
        isEmpty,
      );
    },
  );

  test(
    'new installed and imported plugins survive storage and export together',
    () {
      const extra = RoutingSource('installed-other', 'Other', []);
      const file = RoutingSource('file:sample', 'Imported', [], fromFile: true);
      final plan = RoutingPlan()
          .withAvailableSources([extra])
          .withScannedSource(
            const RoutingSource('installed-other', 'Other', ['api.other.tv']),
          )
          .withConfirmedDomain(extra.id, 'api.other.tv', true)
          .withSource(extra.id, PluginRoute.direct, ['manual.other.tv'])
          .withScannedSource(
            const RoutingSource('file:sample', 'Imported', [
              'video.imported.tv',
            ], fromFile: true),
          )
          .withConfirmedDomain(file.id, 'video.imported.tv', true)
          .withSource(file.id, PluginRoute.proxy, []);
      final restored = RoutingPlan.fromJson(plan.toJson());
      expect(restored.shadowrocketRules, plan.shadowrocketRules);
      expect(
        restored.shadowrocketRules,
        contains('DOMAIN,api.other.tv,DIRECT'),
      );
      expect(
        restored.shadowrocketRules,
        contains('DOMAIN,video.imported.tv,PROXY'),
      );
      expect(restored.customSources[file.id]?.fromFile, isTrue);
      final rescanned = restored
          .withScannedSource(
            const RoutingSource('installed-other', 'Other', ['new.other.tv']),
          )
          .withConfirmedDomain(extra.id, 'new.other.tv', true);
      expect(rescanned.rules, isNot(contains('api.other.tv')));
      expect(rescanned.rules, contains('new.other.tv'));
      expect(rescanned.rules, contains('manual.other.tv'));
      expect(rescanned.rules, contains('video.imported.tv'));
    },
  );

  test('refresh keeps reviewed hosts and catches cross-plugin conflicts', () {
    final first = routingSources.first;
    final plan = RoutingPlan().withSource(first.id, PluginRoute.direct, []);
    final extracted = plan.withScannedSource(
      RoutingSource(first.id, first.name, ['fresh.cdn.tv']),
    );
    expect(extracted.rules, isNot(contains('fresh.cdn.tv')));
    final refreshed = extracted.withConfirmedDomain(
      first.id,
      'fresh.cdn.tv',
      true,
    );
    expect(refreshed.rules, contains('www.omofuna.com'));
    expect(refreshed.rules, contains('fresh.cdn.tv'));
    final conflict = refreshed
        .withScannedSource(
          const RoutingSource('other', 'Other', ['fresh.cdn.tv']),
        )
        .withConfirmedDomain('other', 'fresh.cdn.tv', true)
        .withSource('other', PluginRoute.proxy, []);
    expect(() => conflict.rules, throwsA(isA<RoutingConflict>()));
    expect(
      RoutingPlan.fromJson({'choices': {}, 'extraDomains': {}}).rules,
      isEmpty,
    );
  });
}
