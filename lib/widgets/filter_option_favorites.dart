import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_tag_pin.dart';

/// Favorites are display preferences. Callers continue to own their draft.
class FilterOptionFavorites extends ChangeNotifier {
  FilterOptionFavorites(this.scope) {
    ShelfFacetPreferences.changes.addListener(_changed);
    PortablePreferences.changes.addListener(_changed);
  }

  final String scope;
  final _pins = <String, Set<String>>{};
  final _epochs = <String, int>{};
  final _errors = <String>{};
  final _saving = <String>{};
  bool _disposed = false;

  String _key(String dimension) => '$scope|facet:$dimension';

  void _changed() => unawaited(_reload());

  Future<void> _reload() async {
    await Future.wait(_epochs.keys.toList().map(_read));
  }

  Future<void> _read(String dimension) async {
    final epoch = (_epochs[dimension] ?? 0) + 1;
    _epochs[dimension] = epoch;
    try {
      final values = await ShelfFacetPreferences.load(_key(dimension));
      if (_disposed || _epochs[dimension] != epoch) return;
      final changed = !setEquals(values, _pins[dimension]);
      final recovered = _errors.remove(dimension);
      _pins[dimension] = values;
      if (changed || recovered) notifyListeners();
    } catch (_) {
      if (!_disposed && _epochs[dimension] == epoch && _errors.add(dimension)) {
        notifyListeners();
      }
    }
  }

  Set<String> _options(String dimension) {
    if (!_epochs.containsKey(dimension)) unawaited(_read(dimension));
    return _pins[dimension] ?? const {};
  }

  bool isPinned(String dimension, String value) =>
      _options(dimension).contains(shelfFacetEncodeValue(value));

  List<T> order<T>(
    String dimension,
    Iterable<T> options,
    String Function(T) value,
  ) {
    final pins = _options(dimension);
    final ordered = options.toList();
    if (pins.isEmpty) return ordered;
    bool pinned(T option) =>
        pins.contains(shelfFacetEncodeValue(value(option)));
    return [...ordered.where(pinned), ...ordered.where((o) => !pinned(o))];
  }

  Widget star(
    BuildContext context,
    String dimension,
    String value,
    String label, {
    bool enabled = true,
  }) {
    if (value.trim().isEmpty) return const SizedBox.square(dimension: 44);
    final stored = shelfFacetEncodeValue(value);
    final pinned = _options(dimension).contains(stored);
    return ShelfTagPinButton(
      key: ValueKey('filter-favorite-$dimension-$value'),
      pinned: pinned,
      tooltip: ShelfTagPinButton.optionTooltip(
        context,
        label: label,
        pinned: pinned,
      ),
      onPressed:
          enabled &&
              !_saving.contains(dimension) &&
              (_pins.containsKey(dimension) || _errors.contains(dimension))
          ? () => _toggle(context, dimension, stored)
          : null,
    );
  }

  Future<void> _toggle(
    BuildContext context,
    String dimension,
    String value,
  ) async {
    if (!_saving.add(dimension)) return;
    notifyListeners();
    try {
      if (_errors.contains(dimension)) await _read(dimension);
      if (_disposed) return;
      if (_errors.contains(dimension)) {
        throw StateError('Cannot load favorites');
      }
      await ShelfFacetPreferences.toggle(_key(dimension), value);
      if (!_disposed) await _read(dimension);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'zh'
                  ? '筛选收藏保存失败，请重试'
                  : 'Unable to save filter favorite. Try again.',
            ),
          ),
        );
      }
    } finally {
      _saving.remove(dimension);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ShelfFacetPreferences.changes.removeListener(_changed);
    PortablePreferences.changes.removeListener(_changed);
    super.dispose();
  }
}
