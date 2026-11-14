import 'dart:async';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_state.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/page/comic_read/comic_read.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';

/// Reports a decoded page to the active reader's history owner.
class ReaderDecodedImageScope extends InheritedWidget {
  const ReaderDecodedImageScope({
    super.key,
    required this.onDecoded,
    required this.offline,
    required super.child,
  });

  final void Function(String chapterId, int page) onDecoded;
  final bool offline;

  static ReaderDecodedImageScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderDecodedImageScope>();

  @override
  bool updateShouldNotify(ReaderDecodedImageScope oldWidget) =>
      onDecoded != oldWidget.onDecoded || offline != oldWidget.offline;
}

class ReadImageWidget extends StatefulWidget {
  final PictureInfo pictureInfo;
  final int index;
  final bool isColumn;
  final bool useDownloads;
  final int? cacheIndex;
  final int? displayNumber;
  final int? chapterPage;
  final Alignment imageAlignment;
  final PictureBloc Function()? pictureBlocFactory;

  const ReadImageWidget({
    super.key,
    required this.pictureInfo,
    required this.index,
    required this.isColumn,
    this.useDownloads = true,
    this.cacheIndex,
    this.displayNumber,
    this.chapterPage,
    this.imageAlignment = Alignment.center,
    this.pictureBlocFactory,
  });

  @override
  State<ReadImageWidget> createState() => _ReadImageWidgetState();
}

class _ReadImageWidgetState extends State<ReadImageWidget>
    with WidgetsBindingObserver {
  late PictureBloc _bloc;
  StreamSubscription<ReaderState>? _slotSubscription;
  ReaderCubit? _reader;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _createBloc();
  }

  void _createBloc() {
    _bloc =
        (widget.pictureBlocFactory?.call() ??
              PictureBloc(
                initiallyActive: false,
                useDownloads: widget.useDownloads,
              ))
          ..add(
            GetPicture(
              widget.pictureInfo.copyWith(pictureType: PictureType.page),
            ),
          );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reader = context.read<ReaderCubit>();
    if (!identical(reader, _reader)) {
      unawaited(_slotSubscription?.cancel());
      _reader = reader;
      _slotSubscription = reader.stream.listen((_) => _syncRecovery());
    }
    _syncRecovery();
  }

  void _syncRecovery() {
    if (!mounted) return;
    final current = _reader?.state.currentSlot ?? widget.index;
    _bloc.setRecoveryActive(
      _foreground &&
          TickerMode.of(context) &&
          ModalRoute.of(context)?.isCurrent != false &&
          (widget.index - current).abs() <= 1,
    );
  }

  @override
  void didUpdateWidget(covariant ReadImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pictureInfo != oldWidget.pictureInfo ||
        widget.useDownloads != oldWidget.useDownloads) {
      unawaited(_bloc.close());
      _createBloc();
    }
    _syncRecovery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncRecovery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_slotSubscription?.cancel());
    unawaited(_bloc.close());
    super.dispose();
  }

  int get displayIndex => widget.displayNumber ?? widget.index + 1;
  int get cacheIndex => widget.cacheIndex ?? widget.index;
  bool get isColumn => widget.isColumn;

  @override
  Widget build(BuildContext context) {
    final decoded = ReaderDecodedImageScope.of(context);
    final chapterPage = widget.chapterPage;
    final readSetting = context.watchEffectiveReadSetting();
    final brightness = Theme.of(context).brightness;
    final backgroundColor = readSetting.resolveReaderBackgroundColor(
      brightness,
    );
    final foregroundColor = readSetting.resolveReaderForegroundColor(
      brightness,
    );
    return BlocProvider.value(
      value: _bloc,
      child: SizedBox(
        width: context.screenWidth,
        child: BlocBuilder<PictureBloc, PictureLoadState>(
          builder: (context, state) {
            switch (state.status) {
              case PictureLoadStatus.initial:
                return placeholder(
                  backgroundColor: backgroundColor,
                  foregroundColor: foregroundColor,
                );
              case PictureLoadStatus.success:
                return GestureDetector(
                  onLongPress: () {
                    context.pushRoute(
                      FullRouteImageRoute(imagePath: state.imagePath!),
                    );
                  },
                  child: Container(
                    color: backgroundColor,
                    child: SourceImageFilterQualityBuilder(
                      source: widget.pictureInfo.from,
                      builder: (context, filterQuality) => ImageDisplay(
                        key: ValueKey((widget.pictureInfo, state.imagePath)),
                        imagePath: state.imagePath!,
                        isColumn: isColumn,
                        pageSlotIndex: widget.index,
                        sizeCacheIndex: cacheIndex,
                        imageAlignment: widget.imageAlignment,
                        onFirstFrame: decoded == null || chapterPage == null
                            ? null
                            : () => decoded.onDecoded(
                                widget.pictureInfo.chapterId,
                                chapterPage,
                              ),
                        onDecodeError: (error) => unawaited(
                          _bloc.reportDecodeFailure(
                            error,
                            imagePath: state.imagePath,
                          ),
                        ),
                        filterQuality: filterQuality,
                      ),
                    ),
                  ),
                );
              case PictureLoadStatus.failure:
                if (_bloc.recovering) {
                  return placeholder(
                    backgroundColor: backgroundColor,
                    foregroundColor: foregroundColor,
                  );
                }
                if (decoded?.offline == true) {
                  return ColoredBox(
                    color: backgroundColor,
                    child: Center(
                      child: Text(
                        t.download.fileUnavailable,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: foregroundColor, fontSize: 20),
                      ),
                    ),
                  );
                }
                if (_bloc.pictureNotFound) {
                  return Image.asset(
                    'asset/image/error_image/404.png',
                    fit: BoxFit.fill,
                  );
                } else {
                  return Container(
                    color: backgroundColor,
                    child: InkWell(
                      onTap: () {
                        context.read<PictureBloc>().add(
                          GetPicture(
                            widget.pictureInfo.copyWith(
                              pictureType: PictureType.page,
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: Text(
                          t.reader.imageLoadFailedRetry(
                            error: userFacingErrorMessage(state.result ?? ''),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            color: foregroundColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
            }
          },
        ),
      ),
    );
  }

  Widget placeholder({
    required Color backgroundColor,
    required Color foregroundColor,
  }) => Container(
    color: backgroundColor,
    child: Center(
      child: Text(
        displayIndex.toString(),
        style: TextStyle(
          fontFamily: 'Pacifico-Regular',
          color: foregroundColor,
          fontSize: 150,
        ),
      ),
    ),
  );
}
