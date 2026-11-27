import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/widgets/android_glass_plate.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_motion.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

bool usesSystemSearchSurface(BuildContext context) =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    AppInterfaceStyleScope.usesSystem(context) &&
    !context.select<GlobalSettingCubit?, bool>(
      (cubit) => cubit?.state.eInkSetting.enabled ?? false,
    );

bool usesAndroidSearchSurface(BuildContext context) =>
    AppInterfaceStyleScope.usesAndroidSystem(context) &&
    !context.select<GlobalSettingCubit?, bool>(
      (cubit) => cubit?.state.eInkSetting.enabled ?? false,
    );

BorderRadius searchFieldRadius(BuildContext context) => BorderRadius.circular(
  usesSystemSearchSurface(context) || usesAndroidSearchSurface(context)
      ? 999
      : 12,
);

/// Reveal an editor that has replaced its trigger in the same toolbar slot.
/// Keep the editor laid out at its final size while revealing its capsule.
class AndroidSearchExpansion extends StatelessWidget {
  const AndroidSearchExpansion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return child;
    final duration =
        usesAndroidSearchSurface(context) && !MediaQuery.highContrastOf(context)
        ? BreezeControlMotion.press(context, pressed: false)
        : Duration.zero;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final startWidth = CollectionToolbarMetrics.actionExtentOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: duration == Duration.zero ? 1 : 0, end: 1),
      duration: duration,
      curve: BreezeControlMotion.curve,
      child: child,
      builder: (context, value, child) {
        final revealing = duration != Duration.zero && value < 1;
        return ClipRRect(
          clipBehavior: revealing ? Clip.antiAlias : Clip.none,
          clipper: revealing
              ? _SearchExpansionClip(value, startWidth, rtl)
              : null,
          child: child,
        );
      },
    );
  }
}

class _SearchExpansionClip extends CustomClipper<RRect> {
  const _SearchExpansionClip(this.progress, this.startWidth, this.rtl);

  final double progress, startWidth;
  final bool rtl;

  @override
  RRect getClip(Size size) {
    final remaining = (size.width - startWidth).clamp(0.0, size.width);
    final revealWidth = size.width - remaining * (1 - progress);
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rtl ? 0 : size.width - revealWidth,
        0,
        revealWidth,
        size.height,
      ),
      Radius.circular(size.height / 2),
    );
  }

  @override
  bool shouldReclip(_SearchExpansionClip oldClipper) =>
      progress != oldClipper.progress ||
      startWidth != oldClipper.startWidth ||
      rtl != oldClipper.rtl;
}

/// UIKit owns the material and capsule clipping. Flutter retains one editor.
/// Rounded Flutter clips must wrap only Flutter-painted content: applying one
/// to the platform view can slice later text out of iOS route/modal overlays.
class SearchFieldSurface extends StatelessWidget {
  const SearchFieldSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = searchFieldRadius(context);
    final android = usesAndroidSearchSurface(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final colors = Theme.of(context).colorScheme;
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final surface = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: usesSystemSearchSurface(context)
                  ? NativeViewOcclusion(
                      child: UiKitView(
                        key: ValueKey((
                          Theme.of(context).brightness,
                          highContrast,
                        )),
                        viewType: 'breeze.search.surface',
                        creationParams: {
                          'dark':
                              Theme.of(context).brightness == Brightness.dark,
                          'highContrast': highContrast,
                        },
                        creationParamsCodec: const StandardMessageCodec(),
                      ),
                    )
                  : android && !highContrast
                  ? AndroidGlassPlate(
                      role: AndroidGlassRole.search,
                      corners: radius,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: radius,
                        gradient: breeze
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.alphaBlend(
                                    colors.shadow.withValues(alpha: .045),
                                    colors.surfaceContainerHigh,
                                  ),
                                  colors.surfaceContainerHigh,
                                ],
                              )
                            : null,
                        border: (breeze || android) && highContrast
                            ? Border.all(color: colors.outline)
                            : null,
                      ),
                    ),
            ),
          ),
        ),
        ClipRRect(borderRadius: radius, child: child),
      ],
    );
    final height = SearchToolbarScope.of(context);
    return height == null ? surface : SizedBox(height: height, child: surface);
  }
}
