import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';

enum VideoQuickSection { playback, speed, sources, episodes }

String videoSourceLabel(NativePlaybackSource source, int index) =>
    source.label.trim().isEmpty ||
        const [
          'auto',
          '当前线路',
          'current source',
        ].contains(source.label.trim().toLowerCase())
    ? t.videoPlayback.sourceNumber(index: index + 1)
    : source.label;

/// Contextual controls for the active video. Global defaults remain available
/// through the existing full settings page. No second player or route is made.
class VideoPlaybackQuickPanel extends StatelessWidget {
  const VideoPlaybackQuickPanel({
    super.key,
    required this.section,
    required this.preferences,
    required this.session,
    required this.sourceIndex,
    required this.speed,
    required this.muted,
    required this.ready,
    required this.onSpeed,
    required this.onSource,
    required this.onPreference,
    required this.onMute,
    required this.onSeek,
    required this.onClose,
    required this.onFullSettings,
    required this.onWebsite,
    required this.onExitSource,
    this.onEpisode,
    this.watchLater,
    this.siteBusy = false,
    this.onWatchLater,
    this.siteFeedback,
    this.side = false,
    this.episodePicker,
  });

  final bool? watchLater;
  final bool siteBusy;
  final VoidCallback? onWatchLater;
  final Widget? siteFeedback;
  final bool side;
  final Widget? episodePicker;
  final VideoQuickSection section;
  final VideoPlaybackPreferences preferences;
  final NativePlaybackSession session;
  final int sourceIndex;
  final double speed;
  final bool muted, ready;
  final ValueChanged<double> onSpeed;
  final ValueChanged<int> onSource;
  final void Function(String, Object) onPreference;
  final VoidCallback onMute, onClose, onFullSettings, onWebsite, onExitSource;
  final ValueChanged<int> onSeek;
  final ValueChanged<NativeVideoCard>? onEpisode;

  String get _title => switch (section) {
    VideoQuickSection.playback => t.videoPlayback.quickSettings,
    VideoQuickSection.speed => t.videoPlayback.speed,
    VideoQuickSection.sources => t.videoPlayback.source,
    VideoQuickSection.episodes => t.videoPlayback.episodes,
  };

  Widget _choices<T>(
    BuildContext context, {
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
    bool enabled = true,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in options.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: entry.key == value,
          onSelected: enabled ? (_) => onChanged(entry.key) : null,
          showCheckmark: false,
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
    ],
  );

