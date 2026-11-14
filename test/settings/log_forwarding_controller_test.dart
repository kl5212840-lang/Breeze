import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/util/log_forwarding_controller.dart';

void main() {
  test(
    'saving and clearing updates both sinks and persistence without sending logs',
    () async {
      var rust = '', dart = '', saved = '';
      final controller = LogForwardingController(
        configureRust: (value) {
          rust = value;
        },
        configureDart: (value) => dart = value,
      );
      await controller.apply('https://old.invalid/log');
      await controller.save(
        ' https://new.invalid/log ',
        persist: (value) {
          saved = value;
        },
      );
      expect([
        rust,
        dart,
        saved,
        controller.current,
      ], List.filled(4, 'https://new.invalid/log'));
      await controller.save(
        '',
        persist: (value) {
          saved = value;
        },
      );
      expect([rust, dart, saved, controller.current], List.filled(4, ''));
    },
  );

  test(
    'rejected persistence restores both live sinks and rejects success',
    () async {
      var rust = '', dart = '';
      final controller = LogForwardingController(
        configureRust: (value) {
          rust = value;
        },
        configureDart: (value) => dart = value,
      );
      await controller.apply('https://old.invalid/log');
      await expectLater(
        controller.save(
          '',
          persist: (_) => throw StateError('storage unavailable'),
        ),
        throwsStateError,
      );
      expect([
        rust,
        dart,
        controller.current,
      ], List.filled(3, 'https://old.invalid/log'));
    },
  );

  test(
    'native reconfiguration failure does not change persistence or Dart target',
    () async {
      var rust = '', dart = '', writes = 0;
      final controller = LogForwardingController(
        configureRust: (value) {
          if (value == 'https://rejected.invalid/log')
            throw StateError('native unavailable');
          rust = value;
        },
        configureDart: (value) => dart = value,
      );
      await controller.apply('https://old.invalid/log');
      await expectLater(
        controller.save(
          'https://rejected.invalid/log',
          persist: (_) {
            writes++;
          },
        ),
        throwsStateError,
      );
      expect(writes, 0);
      expect([
        rust,
        dart,
        controller.current,
      ], List.filled(3, 'https://old.invalid/log'));
    },
  );

  test('a failed save does not poison the next serialized clear', () async {
    var rust = '', dart = '', saved = 'https://old.invalid/log';
    final controller = LogForwardingController(
      configureRust: (value) {
        rust = value;
      },
      configureDart: (value) => dart = value,
    );
    await controller.apply(saved);
    final rejected = controller.save(
      'https://bad.invalid/log',
      persist: (_) => throw StateError('storage'),
    );
    final failure = expectLater(rejected, throwsStateError);
    final cleared = controller.save(
      '',
      persist: (value) {
        saved = value;
      },
    );
    await failure;
    await cleared;
    expect([rust, dart, saved, controller.current], List.filled(4, ''));
  });
}
