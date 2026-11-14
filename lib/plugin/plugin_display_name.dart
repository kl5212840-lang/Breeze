import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:objectbox/objectbox.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';

const pluginDisplayNameKey = 'ui.displayName';
const pluginDisplayNameMaximumLength = 80;

String normalizePluginDisplayName(Object? value) {
  if (value is! String) return '';
  final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return name.runes.length <= pluginDisplayNameMaximumLength ? name : '';
}

String readPluginDisplayName(String source) => normalizePluginDisplayName(
  loadPluginConfigValue<Object?>(source, pluginDisplayNameKey, fallback: null),
);

Future<void> savePluginDisplayName(
  String source,
  String value, {
  required String expectedName,
}) async {
  final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.runes.length > pluginDisplayNameMaximumLength) {
    throw const FormatException('Display name too long');
  }
  if (readPluginDisplayName(source) != expectedName) {
    throw StateError('Display name changed while editing');
  }
  // Empty text is an explicit, versioned preference reset. Do not delete the
  // PluginConfig row or touch the source's account and plugin identity fields.
  savePluginConfigValueSync(source, pluginDisplayNameKey, name);
  if (readPluginDisplayName(source) != name) {
    throw StateError('Display name write was not confirmed');
  }
}

class _DisplayNameWatch extends ChangeNotifier {
  _DisplayNameWatch(Store store, String source) {
    _query = store
        .box<PluginConfig>()
        .query(PluginConfig_.name.equals(source))
        .build();
    _read();
    _subscription = store.entityChanges.listen((types) {
      if (types.contains(PluginConfig)) _read();
    });
  }
  late final Query<PluginConfig> _query;
  StreamSubscription<List<Type>>? _subscription;
  String name = '';
  int users = 0;
  void _read() {
    try {
      final raw = _query.findFirst()?.config;
      Object? data;
      try {
        data = raw == null ? null : jsonDecode(raw);
      } on FormatException {
        // Unreadable preference content falls back to the original plugin name.
      }
      final next = normalizePluginDisplayName(
        data is Map ? data[pluginDisplayNameKey] : null,
      );
      if (next == name) return;
      name = next;
      notifyListeners();
    } catch (_) {
      // Retain the last readable value on an actual storage read failure.
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _query.close();
    super.dispose();
  }
}

/// One source-filtered owned query per store/source, shared by all card/title
/// consumers. Settings updates and restores are observed without plugin IO.
class PluginDisplayNameBuilder extends StatefulWidget {
  const PluginDisplayNameBuilder({
    super.key,
    required this.source,
    required this.fallback,
    required this.builder,
  });
  final String source, fallback;
  final Widget Function(BuildContext, String) builder;
  @override
  State<PluginDisplayNameBuilder> createState() =>
      _PluginDisplayNameBuilderState();
}

class _PluginDisplayNameBuilderState extends State<PluginDisplayNameBuilder> {
  static final _watches = <(Store, String), _DisplayNameWatch>{};
  (Store, String)? _key;
  _DisplayNameWatch? _watch;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(PluginDisplayNameBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (canonicalQjsSource(oldWidget.source) !=
        canonicalQjsSource(widget.source)) {
      _release();
      _bind();
    }
  }

  void _bind() {
    try {
      final source = canonicalQjsSource(widget.source);
      final store = objectbox.store;
      final key = (store, source);
      final watch = _watches.putIfAbsent(
        key,
        () => _DisplayNameWatch(store, source),
      );
      _key = key;
      _watch = watch;
      watch.users++;
      watch.addListener(_changed);
    } catch (_) {
      // Bare component hosts may have no database. The plugin name remains usable.
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _release() {
    final watch = _watch;
    if (watch == null) return;
    watch.removeListener(_changed);
    if (--watch.users == 0) {
      _watches.remove(_key);
      watch.dispose();
    }
    _watch = null;
    _key = null;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _watch?.name.isNotEmpty == true ? _watch!.name : widget.fallback,
  );
}
