part of 'reader_settings_sheet.dart';

class _ReaderSettingsGestureTab extends StatelessWidget {
  final bool isAndroidPhone;

  const _ReaderSettingsGestureTab({required this.isAndroidPhone});

  @override
  Widget build(BuildContext context) {
    final settings = context.watchTargetReadSetting();
    final webtoon = settings.readMode == 0;
    final customArea = settings.customToolbarTapArea;
    return _SettingsTabContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ToolbarTapAreaSection(),
          const SizedBox(height: 18),
          if (customArea && webtoon) ...[
            const _WebtoonTapPageTurnSection(),
            const SizedBox(height: 18),
          ],
          const _TapPageTurnModeSection(),
          const SizedBox(height: 18),
          if (customArea && !webtoon) ...[
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

class _ToolbarTapAreaSection extends StatelessWidget {
  const _ToolbarTapAreaSection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();
    return _SettingsSection(
      title: t.reader.toolbarTapArea,
      children: [
        _SettingsSwitchTile(
          title: t.reader.customToolbarTapArea,
          subtitle: effective.customToolbarTapArea
              ? ''
              : t.reader.toolbarTapAreaHelp,
          value: effective.customToolbarTapArea,
          onChanged: (value) => context.updateEffectiveReadSetting(
            (current) => current.copyWith(customToolbarTapArea: value),
          ),
        ),
        if (effective.customToolbarTapArea)
          _SettingsSliderCard(
            sliderKey: const ValueKey('reader.toolbar-tap-area.width'),
            title: t.reader.toolbarTapAreaWidth,
            value: normalizeToolbarTapAreaPercent(
              effective.toolbarTapAreaPercent,
            ),
            min: minToolbarTapAreaPercent,
            max: maxToolbarTapAreaPercent,
            suffix: t.reader.percent,
            onChanged: (value) => context.updateEffectiveReadSetting(
              (current) => current.copyWith(toolbarTapAreaPercent: value),
            ),
            preview: (context, percent) {
              final colors = context.theme.colorScheme;
              final highContrast = MediaQuery.highContrastOf(context);
              return ExcludeSemantics(
                child: Center(
                  child: Container(
                    width: 76,
                    height: 106,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(
                        color: highContrast ? colors.onSurface : colors.outline,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FractionallySizedBox(
                      key: const ValueKey('reader.toolbar-tap-area.preview'),
                      widthFactor: percent / 100,
                      heightFactor: 1,
                      child: ColoredBox(
                        color: highContrast
                            ? colors.primary
                            : colors.primaryContainer,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
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
    final customArea = effective.customToolbarTapArea;
    final enabled = customArea && (!webtoon || effective.tapPageTurnInWebtoon);
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
    final hint = !customArea
        ? t.reader.tapPageTurnNeedsCustomArea
        : enabled
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
