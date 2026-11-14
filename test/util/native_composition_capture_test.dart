import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/util/diagnostics/native_composition_capture.dart';

void main() {
  const add = <String, Object?>{
    'event': 'route-added',
    'route': 'breeze.video.omo-detail',
  };
  const phase = <String, Object?>{
    'event': 'native-scene-audit',
    'sample': 'phase-frame',
    'routeEpoch': 8,
    'phase': 'completed|forward',
  };

  for (final route in [
    'breeze.download.comic-chapters',
    'breeze.download.video-work',
    'breeze.download.settings',
  ]) {
    test(
      '$route captures its own entry and return phases without forwarding the name',
      () async {
        final sent = <Map<String, Object?>>[];
        final probe = NativeCompositionCapture(
          enabled: true,
          isIOS: true,
          send: (args) async {
            sent.add(args);
          },
        );
        probe.observe({'event': 'route-added', 'route': route});
        probe.observe(phase);
        probe.observe({...phase, 'phase': 'completed|reverse'});
        probe.observe({'event': 'route-removed', 'route': route});
        probe.observe({...phase, 'phase': 'completed|completed'});
        await Future<void>.value();
        expect(sent, hasLength(3));
        expect(sent.map((sample) => sample['event']), [
          'route-added',
          'native-scene-audit',
          'native-scene-audit',
        ]);
        expect(sent.any((sample) => sample.containsKey('route')), isFalse);
      },
    );
  }

  test('disabled and non-iOS probes never invoke the native channel', () async {
    var calls = 0;
    for (final flags in [(false, true), (true, false), (false, false)]) {
      final probe = NativeCompositionCapture(
        enabled: flags.$1,
        isIOS: flags.$2,
        send: (_) async {
          calls++;
        },
      );
      probe.observe(add);
      probe.observe(phase);
    }
    await Future<void>.value();
    expect(calls, 0);
  });

  test(
    'capture forwards only categorical metadata and one request per phase',
    () async {
      final sent = <Map<String, Object?>>[];
      final probe = NativeCompositionCapture(
        enabled: true,
        isIOS: true,
        send: (args) async {
          sent.add(args);
        },
      );
      probe.observe(phase); // No tracked diagnostic entrance yet.
      probe.observe({'event': 'route-added', 'route': 'unrelated'});
      expect(sent, isEmpty);
      probe.observe({...add, 'url': 'https://private.test', 'text': 'secret'});
      probe.observe({
        ...phase,
        'cookies': ['secret'],
        'paintedGeometry': ['private'],
      });
      probe.observe(phase);
      probe.observe({...phase, 'sample': 'after-platform-replies'});
      await Future<void>.value();
      expect(sent, [
        {'event': 'route-added', 'request': 1},
        {
          'event': 'native-scene-audit',
          'request': 2,
          'routeEpoch': 8,
          'phase': 'completed|forward',
        },
      ]);
      probe.observe({'event': 'route-removed', 'route': add['route']});
      probe.observe({...phase, 'phase': 'completed|completed'});
      expect(sent, hasLength(2));
    },
  );

  test(
    'request budget is bounded and malformed phase content is omitted',
    () async {
      final sent = <Map<String, Object?>>[];
      final probe = NativeCompositionCapture(
        enabled: true,
        isIOS: true,
        send: (args) async {
          sent.add(args);
        },
      );
      probe.observe(add);
      for (var epoch = 0; epoch < 100; epoch++) {
        probe.observe({
          ...phase,
          'routeEpoch': epoch,
          'phase': 'private URL/中文',
        });
      }
      await Future<void>.value();
      expect(sent, hasLength(32));
      expect(sent.every((args) => !args.containsKey('phase')), isTrue);
    },
  );

  test('native probe errors never escape into navigation', () async {
    final probe = NativeCompositionCapture(
      enabled: true,
      isIOS: true,
      send: (_) async {
        throw StateError('unavailable');
      },
    );
    probe.observe(add);
    probe.observe(phase);
    await Future<void>.value();
  });
}
