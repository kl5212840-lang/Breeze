part of 'reader_settings_sheet.dart';

class _ReaderSettingsGestureTab extends StatelessWidget {
  final bool isAndroidPhone;

  const _ReaderSettingsGestureTab({required this.isAndroidPhone});

  @override
  Widget build(BuildContext context) {
    final webtoon = context.select<GlobalSettingCubit, bool>(
      (settings) => settings.state.readSetting.readMode == 0,
    );
    return _SettingsTabContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (webtoon) ...[
            const _WebtoonTapPageTurnSection(),
            const SizedBox(height: 18),
          ],
          const _TapPageTurnModeSection(),
          const SizedBox(height: 18),
          if (!webtoon) ...[
            const _WebtoonTapPageTurnSection(),
            const SizedBox(height: 18),
          ],
          const _DoubleTapSection(),
          if (isAndroidPhone) const SizedBox(height: 18),
          if (isAndroidPhone) const _VolumeKeyPageTurnSection(),
        ],
      ),
    );
  }
}

class _TapPageTurnModeSection extends StatelessWidget {
  const _TapPageTurnModeSection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();
    final mode = effective.tapPageTurnMode;
    final webtoon = effective.readMode == 0;
    final enabled = !webtoon || effective.tapPageTurnInWebtoon;
    final labels = {
      ReaderTapPageTurnMode.fullScreen: webtoon
          ? t.reader.tapPageTurnWebtoonAll
          : t.reader.fullscreen,
      ReaderTapPageTurnMode.leftHand: webtoon
          ? t.reader.topHalfNext
          : t.reader.leftHandMode,
      ReaderTapPageTurnMode.rightHand: webtoon
          ? t.reader.bottomHalfNext
          : t.reader.rightHandMode,
    };
    final hint = enabled
        ? switch ((webtoon, mode == ReaderTapPageTurnMode.fullScreen)) {
            (false, true) => t.reader.tapPageTurnAllHelp,
            (false, false) => t.reader.tapPageTurnSplitHelp,
            (true, true) => t.reader.tapPageTurnWebtoonAllHelp,
            (true, false) => t.reader.tapPageTurnWebtoonSplitHelp,
          }
        : context.isEditingPerComic
        ? t.reader.tapPageTurnWebtoonPerComicDisabled
        : t.reader.tapPageTurnWebtoonDisabled;

    return _SettingsSection(
      title: t.reader.pageMode,
      details: {
        t.reader.reverseHorizontalPageTurn:
            t.reader.reverseHorizontalPageTurnSubtitle,
      },
      children: [
        if (enabled)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in labels.entries)
                _SettingsChoiceChip(
                  title: option.value,
                  selected: mode == option.key,
                  onTap: () {
                    if (mode == option.key) return;
                    context.updateEffectiveReadSetting(
                      (current) =>
                          current.copyWith(tapPageTurnMode: option.key),
                    );
                  },
                ),
            ],
          ),
        SettingNote(hint, padding: EdgeInsets.zero),
        _SettingsSwitchTile(
          title: t.reader.reverseHorizontalPageTurn,
          value: effective.reverseHorizontalPageTurn,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(reverseHorizontalPageTurn: value),
            );
          },
        ),
      ],
    );
  }
}

class _WebtoonTapPageTurnSection extends StatelessWidget {
  const _WebtoonTapPageTurnSection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();

    return _SettingsSection(
      title: t.reader.webtoonTapPageTurn,
      details: {
        t.reader.enableWebtoonTapPageTurn: t.reader.webtoonTapPageTurnSubtitle,
      },
      children: [
        _SettingsSwitchTile(
          title: t.reader.enableWebtoonTapPageTurn,
          value: effective.tapPageTurnInWebtoon,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(tapPageTurnInWebtoon: value),
            );
          },
        ),
      ],
    );
  }
}

class _DoubleTapSection extends StatelessWidget {
  const _DoubleTapSection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();

    return _SettingsSection(
      title: t.reader.doubleTapAction,
      children: [
        _SettingsSwitchTile(
          title: t.reader.doubleTapZoom,
          value: effective.doubleTapZoom,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(
                doubleTapZoom: value,
                doubleTapOpenMenu: value ? false : current.doubleTapOpenMenu,
              ),
            );
          },
        ),
        if (effective.doubleTapZoom)
          _SettingsSwitchTile(
            title: t.reader.doubleTapZoomAnimation,
            value: effective.doubleTapZoomAnimation,
            onChanged: (value) => context.updateEffectiveReadSetting(
              (current) => current.copyWith(doubleTapZoomAnimation: value),
            ),
          ),
        _SettingsSwitchTile(
          title: t.reader.doubleTapOpenMenu,
          subtitle: t.reader.doubleTapOpenMenuSubtitle,
          value: effective.doubleTapOpenMenu,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(
                doubleTapOpenMenu: value,
                doubleTapZoom: value ? false : current.doubleTapZoom,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _VolumeKeyPageTurnSection extends StatelessWidget {
  const _VolumeKeyPageTurnSection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();

    return _SettingsSection(
      title: t.reader.volumeKeyPageTurn,
      children: [
        _SettingsSwitchTile(
          title: t.reader.enableVolumeKeyPageTurn,
          subtitle: t.reader.volumeKeyPageTurnSubtitle,
          value: effective.volumeKeyPageTurn,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(volumeKeyPageTurn: value),
            );
          },
        ),
        if (effective.volumeKeyPageTurn)
          _SettingsSliderCard(
            title: t.reader.webtoonScrollDistance,
            value: effective.volumeKeyPageTurnDistancePercent.clamp(10, 100),
            min: 10,
            max: 100,
            divisions: 90,
            suffix: t.reader.screenHeightPercent,
            onChanged: (value) {
              final percent = value.clamp(10, 100);
              context.updateEffectiveReadSetting(
                (current) =>
                    current.copyWith(volumeKeyPageTurnDistancePercent: percent),
              );
            },
          ),
      ],
    );
  }
}
