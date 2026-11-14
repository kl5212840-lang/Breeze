import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/search_aggregate/cubit/search_aggregate_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a source network change keeps the other source result', () async {
    SharedPreferences.setMockInitialValues({});
    const changed = '00000000-0000-4000-8000-000000000001';
    const kept = '00000000-0000-4000-8000-000000000002';
    final calls = <String, int>{};
    final c = AggregateSearchCubit(
      const SearchEvent(),
      initialSelectedSources: {changed: true, kept: true},
      sourceSearch: (source, _) async => [
        calls.update(source, (value) => value + 1, ifAbsent: () => 1),
      ],
    );
    addTearDown(c.close);
    await c.search();
    await SourceNetworkPolicies.save(
      changed,
      const SourceNetworkPreference(mode: SourceNetworkMode.system),
    );
    await Future<void>.delayed(Duration.zero);
    expect(c.state.results[changed], [2]);
    expect(c.state.results[kept], [1]);
    expect(calls, {changed: 2, kept: 1});
  });

  test('initial and refresh of one source share physical work', () async {
    final pending = Completer<List<dynamic>>();
    var calls = 0;
    final c = AggregateSearchCubit(
      const SearchEvent(),
      initialSelectedSources: {'a': true},
      sourceSearch: (_, __) {
        calls++;
        return pending.future;
      },
    );
    final first = c.search(), retry = c.refreshSource('a');
    expect(calls, 1);
    pending.complete(['current']);
    await Future.wait([first, retry]);
    expect(c.state.results['a'], ['current']);
    expect(c.state.refreshingSources, isEmpty);
    await c.close();
  });
  test('repeated whole search shares budget and initial tasks', () async {
    var active = 0, peak = 0;
    final pending = <Completer<List<dynamic>>>[];
    final c = AggregateSearchCubit(
      const SearchEvent(),
      initialSelectedSources: {'a': true, 'b': true, 'c': true},
      sourceSearch: (_, __) async {
        active++;
        if (active > peak) peak = active;
        final p = Completer<List<dynamic>>();
        pending.add(p);
        try {
          return await p.future;
        } finally {
          active--;
        }
      },
    );
    final one = c.search(), two = c.search();
    expect(pending, hasLength(3));
    for (final p in pending) {
      p.complete(['result']);
    }
    await Future.wait([one, two]);
    expect(peak, 3);
    expect(active, 0);
    await c.close();
  });
  test('selection changes query only newly enabled source', () async {
    final calls = <String, int>{};
    final c = AggregateSearchCubit(
      const SearchEvent(),
      initialSelectedSources: {'a': true, 'b': true},
      sourceSearch: (id, _) async {
        calls[id] = (calls[id] ?? 0) + 1;
        return [id];
      },
    );
    await c.search();
    await c.toggleSource('a', false);
    expect(c.state.results['b'], ['b']);
    await c.toggleSource('a', true);
    expect(calls, {'a': 2, 'b': 1});
    await c.close();
  });
  test(
    'failed refresh preserves good results and retains failure evidence',
    () async {
      var calls = 0;
      final c = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'a': true},
        sourceSearch: (_, __) async {
          if (++calls > 1) throw const SocketException('network unavailable');
          return ['kept'];
        },
      );
      await c.search();
      await c.refreshSource('a');
      expect(c.state.results['a'], ['kept']);
      expect(c.state.errors['a'], 'network');
      expect(c.state.pendingSources, isEmpty);
      await c.close();
    },
  );
  test(
    'withdrawn source cannot return while noncancellable work drains',
    () async {
      final pending = Completer<List<dynamic>>();
      final c = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'a': true},
        sourceSearch: (_, __) => pending.future,
      );
      final first = c.search();
      await c.toggleSource('a', false);
      pending.complete(['late']);
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(c.state.results, isEmpty);
      expect(c.state.errors, isEmpty);
      await c.close();
    },
  );
  test('disabled or removed sources never enter execution', () async {
    var calls = 0;
    final c = AggregateSearchCubit(
      const SearchEvent(),
      initialSelectedSources: {'a': true},
      availableSources: {},
      sourceSearch: (_, __) async {
        calls++;
        return [];
      },
    );
    await c.search();
    expect(calls, 0);
    await c.close();
  });
  test('429 retry-after prevents early automatic and manual rereads', () async {
    var calls = 0;
    final c = AggregateSearchCubit(
      const SearchEvent(),
      initialSelectedSources: {'limited': true},
      sourceSearch: (_, __) async {
        calls++;
        throw StateError('HTTP 429 Retry-After: 120');
      },
    );
    await c.search();
    c.setReadActive(true);
    await c.refreshSource('limited');
    await Future<void>.delayed(const Duration(milliseconds: 850));
    expect(calls, 1);
    // Explicit retry must also respect the source's server deadline.
    await c.retryFailedSources();
    expect(calls, 1);
    await c.close();
  });

  test(
    'closed sessions hold physical admission until their reads really settle',
    () async {
      var active = 0, peak = 0;
      final oldReads = <Completer<List<dynamic>>>[],
          newReads = <Completer<List<dynamic>>>[];
      Future<List<dynamic>> read(List<Completer<List<dynamic>>> owner) async {
        active++;
        if (active > peak) peak = active;
        final gate = Completer<List<dynamic>>();
        owner.add(gate);
        try {
          return await gate.future;
        } finally {
          active--;
        }
      }

      final old = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'a': true, 'b': true, 'c': true},
        sourceSearch: (_, __) => read(oldReads),
      );
      final next = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'d': true, 'e': true, 'f': true},
        sourceSearch: (_, __) => read(newReads),
      );
      final first = old.search();
      await old.close();
      final second = next.search();
      expect(newReads, isEmpty);
      for (final gate in oldReads) {
        gate.complete(['retired']);
      }
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(newReads.length, 3);
      for (final gate in newReads) {
        gate.complete(['current']);
      }
      await second;
      expect(peak, 3);
      expect(active, 0);
      await next.close();
    },
  );

  test(
    'a published plugin replacement supersedes the old search attempt',
    () async {
      final reads = <Completer<List<dynamic>>>[];
      final c = AggregateSearchCubit(
        const SearchEvent(),
        initialSelectedSources: {'a': true},
        sourceDefinitions: {'a': 'old-script'},
        sourceSearch: (_, __) {
          final gate = Completer<List<dynamic>>();
          reads.add(gate);
          return gate.future;
        },
      );
      final old = c.search();
      c.updateSourceDefinitions({'a': 'new-script'});
      expect(reads.length, 2);
      reads.last.complete(['new']);
      await Future<void>.delayed(Duration.zero);
      reads.first.complete(['old']);
      await old;
      await Future<void>.delayed(Duration.zero);
      expect(c.state.results['a'], ['new']);
      await c.close();
    },
  );

  test('format/authentication failures are not network failures', () {
    expect(
      aggregateSearchFailure(const FormatException('missing items')),
      'format',
    );
    expect(aggregateSearchFailure(StateError('login required')), 'login');
  });
}
