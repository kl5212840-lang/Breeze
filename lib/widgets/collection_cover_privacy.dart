import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/i18n/strings.g.dart';

part 'collection_cover_privacy.freezed.dart';

enum CollectionCoverStyle { blur, mosaic, glass, custom }

@freezed
abstract class CollectionCoverPrivacySettings
    with _$CollectionCoverPrivacySettings {
  const factory CollectionCoverPrivacySettings({
    @Default(false) bool enabled,
    @Default(CollectionCoverStyle.blur) CollectionCoverStyle style,
    @Default(false) bool ready,
  }) = _CollectionCoverPrivacySettings;
}

class CollectionCoverPrivacyController {
  CollectionCoverPrivacyController._();
  @visibleForTesting
  CollectionCoverPrivacyController.forTesting();
  static final instance = CollectionCoverPrivacyController._();
  static const enabledKey = 'breeze.local.collection-cover.enabled.v1';
  static const styleKey = 'breeze.collection-cover.style.v1';
  final state = ValueNotifier(const CollectionCoverPrivacySettings());

  /// The host resolves the selected artwork to this device's local path.
  /// Device protection remains independent of the portable artwork mapping.
  final localImagePath = ValueNotifier<String?>(null);
  Future<void>? _loading;
  Future<void> _enabledWrites = Future.value();
  Future<void> _styleWrites = Future.value();
  int _enabledRevision = 0;

  CollectionCoverStyle _style(String? name) =>
      CollectionCoverStyle.values.firstWhere(
        (style) => style.name == name,
        orElse: () => CollectionCoverStyle.blur,
      );

  Future<void> ensureLoaded() {
    if (state.value.ready) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      state.value = CollectionCoverPrivacySettings(
        enabled: preferences.getBool(enabledKey) ?? false,
        style: _style(preferences.getString(styleKey)),
        ready: true,
      );
    } catch (_) {
      // A preference read failure must not reveal the collection's original image.
      state.value = state.value.copyWith(enabled: true, ready: true);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await ensureLoaded();
    final revision = ++_enabledRevision;
    if (enabled) state.value = state.value.copyWith(enabled: true);
    final write = _enabledWrites.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool(enabledKey, enabled)) {
        throw StateError(t.coverPrivacy.saveFailed);
      }
      // A later enable must never be undone by an earlier disable completing.
      if (revision == _enabledRevision) {
        state.value = state.value.copyWith(enabled: enabled);
      }
    });
    _enabledWrites = write.catchError((Object _) {});
    return write;
  }

  Future<void> setStyle(CollectionCoverStyle style) async {
    await ensureLoaded();
    final write = _styleWrites.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(styleKey, style.name)) {
        throw StateError(t.coverPrivacy.styleSaveFailed);
      }
      state.value = state.value.copyWith(style: style);
    });
    _styleWrites = write.catchError((Object _) {});
    return write;
  }

  Future<void> flushStyle() => _styleWrites;

  Future<void> reloadStyle() async {
    await ensureLoaded();
    await flushStyle();
    final preferences = await SharedPreferences.getInstance();
    state.value = state.value.copyWith(
      style: _style(preferences.getString(styleKey)),
    );
  }
}

/// Only an explicit collection scope opts in. Disabled nested scopes opt out.
class CollectionCoverPrivacyScope extends InheritedWidget {
  const CollectionCoverPrivacyScope({
    super.key,
    required super.child,
    this.enabled = true,
  });
  final bool enabled;
  static bool contains(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CollectionCoverPrivacyScope>()
          ?.enabled ??
      false;
  @override
  bool updateShouldNotify(CollectionCoverPrivacyScope oldWidget) =>
      enabled != oldWidget.enabled;
}

class CollectionCoverPrivacy extends StatelessWidget {
  const CollectionCoverPrivacy({
    super.key,
    required this.child,
    this.enabled = true,
    this.fit = BoxFit.cover,
    this.image,
    this.mosaicPlaceholder,
  });
  final BoxFit fit;
  final ImageProvider? image;
  final Widget? mosaicPlaceholder;
  final Widget child;
  final bool enabled;

  ui.ImageFilter _filter(CollectionCoverStyle style) => ui.ImageFilter.blur(
    sigmaX: style == CollectionCoverStyle.glass ? 30 : 24,
    sigmaY: style == CollectionCoverStyle.glass ? 30 : 24,
    tileMode: TileMode.clamp,
  );