  Widget _group(BuildContext context, String title, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _speedChoices(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final measure = TextPainter(
        text: TextSpan(
          text: '1.25×',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      // Use the actual label width: a font-scale estimate clipped × on iPad
      // accessibility sizes. Normal sizes still fit all five choices.
      final minimum = (measure.width + 20).clamp(44.0, double.infinity);
      measure.dispose();
      final columns = ((constraints.maxWidth + 4) / (minimum + 4))
          .floor()
          .clamp(1, 5);
      final width = (constraints.maxWidth - (columns - 1) * 4) / columns;
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final rate in [0.75, 1.0, 1.25, 1.5, 2.0])
            SizedBox(
              width: width,
              child: ChoiceChip(
                label: SizedBox(
                  width: width - 16,
                  child: Text(
                    '${rate == rate.roundToDouble() ? rate.toStringAsFixed(1) : rate}×',
                    textAlign: TextAlign.center,
                  ),
                ),
                labelStyle: Theme.of(context).textTheme.labelLarge,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.zero,
                side: BorderSide.none,
                selected: speed == rate,
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: ready ? (_) => onSpeed(rate) : null,
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      borderRadius: side
          ? BorderRadius.zero
          : const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: side,
        left: !side,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: t.common.close,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child:
                  section == VideoQuickSection.episodes && episodePicker != null
                  ? episodePicker!
                  : ListView(
                      key: PageStorageKey('video-quick.${section.name}'),
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: switch (section) {
                        VideoQuickSection.speed => [
                          _group(
                            context,
                            t.videoPlayback.currentPlayback,
                            _speedChoices(context),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Text(
                              t.videoPlayback.currentSpeedNote,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                        VideoQuickSection.sources => [
                          for (var i = 0; i < session.sources.length; i++)
                            ListTile(
                              title: Text(
                                videoSourceLabel(session.sources[i], i),
                              ),
                              selected: i == sourceIndex,
                              trailing: i == sourceIndex
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () => onSource(i),
                            ),
                        ],
                        VideoQuickSection.episodes => [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: Text(t.videoPlayback.siteEpisodeOrder),
                          ),
                          for (final card in session.episodes)
                            ListTile(
                              title: Text(card.title),
                              subtitle:
                                  card.episodeLabel.isEmpty ||
                                      card.episodeLabel == card.title.trim()
                                  ? null
                                  : Text(card.episodeLabel),
                              selected: card.isCurrent(session.watchUrl),
                              trailing: card.isCurrent(session.watchUrl)
                                  ? const Icon(Icons.play_arrow_rounded)
                                  : null,
                              onTap:
                                  onEpisode == null ||
                                      card.isCurrent(session.watchUrl)
                                  ? null
                                  : () => onEpisode!(card),
                            ),
                        ],
                        VideoQuickSection.playback => [
                          if (onWatchLater != null)
                            ListTile(
                              leading: Icon(
                                watchLater == true
                                    ? Icons.watch_later_rounded
                                    : Icons.watch_later_outlined,
                              ),
                              title: Text(
                                watchLater == true
                                    ? t.videoCommunity.inWatchLater
                                    : t.videoCommunity.watchLater,
                              ),
                              selected: watchLater == true,
                              onTap: siteBusy ? null : onWatchLater,
                            ),
                          if (siteFeedback != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: siteFeedback,
                            ),
                          _group(
                            context,
                            t.videoPlayback.speed,
                            _speedChoices(context),
                          ),
                          if (session.sources.length > 1)
                            _group(
                              context,
                              t.videoPlayback.source,
                              _choices<int>(
                                context,
                                value: sourceIndex,
                                options: {
                                  for (
                                    var i = 0;
                                    i < session.sources.length;
                                    i++
                                  )
                                    i: videoSourceLabel(session.sources[i], i),
                                },
                                onChanged: onSource,
                              ),
                            ),
                          const Divider(height: 24),
                          _group(
                            context,
                            t.videoPlayback.controlsStyle,
                            _choices<String>(
                              context,
                              value: preferences.controlsStyle,
                              options: {
                                'system': t.videoPlayback.systemControlsShort,
                                'breeze': t.videoPlayback.breezeControls,
                              },
                              onChanged: (v) =>
                                  onPreference('controlsStyle', v),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            title: Text(t.videoPlayback.mute),
                            value: muted,
                            onChanged: ready ? (_) => onMute() : null,
                          ),
                          SwitchListTile.adaptive(
                            title: Text(t.videoPlayback.coverVideo),
                            value: preferences.cover,
                            onChanged: (v) => onPreference('cover', v),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: ready ? () => onSeek(-10) : null,
                                  icon: const Icon(Icons.replay_10_rounded),
                                  label: Text(t.videoPlayback.rewind10),
                                ),
                                TextButton.icon(
                                  onPressed: ready ? () => onSeek(10) : null,
                                  icon: const Icon(Icons.forward_10_rounded),
                                  label: Text(t.videoPlayback.forward10),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 24),
                          _group(
                            context,
                            t.videoPlayback.gestureSettings,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(t.videoPlayback.swipeSeek),
                                  value: preferences.swipeSeek,
                                  onChanged: (v) =>
                                      onPreference('swipeSeek', v),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t.videoPlayback.holdSpeed,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                _choices<double>(
                                  context,
                                  value: preferences.holdSpeed,
                                  options: {
                                    0: t.videoPlayback.gestureOff,
                                    1.5: '1.5×',
                                    2: '2.0×',
                                    3: '3.0×',
                                  },
                                  onChanged: (v) =>
                                      onPreference('holdSpeed', v),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t.videoPlayback.doubleTapAction,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                _choices<String>(
                                  context,
                                  value: preferences.doubleTap,
                                  options: {
                                    'seek': t.videoPlayback.doubleTapSeekShort,
                                    'playPause': t.videoPlayback.doubleTapPlay,
                                    'off': t.videoPlayback.gestureOff,
                                  },
                                  onChanged: (v) =>
                                      onPreference('doubleTap', v),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 24),
                          ListTile(
                            leading: const Icon(Icons.tune_rounded),
                            title: Text(t.videoPlayback.allPlaybackSettings),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: onFullSettings,
                          ),
                          ListTile(
                            leading: const Icon(Icons.open_in_browser_rounded),
                            title: Text(t.videoPlayback.backToWeb),
                            onTap: onWebsite,
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout_rounded),
                            title: Text(t.sourceShell.exitSource),
                            onTap: onExitSource,
                          ),
                        ],
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
