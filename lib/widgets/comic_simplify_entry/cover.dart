import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/util/context/context_extensions.dart';

import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';

class CoverWidget extends StatefulWidget {
  final String fileServer;
  final String path;
  final String id;
  final PictureType pictureType;
  final String from;
  final bool roundedCorner;
  final double? width;
  final double? height;

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
    _bloc = PictureBloc()..add(GetPicture(_pictureInfo));
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
      _bloc = PictureBloc()..add(GetPicture(_pictureInfo));
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
        child: BlocBuilder<PictureBloc, PictureLoadState>(
          bloc: _bloc,
          // 只在图片路径/状态变化时重建，避免无关 rebuild 重新 resolve。
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.imagePath != curr.imagePath ||
              prev.result != curr.result,
          builder: (context, state) {
            switch (state.status) {
              case PictureLoadStatus.initial:
                if (widget.pictureType == PictureType.category) {
                  return const _CategoryCoverFallback();
                }
                return Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(
                      widget.roundedCorner ? kComicCardBorderRadius : 0.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.image, color: Colors.grey[300], size: 30),
                  ),
                );
              case PictureLoadStatus.success:
                // image 对象缓存：选中切换等无关 rebuild 不 new provider，
                // DecorationImage 相等就不重新 resolve，封面不闪。
                final key = (
                  path: state.imagePath!,
                  width: decodeWidth < 1 ? 1 : decodeWidth,
                  height: decodeHeight < 1 ? 1 : decodeHeight,
                );
                if (_imageKey != key) {
                  _imageKey = key;
                  _imageProvider = ResizeImage(
                    FileImage(File(key.path)),
                    width: key.width,
                    height: key.height,
                  );
                }
                return RepaintBoundary(
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(
                        widget.roundedCorner ? 5.0 : 0.0,
                      ),
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: _imageProvider!,
                        onError: (error, stackTrace) {
                          logger.d(
                            '图片解码失败: ${state.imagePath}',
                            error: error,
                            stackTrace: stackTrace,
                          );
                        },
                      ),
                    ),
                  ),
                );
              case PictureLoadStatus.failure:
                if (widget.pictureType == PictureType.category) {
                  return const _CategoryCoverFallback();
                }
                if (state.result.toString().contains('404')) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(kComicCardBorderRadius),
                    child: Image.asset(
                      'asset/image/error_image/404.png',
                      fit: BoxFit.cover,
                    ),
                  );
                } else {
                  return InkWell(
                    onTap: () {
                      context.read<PictureBloc>().add(GetPicture(_pictureInfo));
                    },
                    child: Center(child: Icon(Icons.refresh)),
                  );
                }
            }
          },
        ),
      ),
    );
  }
}

class _CategoryCoverFallback extends StatelessWidget {
  const _CategoryCoverFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(kComicCardBorderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: 36,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
