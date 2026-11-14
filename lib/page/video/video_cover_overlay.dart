import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// A bare, complete clock supplied by the source is duration evidence. Labels
/// containing watch progress, episode numbers or other prose are not clocks.
String clockVideoDurationText(String raw) {
  final clock = RegExp(
    r'^(\d{1,4}):([0-5]\d)(?::([0-5]\d))?$',
  ).firstMatch(raw.trim());
  if (clock == null) return '';
  final first = int.parse(clock[1]!), second = int.parse(clock[2]!);
  final seconds = clock[3] == null
      ? first * 60 + second
      : first * 3600 + second * 60 + int.parse(clock[3]!);
  return formatKnownVideoDuration(Duration(seconds: seconds));
}

String videoCoverDurationText(
  String sourceDuration, {
  String clockFallback = '',
}) {
  final known = knownVideoDurationText(sourceDuration);
  return known.isNotEmpty ? known : clockVideoDurationText(clockFallback);
}

String knownVideoDurationText(String raw) {
  final text = raw.trim();
  if (text.isEmpty ||
      text.length > 120 ||
      const {'--', '--:--', 'unknown', 'n/a'}.contains(text.toLowerCase()) ||
      RegExp(r'^0+(?::00){0,2}$').hasMatch(text))
    return '';
  if (RegExp(r'^\d+(?::\d+)+$').hasMatch(text))
    return clockVideoDurationText(text);
  return text;
}

String formatKnownVideoDuration(Duration value) {
  if (value.inSeconds <= 0) return '';
  final seconds = value.inSeconds;
  final tail = (seconds % 60).toString().padLeft(2, '0');
  return seconds < 3600
      ? '${seconds ~/ 60}:$tail'
      : '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:$tail';
}

/// A media label above protected pixels. It never owns taps or long presses.
/// Callers opt in only for video posters, not avatars or collection artwork.
class VideoCoverOverlay extends StatelessWidget {
  const VideoCoverOverlay({
    super.key,
    required this.child,
    this.durationText = '',
  });
  final Widget child;
  final String durationText;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final duration = knownVideoDurationText(durationText);
      final smallPoster = constraints.maxWidth < 96;
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          PositionedDirectional(
            start: 4,
            end: 4,
            bottom: 4,
            child: IgnorePointer(
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Semantics(
                  image: true,
                  label: duration.isEmpty
                      ? t.videoFilters.videos
                      : '${t.videoFilters.videos} · ${t.videoMetadata.duration(value: duration)}',
                  excludeSemantics: true,
                  child: DecoratedBox(
                    key: const ValueKey('video-cover-badge'),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              key: const ValueKey('video-cover-marker'),
                              size: smallPoster ? 12 : 15,
                              color: Colors.white,
                            ),
                            if (duration.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                duration,
                                maxLines: 1,
                                softWrap: false,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
