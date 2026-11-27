import 'dart:async';
import 'package:zephyr/widgets/picture_bloc/picture_recovery_region.dart';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart'
    show createCoverImageProvider;

class Cover extends StatelessWidget {
  final PictureInfo pictureInfo;
  final double height;
  final double borderRadius;
  final VoidCallback? onTap;

  const Cover({
    super.key,
    required this.pictureInfo,
    this.height = 180,
    this.borderRadius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = height / 4 * 3;
    final radius = BorderRadius.circular(borderRadius);
    final decodeScale = MediaQuery.devicePixelRatioOf(context) * 1.2;

    return SizedBox(
      height: height,
      width: width,
      child: BlocProvider(
        key: ValueKey(pictureInfo),
        create: (context) =>
            PictureBloc(initiallyActive: false)..add(GetPicture(pictureInfo)),
        child: BlocBuilder<PictureBloc, PictureLoadState>(
          builder: (context, state) {
            return PictureRecoveryRegion(
              bloc: context.read<PictureBloc>(),
              child: Builder(
                builder: (context) {
                  final colors = context.theme.colorScheme;
                  final placeholderDecoration = BoxDecoration(
                    borderRadius: radius,
                    color: colors.surfaceContainerHigh,
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.35),
                    ),
                  );
                  switch (state.status) {
                    case PictureLoadStatus.initial:
                      return DecoratedBox(
                        decoration: placeholderDecoration,
                        child: Center(
                          child: LoadingAnimationWidget.waveDots(
                            color: colors.primary,
                            size: 40,
                          ),
                        ),
                      );
                    case PictureLoadStatus.success:
                      return InkWell(
                        onTap:
                            onTap ??
                            () {
                              context.pushRoute(
                                FullRouteImageRoute(
                                  imagePath: state.imagePath!,
                                ),
                              );
                            },
                        child: ClipRRect(
                          borderRadius: radius,
                          child: Image(
                            image: createCoverImageProvider(
                              state.imagePath!,
                              width: (width * decodeScale).ceil(),
                              height: (height * decodeScale).ceil(),
                            ),
                            fit: BoxFit.cover,
                            width: width,
                            height: height,
                            errorBuilder: (_, error, _) {
                              unawaited(
                                context.read<PictureBloc>().reportDecodeFailure(
                                  error,
                                  imagePath: state.imagePath,
                                ),
                              );
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      );
                    case PictureLoadStatus.failure:
                      return DecoratedBox(
                        decoration: placeholderDecoration,
                        child: Center(
                          child: Icon(
                            Icons.image,
                            color: colors.onSurfaceVariant,
                            size: 30,
                          ),
                        ),
                      );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
