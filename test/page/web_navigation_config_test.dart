import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/web_navigation_config.dart';

void main() {
  test('accepts same-origin HTTPS navigation shortcuts', () {
    final config = WebNavigationConfig.fromRouteInfo([
      'Hanime1',
      'https://hanime1.me/',
      '{"homeUrl":"https://hanime1.me/","searchUrl":"https://hanime1.me/search"}',
    ]);
    expect(config?.homeUrl.toString(), 'https://hanime1.me/');
    expect(config?.searchUrl.toString(), 'https://hanime1.me/search');
  });

  test('rejects cross-origin or insecure home shortcut', () {
    expect(
      WebNavigationConfig.fromRouteInfo([
        'Hanime1',
        'https://hanime1.me/',
        '{"homeUrl":"https://example.com/"}',
      ]),
      isNull,
    );
    expect(
      WebNavigationConfig.fromRouteInfo([
        'Hanime1',
        'https://hanime1.me/',
        '{"homeUrl":"http://hanime1.me/"}',
      ]),
      isNull,
    );
  });

  test('ignores invalid search shortcut without losing safe home', () {
    final config = WebNavigationConfig.fromRouteInfo([
      'Hanime1',
      'https://hanime1.me/',
      '{"homeUrl":"https://hanime1.me/","searchUrl":"https://other.test/"}',
    ]);
    expect(config, isNotNull);
    expect(config?.searchUrl, isNull);
  });

  test('legacy web pages keep their existing toolbar behavior', () {
    expect(
      WebNavigationConfig.fromRouteInfo(['Webpage', 'https://example.com/']),
      isNull,
    );
  });

  test('accepts a scoped playback probe only on the declared watch path', () {
    final config = WebNavigationConfig.fromRouteInfo([
      'Hanime1',
      'https://hanime1.me/',
      r'{"homeUrl":"https://hanime1.me/","playback":{"source":"1e600cff-8ebe-4517-8aa4-6678aec46424","fnPath":"getPlayback","videoSelector":"video#player","playTriggerSelector":"button[data-plyr=\"play\"]","watchPath":"/watch"}}',
    ]);
    expect(config?.playback, isNotNull);
    expect(config?.playback?.playTriggerSelector, 'button[data-plyr="play"]');
    expect(
      config?.playback?.matches(Uri.parse('https://hanime1.me/watch?v=408773')),
      isTrue,
    );
    expect(
      config?.playback?.matches(Uri.parse('https://other.test/watch?v=408773')),
      isFalse,
    );
  });

  test(
    'rejects invalid playback selector metadata without losing navigation',
    () {
      final config = WebNavigationConfig.fromRouteInfo([
        'Hanime1',
        'https://hanime1.me/',
        '{"homeUrl":"https://hanime1.me/","playback":{"source":"bad","fnPath":"getPlayback","videoSelector":"video","watchPath":"/watch"}}',
      ]);
      expect(config, isNotNull);
      expect(config?.playback, isNull);
    },
  );
}
