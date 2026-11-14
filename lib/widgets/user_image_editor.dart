import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/user_image_edit.dart';

const userImageEditorRouteName = 'breeze.image.editor';

/// Edits a bounded, metadata-free image in memory. Cancellation returns no bytes
/// and never writes to storage or an account. The fixed frame is the final crop.
Future<Uint8List?> showUserImageEditor(
  BuildContext context, {
  required Uint8List bytes,
  required String title,
  required double aspectRatio,
  String? notice,
  String? confirmLabel,
  bool circularPreview = false,
}) {
  // Dialog.fullscreen only changes the dialog's content. Its PopupRoute stays
  // translucent, retaining the source page's platform-view layers underneath
  // this full-screen Flutter editor. Give this task an actual opaque page.
  // Keep showDialog's root-navigator ownership and caller theme capture.
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  Widget build(BuildContext context) => themes.wrap(
    _UserImageEditor(
      bytes: bytes,
      title: title,
      aspectRatio: aspectRatio,
      notice: notice,
      confirmLabel: confirmLabel,
      circularPreview: circularPreview,
    ),
  );
  const settings = RouteSettings(name: userImageEditorRouteName);
  return navigator.push<Uint8List>(
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? CupertinoPageRoute<Uint8List>(
            settings: settings,
            fullscreenDialog: true,
            title: title,
            builder: build,
          )
        : MaterialPageRoute<Uint8List>(
            settings: settings,
            fullscreenDialog: true,
            builder: build,
          ),
  );
}

class _UserImageEditor extends StatefulWidget {
  const _UserImageEditor({
    required this.bytes,
    required this.title,
    required this.aspectRatio,
    this.notice,
    this.confirmLabel,
    required this.circularPreview,
  });
  final Uint8List bytes;
  final String title;
  final double aspectRatio;
  final String? notice, confirmLabel;
  final bool circularPreview;
  @override
  State<_UserImageEditor> createState() => _UserImageEditorState();
}

class _UserImageEditorState extends State<_UserImageEditor> {
  Size? _imageSize;
  UserImageCrop _crop = const UserImageCrop();
  double _gestureZoom = 1;
  Offset _gestureCenter = const Offset(.5, .5);
  Offset _gestureStart = Offset.zero;
  bool _working = false, _failed = false, _cancelled = false;
  bool _gesturing = false;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  Future<void> _readSize() async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(widget.bytes);
      image = (await codec.getNextFrame()).image;
      if (image.width > 1600 || image.height > 1600) {
        throw const FormatException('Unbounded editor image');
      }
      final size = Size(image.width.toDouble(), image.height.toDouble());
      if (mounted) setState(() => _imageSize = size);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Size get _orientedSize => _crop.quarterTurns.isOdd
      ? Size(_imageSize!.height, _imageSize!.width)
      : _imageSize!;

  void _setCrop(double zoom, double x, double y) {
    final size = _orientedSize;
    final candidate = UserImageCrop(
      zoom: zoom,
      centerX: x,
      centerY: y,
      quarterTurns: _crop.quarterTurns,
    );
    final bounds = candidate.bounds(
      size.width,
      size.height,
      widget.aspectRatio,
    );
    setState(
      () => _crop = UserImageCrop(
        zoom: zoom.clamp(1.0, 6.0).toDouble(),
        centerX: (bounds.x + bounds.width / 2) / size.width,
        centerY: (bounds.y + bounds.height / 2) / size.height,
        quarterTurns: _crop.quarterTurns,
      ),
    );
  }

