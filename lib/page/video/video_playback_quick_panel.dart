import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_selection_panel.dart';
import 'package:zephyr/page/video/video_side_panel.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

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
    this.offlineOnly = false,
    required this.onExitSource,
    this.onEpisode,
    this.watchLater,
    this.siteBusy = false,
    this.onWatchLater,
    this.siteFeedback,
    this.side = false,
    this.episodePicker,
    this.resourcePicker,
    this.floating = false,
    this.onAnalysis,
    this.showSeekActions = true,
  });

  final bool? watchLater;
  final bool siteBusy;
  final VoidCallback? onWatchLater;
  final Widget? siteFeedback;
  final bool side;
  final Widget? episodePicker;
  final Widget? resourcePicker;
  final bool floating;
  final VoidCallback? onAnalysis;
  final bool showSeekActions;
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
  final bool offlineOnly;
  final ValueChanged<int> onSeek;
  final ValueChanged<NativeVideoCard>? onEpisode;

  String get _title => switch (section) {
    VideoQuickSection.playback => t.videoPlayback.quickSettings,
    VideoQuickSection.speed => t.videoPlayback.speed,
    VideoQuickSection.sources => t.videoPlayback.source,
    VideoQuickSection.episodes =>
      session.isSitePlaylist
          ? t.videoPlayback.sitePlaylist
          : t.videoPlayback.episodes,
  };

  static final _rates = <double, String>{
    .5: '0.5×',
    .75: '0.75×',
    1: '1.0×',
    1.25: '1.25×',
    1.5: '1.5×',
    1.75: '1.75×',
    2: '2.0×',
    3: '3.0×',
  };

  List<Widget> _sideGroups(BuildContext context, List<Widget> controls) {
    if (!side || section != VideoQuickSection.playback) return controls;
    final groups = <Widget>[];
    var rows = <Widget>[];
    void finishGroup() {
      if (rows.isEmpty) return;
      groups.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: VideoPanelBlock(
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        ),
      );
      rows = <Widget>[];
    }

    for (final control in controls) {
      if (control is Divider) {
        finishGroup();
      } else {
        rows.add(control);
      }
    }
    finishGroup();
    return groups;
  }

  Widget _playlistRow(NativeVideoCard card, int index) {
    final current = card.isCurrent(session.watchUrl);
    return ListTile(
      key: ValueKey('video-playlist.entry.$index'),
      minTileHeight: 48,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 56,
          height: 36,
          child: VideoThumbnail(
            url: card.coverUrl?.toString() ?? '',
            referrer: card.watchUrl,
            cacheWidth: 168,
            retryOnTap: false,
          ),
        ),
      ),
      title: Text(
        card.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: current ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: current,
      trailing: current ? const Icon(Icons.play_arrow_rounded) : null,
      onTap: current || onEpisode == null ? null : () => onEpisode!(card),
    );
  }

  @override
  Widget build(BuildContext context) => VideoSelectionPanel(
    title: _title,
    onClose: onClose,
    floating: floating,
    side: side,
    grouped:
        section == VideoQuickSection.playback ||
        section == VideoQuickSection.speed ||
        (section == VideoQuickSection.episodes && episodePicker != null),
    child: Builder(
      builder: (context) =>
          section == VideoQuickSection.episodes && episodePicker != null
          ? episodePicker!
          : section == VideoQuickSection.episodes && session.isSitePlaylist
          ? ListView.builder(
              key: const PageStorageKey('video-quick.site-playlist'),
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: session.playbackEntries.length,
              itemBuilder: (_, index) =>
                  _playlistRow(session.playbackEntries[index], index),
            )
          : ListView(
              key: PageStorageKey('video-quick.${section.name}'),
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: _sideGroups(context, switch (section) {
                VideoQuickSection.speed => [
                  for (final rate in _rates.entries)
                    ListTile(
                      minTileHeight: 44,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      title: Text(
                        rate.value,
                        style: TextStyle(
                          color: rate.key == speed
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: rate.key == speed
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      selected: rate.key == speed,
                      trailing: !side && rate.key == speed
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: !ready
                          ? null
                          : () {
                              if (rate.key != speed) onSpeed(rate.key);
                              onClose();
                            },
                    ),
                ],
                VideoQuickSection.sources => [
                  ?resourcePicker,
                  if (resourcePicker == null)
                    for (var i = 0; i < session.sources.length; i++)
                      ListTile(
                        title: Text(
                          videoSourceLabel(session.sources[i], i),
                          style: TextStyle(
                            fontWeight: i == sourceIndex
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        selected: i == sourceIndex,
                        trailing: i == sourceIndex
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () {
                          if (i != sourceIndex) onSource(i);
                          onClose();
                        },
                      ),
                ],
                VideoQuickSection.episodes => [
                  for (final card in session.playbackEntries)
                    ListTile(
                      title: Text(
                        card.title,
                        style: TextStyle(
                          fontWeight: card.isCurrent(session.watchUrl)
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      selected: card.isCurrent(session.watchUrl),
                      trailing: card.isCurrent(session.watchUrl)
                          ? const Icon(Icons.play_arrow_rounded)
                          : null,
                      onTap:
                          onEpisode == null || card.isCurrent(session.watchUrl)
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: siteFeedback,
                    ),
                  if (onWatchLater != null || siteFeedback != null)
                    const Divider(height: 16, indent: 16, endIndent: 16),
                  BreezeSwitchListTile(
                    SwitchListTile.adaptive(
                      title: Text(t.videoPlayback.mute),
                      value: muted,
                      onChanged: ready ? (_) => onMute() : null,
                    ),
                  ),
                  BreezeSwitchListTile(
                    SwitchListTile.adaptive(
                      title: Text(t.videoPlayback.coverVideo),
                      value: preferences.cover,
                      onChanged: (value) => onPreference('cover', value),
                    ),
                  ),
                  if (showSeekActions)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            key: const ValueKey('video-quick.rewind'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: ready ? () => onSeek(-10) : null,
                            icon: const Icon(Icons.replay_10_rounded),
                            label: Text(t.videoPlayback.rewind10),
                          ),
                          TextButton.icon(
                            key: const ValueKey('video-quick.forward'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: ready ? () => onSeek(10) : null,
                            icon: const Icon(Icons.forward_10_rounded),
                            label: Text(t.videoPlayback.forward10),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  SettingChoiceTile<String>(
                    key: const ValueKey('video-quick.controls-style'),
                    title: t.videoPlayback.controlsStyle,
                    value: preferences.controlsStyle,
                    items: {
                      'system': t.videoPlayback.systemControlsShort,
                      'breeze': t.videoPlayback.breezeControls,
                    },
                    onChanged: (value) => onPreference('controlsStyle', value),
                  ),
                  BreezeSwitchListTile(
                    SwitchListTile.adaptive(
                      key: const ValueKey('video-quick.swipe-seek'),
                      title: Text(t.videoPlayback.swipeSeek),
                      value: preferences.swipeSeek,
                      onChanged: (value) => onPreference('swipeSeek', value),
                    ),
                  ),
                  SettingChoiceTile<double>(
                    key: const ValueKey('video-quick.hold-speed'),
                    title: t.videoPlayback.holdSpeed,
                    value: preferences.holdSpeed,
                    items: {
                      0: t.videoPlayback.gestureOff,
                      1.5: '1.5×',
                      2: '2.0×',
                      3: '3.0×',
                    },
                    onChanged: (value) => onPreference('holdSpeed', value),
                  ),
                  SettingChoiceTile<String>(
                    key: const ValueKey('video-quick.double-tap'),
                    title: t.videoPlayback.doubleTapAction,
                    value: preferences.doubleTap,
                    items: {
                      'seek': t.videoPlayback.doubleTapSeekShort,
                      'playPause': t.videoPlayback.doubleTapPlay,
                      'off': t.videoPlayback.gestureOff,
                    },
                    onChanged: (value) => onPreference('doubleTap', value),
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: Text(t.videoPlayback.allPlaybackSettings),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onFullSettings,
                  ),
                  if (onAnalysis != null || !offlineOnly)
                    const Divider(height: 16, indent: 16, endIndent: 16),
                  if (onAnalysis != null)
                    ListTile(
                      key: const ValueKey('video-quick.analysis'),
                      leading: const Icon(Icons.analytics_outlined),
                      title: Text(t.videoPlayback.playbackAnalysis),
                      onTap: onAnalysis,
                    ),
                  if (!offlineOnly)
                    ListTile(
                      leading: const Icon(Icons.open_in_browser_rounded),
                      title: Text(t.videoPlayback.backToWeb),
                      onTap: onWebsite,
                    ),
                  if (!offlineOnly)
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: Text(t.sourceShell.exitSource),
                      onTap: onExitSource,
                    ),
                ],
              }),
            ),
    ),
  );
}
