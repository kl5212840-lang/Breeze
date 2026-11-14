import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

bool usesSystemSearchSurface(BuildContext context) =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    AppInterfaceStyleScope.usesSystem(context) &&
    !context.select<GlobalSettingCubit?, bool>(
      (cubit) => cubit?.state.eInkSetting.enabled ?? false,
    );

BorderRadius searchFieldRadius(BuildContext context) =>
    BorderRadius.circular(usesSystemSearchSurface(context) ? 999 : 12);

/// UIKit owns the material and capsule clipping. Flutter retains one editor.
/// Rounded Flutter clips must wrap only Flutter-painted content: applying one
/// to the platform view can slice later text out of iOS route/modal overlays.
class SearchFieldSurface extends StatelessWidget {
  const SearchFieldSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = searchFieldRadius(context);
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
                          MediaQuery.highContrastOf(context),
                        )),
                        viewType: 'breeze.search.surface',
                        creationParams: {
                          'dark':
                              Theme.of(context).brightness == Brightness.dark,
                          'highContrast': MediaQuery.highContrastOf(context),
                        },
                        creationParamsCodec: const StandardMessageCodec(),
                      ),
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
                        border: breeze && MediaQuery.highContrastOf(context)
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