  Future<void> _confirm() async {
    if (_working || _imageSize == null) return;
    setState(() => _working = true);
    try {
      final edited = await compute(exportUserImageCrop, <String, Object>{
        'bytes': widget.bytes,
        'zoom': _crop.zoom,
        'centerX': _crop.centerX,
        'centerY': _crop.centerY,
        'quarterTurns': _crop.quarterTurns,
        'aspectRatio': widget.aspectRatio,
      });
      if (mounted && !_cancelled && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, edited);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _failed = true;
        });
      }
    }
  }

  Widget _preview() => LayoutBuilder(
    builder: (context, constraints) {
      final size = _orientedSize;
      final frameWidth = math.min(
        math.min(420.0, constraints.maxWidth * .8),
        constraints.maxHeight * .65 * widget.aspectRatio,
      );
      final frameHeight = frameWidth / widget.aspectRatio;
      final bounds = _crop.bounds(size.width, size.height, widget.aspectRatio);
      final scale = frameWidth / bounds.width;
      return Semantics(
        label: t.imageEditor.cropHint,
        child: Center(
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: ClipRect(
              child: GestureDetector(
                key: const ValueKey('user-image-crop-viewport'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: _working
                    ? null
                    : (details) {
                        _gestureZoom = _crop.zoom;
                        _gestureCenter = Offset(_crop.centerX, _crop.centerY);
                        _gestureStart = details.localFocalPoint;
                        setState(() => _gesturing = true);
                      },
                onScaleUpdate: _working
                    ? null
                    : (details) {
                        final zoom = (_gestureZoom * details.scale)
                            .clamp(1.0, 6.0)
                            .toDouble();
                        final newBounds = UserImageCrop(
                          zoom: zoom,
                        ).bounds(size.width, size.height, widget.aspectRatio);
                        final newScale = frameWidth / newBounds.width;
                        // Keep the point under the fingers stable while zooming and panning.
                        final focalStart =
                            _gestureStart -
                            Offset(frameWidth / 2, frameHeight / 2);
                        final focalNow =
                            details.localFocalPoint -
                            Offset(frameWidth / 2, frameHeight / 2);
                        final startScale =
                            frameWidth /
                            UserImageCrop(zoom: _gestureZoom)
                                .bounds(
                                  size.width,
                                  size.height,
                                  widget.aspectRatio,
                                )
                                .width;
                        _setCrop(
                          zoom,
                          _gestureCenter.dx +
                              (focalStart.dx / startScale -
                                      focalNow.dx / newScale) /
                                  size.width,
                          _gestureCenter.dy +
                              (focalStart.dy / startScale -
                                      focalNow.dy / newScale) /
                                  size.height,
                        );
                      },
                onScaleEnd: (_) {
                  if (mounted) setState(() => _gesturing = false);
                },
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: -bounds.x * scale,
                      top: -bounds.y * scale,
                      width: size.width * scale,
                      height: size.height * scale,
                      child: RotatedBox(
                        quarterTurns: _crop.quarterTurns,
                        child: Image.memory(
                          widget.bytes,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CropGrid(
                            circular: widget.circularPreview,
                            showGrid: _gesturing,
                            maskColor: Theme.of(context).colorScheme.surface,
                            outlineColor: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  void _cancel() {
    _cancelled = true;
    Navigator.pop(context);
  }

  Widget _navigation(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        NativeVideoIconButton(
          key: const ValueKey('image-editor-cancel'),
          icon: Icons.close,
          symbol: 'xmark',
          tooltip: t.common.cancel,
          light: false,
          onPressed: _cancel,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        NativeVideoIconButton(
          key: const ValueKey('image-editor-confirm'),
          icon: Icons.check,
          symbol: 'checkmark',
          tooltip: widget.confirmLabel ?? t.common.done,
          light: false,
          onPressed: _working || _imageSize == null ? null : _confirm,
        ),
      ],
    ),
  );

  Widget _tools(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _working || _imageSize == null
                    ? null
                    : () => setState(
                        () => _crop = UserImageCrop(
                          quarterTurns: (_crop.quarterTurns + 1) % 4,
                        ),
                      ),
                icon: const Icon(Icons.rotate_right),
                label: Text(t.imageEditor.rotate),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _working || _imageSize == null
                    ? null
                    : () => setState(() => _crop = const UserImageCrop()),
                icon: const Icon(Icons.restart_alt),
                label: Text(t.imageEditor.reset),
              ),
            ],
          ),
        ),
        if (widget.notice?.isNotEmpty == true) SettingNote(widget.notice!),
        if (_working)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(t.imageEditor.processing)),
              ],
            ),
          ),
        if (_failed && _imageSize != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              t.coverPrivacy.invalidImage,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('user-image-editor-page'),
    backgroundColor: Theme.of(context).colorScheme.surface,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 768),
          child: Column(
            children: [
              _navigation(context),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Keep the photo and its controls in separate regions.
                    // Large text can scroll the tools without moving the crop
                    // or the always-available Cancel/Done navigation.
                    final minimumStage = math.min(
                      140.0,
                      constraints.maxHeight / 2,
                    );
                    final maximumTools = math.max(
                      0.0,
                      constraints.maxHeight - minimumStage,
                    );
                    final toolsHeight = (constraints.maxHeight * .42)
                        .clamp(math.min(100.0, maximumTools), maximumTools)
                        .toDouble();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ColoredBox(
                            key: const ValueKey('image-editor-canvas'),
                            color: Theme.of(context).colorScheme.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _imageSize == null
                                  ? Center(
                                      child: _failed
                                          ? Text(t.coverPrivacy.invalidImage)
                                          : const CircularProgressIndicator(),
                                    )
                                  : _preview(),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: toolsHeight),
                          child: SingleChildScrollView(
                            key: const ValueKey('image-editor-tools-scroll'),
                            primary: false,
                            child: _tools(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// This is only a final-use preview. Avatar exports remain square image
/// bytes; the caller explicitly requests a circle, independently of icon crops.
class _CropGrid extends CustomPainter {
  const _CropGrid({
    required this.circular,
    required this.showGrid,
    required this.maskColor,
    required this.outlineColor,
  });
  final bool circular, showGrid;
  final Color maskColor, outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Path()..addOval(rect);
    if (circular) {
      canvas.drawPath(
        Path.combine(
          ui.PathOperation.difference,
          Path()..addRect(rect),
          circle,
        ),
        Paint()..color = maskColor.withValues(alpha: .85),
      );
      canvas.save();
      canvas.clipPath(circle);
    }
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .45)
      ..strokeWidth = .5;
    if (showGrid) {
      for (final fraction in [1 / 3, 2 / 3]) {
        canvas.drawLine(
          Offset(size.width * fraction, 0),
          Offset(size.width * fraction, size.height),
          gridPaint,
        );
        canvas.drawLine(
          Offset(0, size.height * fraction),
          Offset(size.width, size.height * fraction),
          gridPaint,
        );
      }
    }
    if (circular) canvas.restore();
    final outline = Paint()
      ..color = circular ? Colors.white : outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (circular) {
      canvas.drawOval(rect.deflate(.5), outline);
    } else {
      canvas.drawRect(rect.deflate(.5), outline);
    }
  }

  @override
  bool shouldRepaint(_CropGrid oldDelegate) =>
      circular != oldDelegate.circular ||
      showGrid != oldDelegate.showGrid ||
      maskColor != oldDelegate.maskColor ||
      outlineColor != oldDelegate.outlineColor;
}
