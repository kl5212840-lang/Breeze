import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Exclusions are local preferences, separate from inclusive result filters.
abstract final class SourceListBlockPreferences {
  static final changes = ValueNotifier<int>(0);
  static Future<void> flush() async {
    await Future.wait(_writes.values.toList());
  }

  static final _writes = <String, Future<void>>{};
  static String key(String scope) =>
      'breeze.source.blocked-categories.v1.${Uri.encodeComponent(scope)}';

  static Future<Set<String>?> read(String scope) async {
    await _writes[scope];
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(key(scope));
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.any((item) => item is! String)) {
      throw const FormatException('Invalid category preferences');
    }
    return decoded
        .cast<String>()
        .where((item) => item.trim().isNotEmpty)
        .toSet();
  }

  static Future<void> write(String scope, Set<String> categories) {
    final values = categories.toList()..sort();
    final operation = (_writes[scope] ?? Future<void>.value()).then((_) async {
      final store = await SharedPreferences.getInstance();
      final storageKey = key(scope), previous = store.getString(key(scope));
      final encoded = jsonEncode(values);
      try {
        if (!await store.setString(storageKey, encoded)) {
          throw StateError('Category preferences were not saved');
        }
      } catch (_) {
        if (store.getString(storageKey) == encoded) {
          try {
            previous == null
                ? await store.remove(storageKey)
                : await store.setString(storageKey, previous);
          } catch (_) {}
        }
        rethrow;
      }
      changes.value++;
    });
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _writes[scope] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_writes[scope], tail)) _writes.remove(scope);
      }),
    );
    return operation;
  }
}

class SourceCategoryBlockScope extends StatefulWidget {
  const SourceCategoryBlockScope({
    super.key,
    required this.scope,
    required this.builder,
    this.initial = const {},
    this.onRestored,
    this.persistent = true,
  });

  final String scope;
  final bool persistent;
  final Set<String> initial;
  final ValueChanged<Set<String>>? onRestored;
  final Widget Function(BuildContext, Set<String>, ValueChanged<Set<String>>)
  builder;

  @override
  State<SourceCategoryBlockScope> createState() =>
      _SourceCategoryBlockScopeState();
}

class _SourceCategoryBlockScopeState extends State<SourceCategoryBlockScope> {
  late Set<String> _blocked = {...widget.initial};
  bool _overridden = false;
  int _epoch = 0;
  (Set<String>, bool)? _beforePendingWrite;

  @override
  void initState() {
    super.initState();
    SourceListBlockPreferences.changes.addListener(_changed);
    unawaited(_load());
  }

  void _changed() {
    // Notifications include other scopes and restore operations. A save
    // reconciles storage itself when it finishes, including on failure.
    if (_beforePendingWrite == null) unawaited(_load());
  }

  @override
  void didUpdateWidget(SourceCategoryBlockScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        oldWidget.persistent != widget.persistent) {
      _beforePendingWrite = null;
      _blocked = {...widget.initial};
      _overridden = false;
      unawaited(_load());
    } else if (!_overridden && !setEquals(oldWidget.initial, widget.initial)) {
      _blocked = {...widget.initial};
    }
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    if (!widget.persistent) return;
    try {
      final saved = await SourceListBlockPreferences.read(widget.scope);
      if (!mounted || epoch != _epoch) return;
      final next = saved ?? widget.initial;
      if (setEquals(_blocked, next) && _overridden == (saved != null)) return;
      setState(() {
        _blocked = {...next};
        _overridden = saved != null;
      });
      widget.onRestored?.call({...next});
    } catch (_) {
      if (mounted && epoch == _epoch) _showFailure(read: true);
    }
  }

  void _showFailure({bool read = false}) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(read ? t.error.loadFailed : t.error.saveFailed)),
      );

  void _change(Set<String> value) {
    final baseline = (_blocked, _overridden);
    final scope = widget.scope, epoch = ++_epoch;
    final snapshot = {...value};
    setState(() {
      _blocked = snapshot;
      _overridden = true;
    });
    if (widget.persistent) {
      unawaited(
        _save(scope, epoch, snapshot, _beforePendingWrite ??= baseline),
      );
    }
  }

  Future<void> _save(
    String scope,
    int epoch,
    Set<String> snapshot,
    (Set<String>, bool) baseline,
  ) async {
    bool ownsChange() => mounted && epoch == _epoch && scope == widget.scope;
    try {
      await SourceListBlockPreferences.write(scope, snapshot);
    } catch (_) {
      if (!ownsChange()) return;
      var (restored, overridden) = baseline;
      try {
        final saved = await SourceListBlockPreferences.read(scope);
        restored = saved ?? restored;
        overridden = saved != null;
      } catch (_) {
        // Keep the last known categories if storage cannot be read either.
      }
      if (!ownsChange()) return;
      _beforePendingWrite = null;
      setState(() {
        _blocked = restored;
        _overridden = overridden;
      });
      widget.onRestored?.call({...restored});
      _showFailure();
      return;
    }
    if (!ownsChange()) return;
    _beforePendingWrite = null;
    await _load();
  }

  @override
  void dispose() {
    _epoch++;
    SourceListBlockPreferences.changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _blocked, _change);
}
