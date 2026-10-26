import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// A source's display choice is independent of its search/filter capabilities.
abstract final class SourceListPreferences {
  static const prefix = 'breeze.source.list-details.v1.';
  static final changes = ValueNotifier<int>(0);
  static final _writes = <String, Future<void>>{};

  static Future<bool?> read(String source) async {
    if (source.isEmpty) return null;
    try {
      await _writes[source]?.catchError((Object _) {});
      return (await SharedPreferences.getInstance()).getBool('$prefix$source');
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String source, bool detailed) async {
    if (source.isEmpty) return;
    final previous = _writes[source] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      final store = await SharedPreferences.getInstance();
      try {
        if (!await store.setBool('$prefix$source', detailed)) {
          throw StateError('Display preference was not saved');
        }
      } catch (_) {
        // SharedPreferences changes its memory cache before persistence. A
        // failed save must not be mistaken for a successful future preference.
        try {
          await store.reload();
        } catch (_) {}
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
    setState(() => _detailed = detailed);
    final source = widget.source;
    unawaited(() async {
      try {
        await SourceListPreferences.write(source, detailed);
      } catch (_) {
        if (mounted && source == widget.source) {
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
    SourceListPreferences.changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _detailed, _select);
}
