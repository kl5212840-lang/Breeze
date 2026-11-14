import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

void main() {
  test('a source session change invalidates every earlier network runtime', () {
    final fence = PluginSessionWriteFence();
    const source = 'fixture-source';
    const first = 'fixture-source@net.aaaaaaaaaaaa';
    const second = 'fixture-source@net.bbbbbbbbbbbb';
    expect(fence.permits(source, first), isTrue);
    final logoutOwner = fence.advance(source);
    final clearingRuntime = fence.runtime(source, second);
    expect(fence.permits(source, first), isFalse);
    expect(fence.permits(source, clearingRuntime), isTrue);
    fence.seal(source, logoutOwner);
    expect(
      fence.permits(source, clearingRuntime),
      isFalse,
      reason:
          'A detached init promise in the clearing VM cannot restore a session either.',
    );
    final legalLoginRuntime = fence.runtime(source, second);
    expect(fence.permits(source, legalLoginRuntime), isTrue);
    expect(pluginSessionBaseRuntime(legalLoginRuntime), second);
  });

  test(
    'ordinary dispatch/network changes retain ownership and unrelated sources remain independent',
    () {
      final fence = PluginSessionWriteFence();
      final original = fence.runtime('a', 'a@net.aaaaaaaaaaaa');
      final networkChanged = fence.runtime('a', 'a@net.bbbbbbbbbbbb');
      expect(fence.permits('a', original), isTrue);
      expect(fence.permits('a', networkChanged), isTrue);
      fence.advance('b');
      expect(fence.permits('a', original), isTrue);
      expect(fence.runtime('a', original), original);
    },
  );

  test('an older completion cannot seal a newer explicit login', () {
    final fence = PluginSessionWriteFence();
    final older = fence.advance('a');
    final newer = fence.advance('a');
    final runtime = fence.runtime('a', 'a');
    fence.seal('a', older);
    expect(fence.generation('a'), newer);
    expect(fence.permits('a', runtime), isTrue);
  });
}
