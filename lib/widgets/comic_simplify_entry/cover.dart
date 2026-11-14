import 'package:zephyr/widgets/picture_bloc/picture_recovery_region.dart';
import 'package:zephyr/widgets/soft_cover_background.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/util/context/context_extensions.dart';

import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';

/// Decode inside a size budget while preserving the source aspect ratio.
/// The display fit is a paint choice and does not alter the image cache key.
ImageProvider createCoverImageProvider(
  String path, {
  required int width,
  required int height,
}) => ResizeImage(
  FileImage(File(path)),
  policy: ResizeImagePolicy.fit,
  width: width,
  height: height,
);

class CoverWidget extends StatefulWidget {
  final String fileServer;
  final String path;
  final String id;
  final PictureType pictureType;
  final String from;
  final bool roundedCorner;
  final double? width;
  final double? height;
  final IconData categoryFallbackIcon;
  final BoxFit fit;
  final bool containBackground;

  const CoverWidget({
    super.key,
    required this.fileServer,
    required this.path,
    required this.id,
    required this.pictureType,
    required this.from,
    this.roundedCorner = true,
    this.width,
    this.height,
    this.categoryFallbackIcon = Icons.auto_stories_outlined,
    this.fit = BoxFit.cover,
    this.containBackground = false,
  });

  @override
  State<CoverWidget> createState() => _CoverWidgetState();
}

class _CoverWidgetState extends State<CoverWidget> {
  late PictureInfo _pictureInfo;
  late PictureBloc _bloc;
  ImageProvider? _imageProvider;
  ({String path, int width, int height})? _imageKey;

  @override
  void initState() {
    super.initState();
    _pictureInfo = _buildPictureInfo();
    // Bloc 由 State 持有：build 里只引用，不创建。
    // Keep image requests tied to picture identity instead of selection/layout.
    // BlocProvider.create itself is lazy; ordinary rebuilds do not create IO.
    _bloc = PictureBloc(initiallyActive: false)..add(GetPicture(_pictureInfo));
  }

  @override
  void didUpdateWidget(covariant CoverWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileServer != widget.fileServer ||
        oldWidget.path != widget.path ||
        oldWidget.id != widget.id ||
        oldWidget.pictureType != widget.pictureType ||
        oldWidget.from != widget.from) {
      _pictureInfo = _buildPictureInfo();
      // Only a changed picture identity requests an image. Layout changes only
      // update the decode-size key below.
      _imageProvider = null;
      _imageKey = null;
      // PictureBloc drops requests while busy. A new picture identity needs
      // its own bloc, otherwise a slow previous request can win or drop it.
      final previous = _bloc;
      _bloc = PictureBloc(initiallyActive: false)
        ..add(GetPicture(_pictureInfo));
      unawaited(previous.close());
    }
  }

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  PictureInfo _buildPictureInfo() {
    return PictureInfo(
      from: widget.from,
      url: widget.fileServer,
      path: widget.path,
      cartoonId: widget.id,
      pictureType: widget.pictureType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fit = widget.pictureType == PictureType.user
        ? widget.fit
        : CollectionCoverFitScope.maybeOf(context) ?? widget.fit;
    final softBackground =
        widget.pictureType != PictureType.user &&
        fit == BoxFit.contain &&
        (widget.containBackground ||
            CollectionCoverFitScope.maybeOf(context) != null);
    final width = widget.width ?? context.screenWidth * 0.3;
    final height = widget.height ?? (context.screenWidth * 0.3) / 0.75;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = ((width * devicePixelRatio) * 1.2).round();
    final decodeHeight = ((height * devicePixelRatio) * 1.2).round();
    return BlocProvider.value(
      value: _bloc,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            widget.roundedCorner ? kComicCardBorderRadius : 0,
          ),
          child: BlocBuilder<PictureBloc, PictureLoadState>(
            bloc: _bloc,
            // 只在图片路径/状态变化时重建，避免无关 rebuild 重新 resolve。
            buildWhen: (prev, curr) =>
                prev.status != curr.status ||
                prev.imagePath != curr.imagePath ||
                prev.result != curr.result,
            builder: (context, state) {
              final colors = Theme.of(context).colorScheme;
              // The replacement artwork belongs to privacy, so it must be
              // present before the original cover path resolves on remount.
              Widget surface(Widget pixels, {Widget? feedback}) =>
                  PictureRecoveryRegion(
                    bloc: _bloc,
                    child: ColoredBox(
                      color: colors.surfaceContainerHigh,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CollectionCoverPrivacy(
                            enabled: widget.pictureType != PictureType.user,
                            fit: fit,
                            child: pixels,
                          ),
                          ?feedback,
                        ],
                      ),
                    ),
                  );

              switch (state.status) {
                case PictureLoadStatus.initial:
                  return surface(
                    widget.pictureType == PictureType.category
                        ? _CategoryCoverFallback(
                            icon: widget.categoryFallbackIcon,
                          )
                        : Center(
                            child: Icon(
                              Icons.image,
                              color: colors.onSurfaceVariant,
                              size: 30,
                            ),
                          ),
                  );
                case PictureLoadStatus.success:
                  final key = (
                    path: state.imagePath!,
                    width: decodeWidth < 1 ? 1 : decodeWidth,
                    height: decodeHeight < 1 ? 1 : decodeHeight,
                  );
                  if (_imageKey != key) {
                    _imageKey = key;
                    _imageProvider = createCoverImageProvider(
                      key.path,
                      width: key.width,
                      height: key.height,
                    );
                  }
                  final image = _imageProvider!;
                  final bloc = _bloc;
                  return surface(
                    SourceImageFilterQualityBuilder(
                      source: widget.from,
                      builder: (context, filterQuality) => RepaintBoundary(
                        child: SoftCoverBackground(
                          image: image,
                          enabled: softBackground,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                widget.roundedCorner ? 5.0 : 0.0,
                              ),
                              image: DecorationImage(
                                fit: fit,
                                filterQuality: filterQuality,
                                image: image,
                                onError: (error, stackTrace) {
                                  unawaited(
                                    bloc.reportDecodeFailure(
                                      error,
                                      imagePath: key.path,
                                    ),
                                  );
                                  logger.d(
                                    '图片解码失败: ${key.path}',
                                    error: error,
                                    stackTrace: stackTrace,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                case PictureLoadStatus.failure:
                  if (widget.pictureType == PictureType.category) {
                    return surface(
                      _CategoryCoverFallback(icon: widget.categoryFallbackIcon),
                    );
                  }
                  if (_bloc.pictureNotFound) {
                    return surface(
                      Image.asset(
                        'asset/image/error_image/404.png',
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                  return surface(
                    const SizedBox.expand(),
                    feedback: InkWell(
                      onTap: () => _bloc.add(GetPicture(_pictureInfo)),
                      child: const Center(child: Icon(Icons.refresh)),
                    ),
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryCoverFallback extends StatelessWidget {
  const _CategoryCoverFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(kComicCardBorderRadius),
      ),
      child: Center(
        child: Icon(icon, size: 36, color: colors.onPrimaryContainer),
      ),
    );
  }
}
