import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/toast.dart';

/// Portable appearance preference; only consumers opting into this builder
/// change their image fit. The surrounding card geometry remains unchanged.
class CollectionCoverFitController {
  CollectionCoverFitController._();
  static final instance = CollectionCoverFitController._();
  static const storageKey = 'breeze.collection-cover.fit.v1';
  final state = ValueNotifier<BoxFit>(BoxFit.cover);
  bool _loaded = false;
  Future<void>? _loading;
  Future<void> _writes = Future.value();

  BoxFit _decode(String? value) =>
      value == 'contain' ? BoxFit.contain : BoxFit.cover;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    state.value = _decode(preferences.getString(storageKey));
    _loaded = true;
  }

  Future<void> setFit(BoxFit fit) async {
    if (fit != BoxFit.contain && fit != BoxFit.cover) {
      throw ArgumentError.value(fit, 'fit');
    }
    await ensureLoaded();
    final write = _writes.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(storageKey, fit.name)) {
        throw StateError('Cover fit could not be saved');
      }
      await preferences.reload();
      if (preferences.getString(storageKey) != fit.name) {
        throw StateError('Cover fit could not be read back');
      }
      state.value = fit;
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> flush() => _writes;

  Future<void> reload() async {
    await flush();
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    state.value = _decode(preferences.getString(storageKey));
    _loaded = true;
  }
}

class CollectionCoverFitBuilder extends StatefulWidget {
  const CollectionCoverFitBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, BoxFit fit) builder;

  @override
  State<CollectionCoverFitBuilder> createState() =>
      _CollectionCoverFitBuilderState();
}

class _CollectionCoverFitBuilderState extends State<CollectionCoverFitBuilder> {
  @override
  void initState() {
    super.initState();
    unawaited(
      CollectionCoverFitController.instance.ensureLoaded().catchError(
        (Object _) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<BoxFit>(
    valueListenable: CollectionCoverFitController.instance.state,
    builder: (context, fit, _) => widget.builder(context, fit),
  );
}

class CollectionCoverFitSetting extends StatefulWidget {
  const CollectionCoverFitSetting({super.key});

  @override
  State<CollectionCoverFitSetting> createState() =>
      _CollectionCoverFitSettingState();
}

class _CollectionCoverFitSettingState extends State<CollectionCoverFitSetting> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return CollectionCoverFitBuilder(
      builder: (context, fit) => SettingChoiceTile<BoxFit>(
        leading: const Icon(Icons.fit_screen_outlined),
        title: chinese ? '封面适配' : 'Image fit',
        value: fit,
        enabled: !_busy,
        items: {
          BoxFit.contain: chinese ? '完整显示' : 'Show entire image',
          BoxFit.cover: chinese ? '填充裁切' : 'Fill and crop',
        },
        onChanged: (value) async {
          if (_busy || value == fit) return;
          setState(() => _busy = true);
          try {
            await CollectionCoverFitController.instance.setFit(value);
            if (context.mounted) {
              showSuccessToast(t.common.settingSaved, context: context);
            }
          } catch (_) {
            if (context.mounted) {
              showErrorToast(t.coverPrivacy.saveFailed, context: context);
            }
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
      ),
    );
  }
}

/// Opt in a bookshelf host without rebuilding its list or scroll controller.
class CollectionCoverFitScope extends StatelessWidget {
  const CollectionCoverFitScope({super.key, required this.child});
  final Widget child;

  static BoxFit? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CollectionCoverFitValue>()
      ?.fit;

  @override
  Widget build(BuildContext context) => CollectionCoverFitBuilder(
    builder: (context, fit) => _CollectionCoverFitValue(fit: fit, child: child),
  );
}

class _CollectionCoverFitValue extends InheritedWidget {
  const _CollectionCoverFitValue({required this.fit, required super.child});
  final BoxFit fit;

  @override
  bool updateShouldNotify(_CollectionCoverFitValue oldWidget) =>
      fit != oldWidget.fit;
}
