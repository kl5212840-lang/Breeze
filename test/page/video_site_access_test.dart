import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_site_access.dart';

void main() {
  final home = Uri.parse('https://hanime1.me/');
  test(
    'expanded diagnostics keep error codes but discard raw messages and headers',
    () {
      final diagnostic = VideoBrowserDiagnostics();
      diagnostic.console(
        'Cloudflare Turnstile error 200500 at https://secret.example/?token=private',
      );
      diagnostic.response({
        'cf-ray': 'a4e73e244a127e27-SJC',
        'set-cookie': 'password=private',
        'cf-mitigated': 'challenge',
      }, main: true);
      diagnostic.document(
        'load-start',
        Uri.parse('https://hanime1.me/user/private?token=hidden'),
      );
      final report = diagnostic.report();
      expect(report, contains('200500'));
      expect(report, contains('a4e73e244a127e27-SJC'));
      expect(report, contains('/other'));
      expect(report, contains('diagnosticVersion: 5'));
      expect(report, contains('resource-status-0-is-unknown'));
      expect(report, contains('clearance-presence-is-not-acceptance'));
      for (final secret in [
        'secret.example',
        'private',
        'password',
        'hidden',
        'token=',
      ]) {
        expect(report, isNot(contains(secret)));
      }
    },
  );

  test('diagnostics separate observed content from challenges and timeout', () {
    final diagnostic = VideoBrowserDiagnostics();
    VideoSiteState state(Map<String, dynamic> signals) =>
        VideoSiteState.fromRaw({
          'url': 'https://hanime1.me/user/private?token=hidden',
          ...signals,
        });
    for (var i = 0; i < 50; i++) {
      diagnostic.observed(
        state({'challengeShell': true}),
        matchesRequested: true,
      );
    }
    diagnostic.verification('shown');
    diagnostic.verification('observation-deadline');
    diagnostic.observed(
      state({'nativeContent': true}),
      matchesRequested: false,
    );
    diagnostic.observed(state({'nativeContent': true}), matchesRequested: true);
    diagnostic.verification('content-returned');
    diagnostic.verification('private-token');
    diagnostic.catalog('cache-frame-ready');
    diagnostic.catalog('fresh-frame-ready');
    diagnostic.catalog('refresh-failed');
    diagnostic.catalog('private-token');
    final report = diagnostic.report();
    expect(report, contains('"observed challenge":1'));
    expect(report, contains('observed different-document'));
    expect(report, contains('observed native-content'));
    expect(report, contains('verification observation-deadline'));
    expect(report, contains('verification content-returned'));
    expect(report, contains('catalog cache-frame-ready'));
    expect(report, contains('catalog fresh-frame-ready'));
    expect(report, contains('catalog refresh-failed'));
    expect(report, isNot(contains('private')));
    expect(report, isNot(contains('hidden')));
  });

  test(
    'resource diagnostics are allowlisted and frame observation is explicitly limited',
    () {
      final state = VideoSiteState.fromRaw({
        'url': home.toString(),
        'challengeShell': true,
        'frameObservation': 'main-and-open-shadow-only',
        'challengeFrames': 0,
        'challengeErrorCodes': ['200500', 'private-token'],
        'challengeResources': [
          {
            'host': 'provider',
            'stage': 'pat',
            'type': 'fetch',
            'status': 401,
            'durationMs': 40,
            'url': 'https://secret.example/?token=private',
          },
        ],
      });
      expect(state.challenge, isTrue);
      expect(state.browser['frameObservation'], 'main-and-open-shadow-only');
      expect(state.browser.toString(), contains('200500'));
      expect(state.browser.toString(), isNot(contains('private')));
    },
  );

  test(
    'HTTPS child frames use browser rules, not top-level app navigation',
    () {
      for (final url in [
        'https://example.com/frame',
        'https://challenges.cloudflare.com.evil.example/',
      ]) {
        expect(
          allowVideoSiteNavigation(home, Uri.parse(url), isMainFrame: false),
          isTrue,
        );
        expect(
          allowVideoSiteNavigation(home, Uri.parse(url), isMainFrame: true),
          isFalse,
        );
      }
    },
  );

  test('diagnostics contain bounded metadata without URLs or secrets', () {
    final diagnostic = VideoBrowserDiagnostics();
    final uri = Uri.parse(
      'https://user:secret@example.com/private?token=hidden',
    );
    diagnostic.navigation(uri, main: true, allowed: false);
    diagnostic.resource(uri, 'HTTP 403', main: true);
    for (var i = 0; i < 100; i++) {
      diagnostic.resource(
        Uri.parse('https://host$i.example/'),
        'HTTP 500',
        main: true,
      );
    }
    final report = diagnostic.report();
    for (final secret in ['secret', 'private', 'token', 'hidden', 'user:']) {
      expect(report, isNot(contains(secret)));
    }
    expect(report.length, lessThan(16000));
  });

  test(
    'navigation allowlist separates challenge frames from top-level pages',
    () {
      for (final path in [
        'https://hanime1.me/',
        'https://hanime1.me/cdn-cgi/challenge-platform/test',
      ]) {
        expect(
          allowVideoSiteNavigation(home, Uri.parse(path), isMainFrame: true),
          isTrue,
        );
      }
      for (final url in [
        'https://challenges.cloudflare.com/turnstile/v0/',
        'about:blank',
        'about:srcdoc',
      ]) {
        expect(
          allowVideoSiteNavigation(home, Uri.parse(url), isMainFrame: false),
          isTrue,
        );
        expect(
          allowVideoSiteNavigation(home, Uri.parse(url), isMainFrame: true),
          isFalse,
        );
      }
      for (final url in [
        'https://user@challenges.cloudflare.com/',
        'https://challenges.cloudflare.com:8443/',
        'http://challenges.cloudflare.com/',
        'javascript:alert(1)',
        'data:text/html,test',
        'about:settings',
      ]) {
        expect(
          allowVideoSiteNavigation(home, Uri.parse(url), isMainFrame: false),
          isFalse,
          reason: url,
        );
      }
    },
  );

  test(
    'temporary challenge query does not change requested video identity',
    () {
      final expected = Uri.parse('https://hanime1.me/watch?v=1');
      final temporary = Uri.parse(
        'https://hanime1.me/watch?v=1&__cf_chl_rt_tk=private#fragment',
      );
      expect(videoSiteDocumentMatches(expected, temporary), isTrue);
      expect(videoSiteDocumentUrl(temporary), expected);
      expect(
        videoSiteDocumentMatches(
          expected,
          Uri.parse('https://hanime1.me/watch?v=2&__cf_chl_rt_tk=private'),
        ),
        isFalse,
      );
      expect(
        videoSiteDocumentMatches(
          expected,
          Uri.parse('https://evil.example/watch?v=1'),
        ),
        isFalse,
      );
      expect(
        videoSiteDocumentMatches(
          expected,
          Uri.parse('https://hanime1.me/watch?v=1&other=value'),
        ),
        isFalse,
      );
    },
  );

  test('queryless document identities never gain an empty query separator', () {
    const target = 'https://hanime1.me/user/88';
    for (final raw in [
      target,
      '$target?',
      '$target?__cf_chl_rt_tk=private#fragment',
    ]) {
      final actual = videoSiteDocumentUrl(Uri.parse(raw));
      expect(actual.toString(), target);
      expect(actual.hasQuery, isFalse);
    }
    final encoded = Uri.parse(
      'https://hanime1.me/a%2Fb?__cf_chl_rt_tk=private',
    );
    expect(
      videoSiteDocumentUrl(encoded).toString(),
      'https://hanime1.me/a%2Fb',
    );
    final search = Uri.parse(
      'https://hanime1.me/search?query=Creator&tags%5B%5D=HD',
    );
    expect(videoSiteDocumentUrl(search), search);
  });

  test(
    'interstitial is distinct from an empty document or an embedded widget',
    () {
      VideoSiteState state(Map<String, dynamic> signals) =>
          VideoSiteState.fromRaw({'url': home.toString(), ...signals});
      expect(state({'challengeShell': true}).challenge, isTrue);
      expect(state({'challengeForm': true}).challenge, isTrue);
      expect(
        state({'clearanceConfig': true, 'challengeFrame': true}).challenge,
        isTrue,
      );
      expect(state({}).challenge, isFalse);
      expect(
        state({'challengeFrame': true, 'siteUi': true}).challenge,
        isFalse,
      );
      expect(
        state({
          'nativeContent': true,
          'clearanceConfig': true,
          'challengeTitle': true,
        }).challenge,
        isFalse,
      );
      expect(state({'siteUi': true}).websiteReady, isTrue);
      expect(
        state({'challengeForm': true, 'siteUi': true}).websiteReady,
        isFalse,
      );
    },
  );
}
