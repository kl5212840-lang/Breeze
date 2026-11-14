import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// A source's display choice is independent of its search/filter capabilities.
abstract final class SourceListPreferences {
  static const prefix = 'breeze.source.list-details.v1.';
  static final changes = ValueNotifier<int>(0);
  static final _writes = <String, Future<void>>{};
  static final _epochs = <String, int>{};

  static Future<bool?> read(String source) async {
    if (source.isEmpty) return null;
    try {
      while (true) {
        final epoch = _epochs[source] ?? 0;
        await _writes[source]?.catchError((Object _) {});
        final store = await SharedPreferences.getInstance();
        if (epoch != (_epochs[source] ?? 0)) continue;
        return store.getBool('$prefix$source');
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String source, bool detailed) async {
    if (source.isEmpty) return;
    _epochs[source] = (_epochs[source] ?? 0) + 1;
    final previous = _writes[source] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      final store = await SharedPreferences.getInstance();
      final key = '$prefix$source', previous = store.get('$prefix$source');
      try {
        if (!await store.setBool(key, detailed)) {
          throw StateError('Display preference was not saved');
        }
      } catch (_) {
        // SharedPreferences changes its memory cache before persistence. A
        // failed save must not be mistaken for a successful future preference.
        // A global reload would discard unrelated concurrent restore changes.
        if (store.get(key) == detailed) {
          try {
            await switch (previous) {
              String value => store.setString(key, value),
              bool value => store.setBool(key, value),
              int value => store.setInt(key, value),
              double value => store.setDouble(key, value),
              List<String> value => store.setStringList(key, value),
              _ => store.remove(key),
            };
          } catch (_) {}
        }
        rethrow;
      }
      changes.value++;
    });
    _writes[source] = next;
    try {
      await next;
    } finally {
      if (identical(_writes[source], next)) _writes.remove(source);
    }
  }

  static Future<void> flush() async {
    await Future.wait([
      for (final write in _writes.values.toList())
        write.catchError((Object _) {}),
    ]);
  }
}

class SourceListPresentation extends StatefulWidget {
  const SourceListPresentation({
    super.key,
    required this.source,
    required this.builder,
    this.detailedByDefault = false,
  });

  final String source;
  final bool detailedByDefault;
  final Widget Function(BuildContext, bool, ValueChanged<bool>) builder;

  @override
  State<SourceListPresentation> createState() => _SourceListPresentationState();
}

class _SourceListPresentationState extends State<SourceListPresentation> {
  late bool _detailed = widget.detailedByDefault;
  int _epoch = 0;
  int _selectionEpoch = 0;

  @override
  void initState() {
    super.initState();
    SourceListPreferences.changes.addListener(_changed);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(SourceListPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _selectionEpoch++;
      _detailed = widget.detailedByDefault;
      unawaited(_load());
    }
  }

  void _changed() => unawaited(_load());

  Future<void> _load() async {
    final epoch = ++_epoch;
    final value = await SourceListPreferences.read(widget.source);
    if (!mounted || epoch != _epoch) return;
    setState(() => _detailed = value ?? widget.detailedByDefault);
  }

  void _select(bool detailed) {
    _epoch++;
    final selectionEpoch = ++_selectionEpoch;
    setState(() => _detailed = detailed);
    final source = widget.source;
    unawaited(() async {
      try {
        await SourceListPreferences.write(source, detailed);
      } catch (_) {
        if (mounted &&
            source == widget.source &&
            selectionEpoch == _selectionEpoch) {
          await _load();
          if (!mounted || selectionEpoch != _selectionEpoch) return;
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(t.comicList.viewSaveFailed)));
        }
      }
    }());
  }

  @override
  void dispose() {
    _epoch++;
    _selectionEpoch++;
    SourceListPreferences.changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _detailed, _select);
}