  @override
  Widget build(BuildContext context) {
    if (!enabled || !CollectionCoverPrivacyScope.contains(context)) {
      return child;
    }
    final controller = CollectionCoverPrivacyController.instance;
    return ValueListenableBuilder<CollectionCoverPrivacySettings>(
      valueListenable: controller.state,
      child: child,
      builder: (context, settings, original) {
        final protected = !settings.ready || settings.enabled;
        final style = settings.ready
            ? settings.style
            : CollectionCoverStyle.blur;
        return ValueListenableBuilder<String?>(
          valueListenable: controller.localImagePath,
          child: original,
          builder: (context, path, image) {
            final hasArtwork =
                protected &&
                style == CollectionCoverStyle.custom &&
                path != null &&
                path.isNotEmpty;
            final mosaic = protected && style == CollectionCoverStyle.mosaic;
            return ClipRect(
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Keep the original loading and in layout. Opaque artwork
                  // covers it even if decoding fails, so its paint can stop.
                  Opacity(
                    opacity: hasArtwork || mosaic ? 0 : 1,
                    alwaysIncludeSemantics: true,
                    child: ImageFiltered(
                      enabled: protected && !hasArtwork && !mosaic,
                      imageFilter: _filter(style),
                      child: image!,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: hasArtwork
                          ? _ReplacementCover(path: path)
                          : mosaic
                          ? _MosaicCover(
                              image: this.image,
                              fit: fit,
                              placeholder: mosaicPlaceholder,
                            )
                          : protected && style == CollectionCoverStyle.glass
                          ? ColoredBox(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0x55303030)
                                  : const Color(0x55ffffff),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Render an actual tiny image and magnify its pixels. Reciprocal transform
/// filters can be combined by the renderer before sampling the source.
class _MosaicCover extends StatefulWidget {
  const _MosaicCover({
    required this.image,
    required this.fit,
    required this.placeholder,
  });
  final ImageProvider? image;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  State<_MosaicCover> createState() => _MosaicCoverState();
}

class _MosaicCoverState extends State<_MosaicCover> {
  late final ImageStreamListener _listener = ImageStreamListener(
    _sourceReady,
    onError: (_, _) {},
  );
  ImageStream? _source;
  ui.Image? _pixels;
  var _revision = 0;
  bool _sampled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _MosaicCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _resolve();
  }

  void _resolve() {
    // Use the original provider and cache key, including its resize/network
    // policy. Never fetch a second URL or put a mosaic into the source cache.
    final next = widget.image?.resolve(createLocalImageConfiguration(context));
    if (next?.key == _source?.key) return;
    _revision++;
    _source?.removeListener(_listener);
    _pixels?.dispose();
    _pixels = null;
    _sampled = false;
    _source = next;
    next?.addListener(_listener);
  }

  Future<void> _sourceReady(ImageInfo info, bool synchronous) async {
    if (_sampled) {
      info.dispose();
      return;
    }
    _sampled = true;
    final revision = _revision;
    ui.Image? pixels;
    try {
      final source = info.image;
      const maxBlocks = 6;
      final ratio = maxBlocks / math.max(source.width, source.height);
      final width = (source.width * ratio).round().clamp(1, maxBlocks);
      final height = (source.height * ratio).round().clamp(1, maxBlocks);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..filterQuality = FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      try {
        pixels = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
    } catch (_) {
      // Missing or unsupported images keep the opaque placeholder.
    } finally {
      info.dispose();
    }
    if (!mounted || revision != _revision) {
      pixels?.dispose();
      return;
    }
    if (pixels != null) setState(() => _pixels = pixels);
  }

  @override
  void dispose() {
    _revision++;
    _source?.removeListener(_listener);
    _pixels?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: _pixels == null && widget.placeholder != null
        ? widget.placeholder!
        : RawImage(
            image: _pixels,
            fit: widget.fit,
            filterQuality: FilterQuality.none,
          ),
  );
}

class _ReplacementCover extends StatelessWidget {
  const _ReplacementCover({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final side =
            constraints.biggest.longestSide *
            MediaQuery.devicePixelRatioOf(context);
        // Reuse a small set of cache keys across a collection's row sizes.
        final limit = side <= 256 ? 256 : (side <= 512 ? 512 : 1024);
        return Image(
          image: ResizeImage(
            FileImage(File(path)),
            width: limit,
            height: limit,
            policy: ResizeImagePolicy.fit,
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      },
    ),
  );
}

class CollectionCoverPrivacyButton extends StatelessWidget {
  const CollectionCoverPrivacyButton({
    super.key,
    this.emphasizeProtected = false,
  });

  final bool emphasizeProtected;
  @override
  Widget build(BuildContext context) {
    final controller = CollectionCoverPrivacyController.instance;
    return ValueListenableBuilder<CollectionCoverPrivacySettings>(
      valueListenable: controller.state,
      builder: (context, settings, _) {
        final protected = !settings.ready || settings.enabled;
        return Semantics(
          toggled: protected,
          child: SourceChromeIconButton(
            icon: protected
                ? (emphasizeProtected
                      ? Icons.visibility_off
                      : Icons.visibility_off_outlined)
                : Icons.visibility_outlined,
            symbol: protected
                ? (emphasizeProtected ? 'eye.slash.fill' : 'eye.slash')
                : 'eye',
            tooltip: protected ? t.coverPrivacy.disable : t.coverPrivacy.enable,
            onPressed: () async {
              try {
                await controller.setEnabled(!protected);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text(t.coverPrivacy.saveFailed)),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}
