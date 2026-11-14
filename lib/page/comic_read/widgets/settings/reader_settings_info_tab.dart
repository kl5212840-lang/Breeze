part of 'reader_settings_sheet.dart';

class _ReaderSettingsInfoTab extends StatelessWidget {
  const _ReaderSettingsInfoTab();

  @override
  Widget build(BuildContext context) {
    return const _SettingsTabContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageInfoVisibilitySection(),
          SizedBox(height: 18),
          _PageInfoPlacementSection(),
          SizedBox(height: 18),
          _PageInfoAppearanceSection(),
        ],
      ),
    );
  }
}

class _PageInfoVisibilitySection extends StatelessWidget {
  const _PageInfoVisibilitySection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();
    final allHidden =
        !effective.pageInfoShowPage &&
        !effective.pageInfoShowNetwork &&
        !effective.pageInfoShowBattery &&
        !effective.pageInfoShowTime;

    return _SettingsSection(
      title: t.reader.infoDisplay,
      children: [
        _SettingsSwitchTile(
          title: t.reader.pageNumber,
          value: effective.pageInfoShowPage,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoShowPage: value),
            );
          },
        ),
        _SettingsSwitchTile(
          title: t.reader.networkStatus,
          subtitle: !kIsWeb && Platform.isLinux
              ? t.reader.networkStatusSubtitle
              : '',
          value: effective.pageInfoShowNetwork,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoShowNetwork: value),
            );
          },
        ),
        _SettingsSwitchTile(
          title: t.reader.battery,
          value: effective.pageInfoShowBattery,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoShowBattery: value),
            );
          },
        ),
        _SettingsSwitchTile(
          title: t.reader.time,
          value: effective.pageInfoShowTime,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoShowTime: value),
            );
          },
        ),
        if (allHidden) _SettingsNoticeCard(text: t.reader.allHiddenNotice),
      ],
    );
  }
}

class _PageInfoPlacementSection extends StatelessWidget {
  const _PageInfoPlacementSection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();
    final isHorizontalCenter =
        effective.pageInfoHorizontalPosition ==
        ReaderInfoHorizontalPosition.center;

    return _SettingsSection(
      title: t.reader.infoBarPosition,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageInfoPositionChoices(
              options: {
                ReaderInfoVerticalPosition.top: t.reader.verticalPositionTop,
                ReaderInfoVerticalPosition.bottom:
                    t.reader.verticalPositionBottom,
              },
              value: effective.pageInfoVerticalPosition,
              onChanged: (value) => context.updateEffectiveReadSetting(
                (current) => current.copyWith(pageInfoVerticalPosition: value),
              ),
            ),
            const SizedBox(height: 6),
            _PageInfoPositionChoices(
              options: {
                ReaderInfoHorizontalPosition.left:
                    t.reader.horizontalPositionLeft,
                ReaderInfoHorizontalPosition.center:
                    t.reader.horizontalPositionCenter,
                ReaderInfoHorizontalPosition.right:
                    t.reader.horizontalPositionRight,
              },
              value: effective.pageInfoHorizontalPosition,
              onChanged: (value) => context.updateEffectiveReadSetting(
                (current) =>
                    current.copyWith(pageInfoHorizontalPosition: value),
              ),
            ),
          ],
        ),
        if (effective.pageInfoVerticalPosition ==
            ReaderInfoVerticalPosition.top)
          _SettingsSwitchTile(
            title: t.reader.showInStatusBar,
            value: effective.pageInfoTopInStatusBar,
            onChanged: (value) => context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoTopInStatusBar: value),
            ),
          ),
        _SettingsSliderCard(
          title: t.reader.edgePadding,
          value: effective.pageInfoEdgePadding.clamp(0, 48),
          min: 0,
          max: 48,
          divisions: 48,
          suffix: t.reader.pixels,
          enabled: !isHorizontalCenter,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoEdgePadding: value),
            );
          },
        ),
        if (isHorizontalCenter)
          _SettingsNoticeCard(text: t.reader.edgePaddingDisabled),
      ],
    );
  }
}

class _PageInfoPositionChoices<T> extends StatelessWidget {
  const _PageInfoPositionChoices({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 6,
    children: [
      for (final option in options.entries)
        _SettingsChoiceChip(
          title: option.value,
          selected: option.key == value,
          onTap: () => onChanged(option.key),
        ),
    ],
  );
}

class _PageInfoAppearanceSection extends StatelessWidget {
  const _PageInfoAppearanceSection();

  @override
  Widget build(BuildContext context) {
    final effective = context.watchTargetReadSetting();

    return _SettingsSection(
      title: t.reader.infoBarStyle,
      children: [
        _SettingsSliderCard(
          title: t.reader.fontSize,
          value: effective.pageInfoFontSize.clamp(10, 20),
          min: 10,
          max: 20,
          divisions: 10,
          suffix: t.reader.pixels,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoFontSize: value),
            );
          },
        ),
        _SettingsSliderCard(
          title: t.reader.backgroundOpacity,
          value: effective.pageInfoOpacityPercent.clamp(20, 100),
          min: 20,
          max: 100,
          divisions: 80,
          suffix: t.reader.percent,
          onChanged: (value) {
            context.updateEffectiveReadSetting(
              (current) => current.copyWith(pageInfoOpacityPercent: value),
            );
          },
        ),
      ],
    );
  }
}
