import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

Map<String, dynamic> _page(String value) => {
  'scheme': {'type': 'page'},
  'data': {'value': value},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'same query coalesces and older query cannot overwrite latest content',
    () async {
      final gates = <Completer<Map<String, dynamic>>>[];
      final cubit = PluginFunctionCubit(
        request: (_, _, _) {
          final gate = Completer<Map<String, dynamic>>();
          gates.add(gate);
          return gate.future;
        },
      );
      addTearDown(cubit.close);
      final old = cubit.load(from: 'function-order-test', functionId: 'old');
      final duplicate = cubit.load(
        from: 'function-order-test',
        functionId: 'old',
      );
      expect(gates.length, 1);
      final newer = cubit.load(from: 'function-order-test', functionId: 'new');
      gates[1].complete(_page('new'));
      await newer;
      gates[0].complete(_page('old'));
      await Future.wait([old, duplicate]);
      expect(cubit.state.data['value'], 'new');
      expect(cubit.state.hasContent, isTrue);
    },
  );

  test(
    'refresh failure retains successful content but login hides private data',
    () async {
      Object? failure;
      final cubit = PluginFunctionCubit(
        request: (_, _, _) async {
          if (failure != null) throw failure!;
          return _page('retained');
        },
      );
      addTearDown(cubit.close);
      await cubit.load(from: 'function-retain-test', functionId: 'home');
      failure = StateError('connection reset');
      await cubit.load(from: 'function-retain-test', functionId: 'home');
      expect(cubit.state.hasContent, isTrue);
      expect(cubit.state.data['value'], 'retained');
      expect(cubit.state.error, isNotEmpty);
      failure = StateError('请先登录');
      await cubit.load(from: 'function-retain-test', functionId: 'home');
      expect(cubit.state.loginRequired, isTrue);
      expect(cubit.state.hasContent, isFalse);
      expect(cubit.state.data, isEmpty);
    },
  );

  test('account boundary clears content and rejects late response', () async {
    final gate = Completer<Map<String, dynamic>>();
    final cubit = PluginFunctionCubit(request: (_, _, _) => gate.future);
    addTearDown(cubit.close);
    final pending = cubit.load(
      from: 'function-account-test',
      functionId: 'home',
    );
    final owner = pluginSessionWriteFence.beginSessionChange(
      'function-account-test',
    );
    gate.complete(_page('old-account'));
    await pending;
    expect(cubit.state.hasContent, isFalse);
    expect(cubit.state.data, isEmpty);
    pluginSessionWriteFence.seal('function-account-test', owner);
    expect(cubit.state.data, isEmpty);
  });
}
