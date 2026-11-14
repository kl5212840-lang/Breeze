import 'package:material_ui/material_ui.dart';
import 'dart:math' as math;
import 'package:zephyr/i18n/strings.g.dart';

/// A source's declared loading artwork changes presentation only. Requests,
/// retry ownership and page state remain with the existing feature controller.
class SourceLoadingIndicator extends StatelessWidget {
  const SourceLoadingIndicator({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) => const CircularProgressIndicator();
}

/// Original 85px artwork and timing; a static first frame is used whenever
/// motion is disabled or the persistent tab is not being displayed.
class BikaLoadingArtwork extends StatelessWidget {
  const BikaLoadingArtwork({super.key, this.extent = 72});
  final double extent;

  @override
  Widget build(BuildContext context) {
    final animate =
        TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: t.common.loading,
      image: true,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(
              extent,
              math.min(
                constraints.hasBoundedWidth ? constraints.maxWidth : extent,
                constraints.hasBoundedHeight ? constraints.maxHeight : extent,
              ),
            );
            return SizedBox.square(
              dimension: side,
              child: Image.asset(
                animate
                    ? 'asset/image/bika_experience/loading.gif'
                    : 'asset/image/bika_experience/loading-first-frame.png',
                fit: BoxFit.contain,
                cacheWidth: 85,
                cacheHeight: 85,
                errorBuilder: (_, _, _) =>
                    const Center(child: CircularProgressIndicator()),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum BikaStatusKind { error, empty }

/// The verified original status artwork, bounded by its actual host. No
/// transport/authentication state is inferred from an illustration.
class BikaStatusArtwork extends StatelessWidget {
  const BikaStatusArtwork({super.key, required this.kind, this.extent = 112});
  final BikaStatusKind kind;
  final double extent;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          extent,
          math.min(
            constraints.hasBoundedWidth ? constraints.maxWidth : extent,
            constraints.hasBoundedHeight ? constraints.maxHeight : extent,
          ),
        );
        final decode = (side * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 800)
            .toInt();
        return SizedBox.square(
          dimension: side,
          child: Image.asset(
            kind == BikaStatusKind.error
                ? 'asset/image/bika_experience/icon_exclamation_error.png'
                : 'asset/image/bika_experience/icon_empty.png',
            fit: BoxFit.contain,
            cacheWidth: decode,
            cacheHeight: decode,
            errorBuilder: (_, _, _) => Icon(
              kind == BikaStatusKind.error
                  ? Icons.wifi_off_outlined
                  : Icons.auto_stories_outlined,
            ),
          ),
        );
      },
    ),
  );
}
