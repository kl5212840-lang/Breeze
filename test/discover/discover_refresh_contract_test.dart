import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';

class _Registry extends Fake implements PluginRegistryService {
  final updates = StreamController<Map<String, PluginRuntimeState>>.broadcast();
  final pending = <Completer<Map<String, dynamic>>>[];
  final items = <String, PluginRuntimeState>{
    'local-fixture': PluginRuntimeState(
      uuid: 'local-fixture',
      version: '1',
      originScript: 'offline fixture',
      isEnabled: true,
      isDeleted: false,
      debug: false,
      debugUrl: null,
      lastLoadSuccess: true,
      lastLoadError: null,
      sortOrder: 0,
      insertedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      deletedAt: null,
    ),
  };

  @override
  Map<String, PluginRuntimeState> get snapshot => Map.unmodifiable(items);
  @override
  Stream<Map<String, PluginRuntimeState>> get stream => updates.stream;
  @override
  PluginRuntimeState? getByUuid(String uuid) => items[uuid];
  @override
  Map<String, dynamic>? getCachedPluginInfo(String uuid) => null;
  @override
  List<PluginRuntimeState> sortPlugins(Iterable<PluginRuntimeState> plugins) =>
      plugins.toList();
  @override
  Future<Map<String, dynamic>> fetchPluginInfo({
    required String uuid,
    required String runtimeName,
  }) {
    final gate = Completer<Map<String, dynamic>>();
    pending.add(gate);
    return gate.future;
  }
}

void main() {
  test(
    'Discover refresh waits for metadata, retains cards and joins duplicates',
    () async {
      final service = _Registry();
      final cubit = DiscoverCubit(service: service);
      addTearDown(service.updates.close);
      addTearDown(cubit.close);
      service.pending[0].complete({'name': 'kept'});
      await Future<void>.delayed(Duration.zero);
      var done = false;
      final refresh = cubit.reload().then((_) => done = true);
      final duplicate = cubit.reload();
      await Future<void>.delayed(Duration.zero);
      expect(service.pending, hasLength(2));
      expect(done, isFalse);
      expect(cubit.state.infoStates['local-fixture']!.data!['name'], 'kept');
      service.pending[1].complete({'name': 'fresh'});
      expect(await refresh, isTrue);
      await duplicate;
      expect(cubit.state.infoStates['local-fixture']!.data!['name'], 'fresh');
    },
  );

  test(
    'metadata failure retains the good card and offers another real read',
    () async {
      final service = _Registry();
      final cubit = DiscoverCubit(service: service);
      addTearDown(service.updates.close);
      addTearDown(cubit.close);
      service.pending[0].complete({'name': 'retained'});
      await Future<void>.delayed(Duration.zero);
      final refresh = cubit.reload();
      service.pending[1].completeError(StateError('metadata fixture failed'));
      expect(await refresh, isFalse);
      final state = cubit.state.infoStates['local-fixture']!;
      expect(state.data!['name'], 'retained');
      expect(cubit.refreshError, isNotNull);
      expect(state.loading, isFalse);
      final retry = cubit.retryLoadInfo('local-fixture');
      service.pending[2].complete({'name': 'recovered'});
      await retry;
      expect(cubit.state.infoStates['local-fixture']!.error, isNull);
      expect(
        cubit.state.infoStates['local-fixture']!.data!['name'],
        'recovered',
      );
    },
  );
}
