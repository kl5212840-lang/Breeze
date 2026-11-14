import 'package:zephyr/page/setting/global/app_icon_setting.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'dart:io';

import 'package:zephyr/page/video/native_video_controls.dart';

import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/setting/global/interface_style_setting.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/i18n_helper.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/i18n/system_locale_service.dart';
import 'package:zephyr/page/font_setting/view/font_setting_page.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/setting/global/switch_style_setting_page.dart';
import 'package:zephyr/page/theme_color/view/theme_color_page.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/widgets/system_accent_availability.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

@RoutePage()
class AppearanceSettingPage extends StatelessWidget {
  const AppearanceSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;
    final systemAccentAvailable = SystemAccentAvailability.of(context);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';

    return SettingPageShell(
      grouped: true,
      title: t.settings.appearance,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SettingSection(
            title: android ? (chinese ? '界面' : 'Interface') : '',
            children: [
              _languageTile(state, cubit),
              _systemTheme(state, cubit),
              const InterfaceStyleSetting(),
              const AppIconSetting(),
              _switchStyle(context, state.switchStyle),
              if (!android) _fontSettings(context),
            ],
          ),
          SettingSection(
            title: android
                ? t.settings.themeColor
                : t.settings.appearanceOptions,
            footer: t.settings.amoledSubtitle,
            children: [
              if (systemAccentAvailable) _dynamicColor(state, cubit),
              if (!systemAccentAvailable || !state.dynamicColor)
                _themeColor(context, state.seedColor),
              _isAMOLED(state, cubit),
            ],
          ),
          CollectionCoverAppearanceSettings(
            fontSettings: android ? _fontSettings(context) : null,
          ),
        ],
      ),
    );
  }

  Widget _languageTile(GlobalSettingState state, GlobalSettingCubit cubit) {
    final labels = {
      null: t.settings.followSystemLanguage,
      for (final appLocale in AppLocale.values)
        I18nHelper.toFlutterLocale(appLocale): I18nHelper.displayName(
          appLocale,
        ),
    };

    final currentValue = state.localeFollowsSystem
        ? null
        : I18nHelper.toFlutterLocale(
            I18nHelper.toAppLocale(state.locale) ?? AppLocale.enUs,
          );

    return SettingChoiceTile<Locale?>(
      leading: const InterfaceSymbol(
        symbol: 'globe',
        fallback: Icons.language_outlined,
      ),
      title: t.settings.language,
      value: currentValue,
      items: labels,
      onChanged: (value) async {
        if (value == currentValue) return;
        if (value == null) {
          await cubit.setSystemLocale(SystemLocaleService.preferredLocale);
        } else {
          await cubit.setLocale(value, followsSystem: false);
        }
      },
    );
  }

  Widget _systemTheme(GlobalSettingState state, GlobalSettingCubit cubit) {
    final themeItems = <ThemeMode, String>{
      ThemeMode.system: t.common.followSystem,
      ThemeMode.light: t.common.lightMode,
      ThemeMode.dark: t.common.darkMode,
    };

    return SettingChoiceTile<ThemeMode>(
      leading: const InterfaceSymbol(
        symbol: 'moon',
        fallback: Icons.dark_mode_outlined,
      ),
      title: t.settings.theme,
      value: state.themeMode,
      items: themeItems,
      onChanged: (ThemeMode value) {
        cubit.updateState((current) => current.copyWith(themeMode: value));
      },
    );
  }

  Widget _dynamicColor(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'appearance_setting_page.switch:0',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'paintpalette',
            fallback: Icons.color_lens_outlined,
          ),
          title: Text(t.settings.dynamicColor),
          subtitle: Text(t.settings.dynamicColorSubtitle),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.dynamicColor,
          onChanged: (bool value) {
            cubit.updateState(
              (current) => current.copyWith(dynamicColor: value),
            );
          },
        ),
      ),
    );
  }

  Widget _switchStyle(BuildContext context, BreezeSwitchStyle style) {
    return TouchHoverIntent(
      identity: 'settings.switch-style',
      builder: (context, hover) => ListTile(
        key: const ValueKey('settings.switch-style'),
        hoverColor: hover.hoverColor(),
        leading: const InterfaceSymbol(
          symbol: 'switch.2',
          fallback: Icons.toggle_on_outlined,
        ),
        title: Text(t.settings.switchStyles.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(switchStyleLabel(style), textAlign: TextAlign.end),
            ),
            const SizedBox(width: 8),
            const InterfaceSymbol(
              symbol: 'chevron.right',
              fallback: Icons.chevron_right,
            ),
          ],
        ),
        onTap: () => openSettingPage(
          context,
          route: const SwitchStyleSettingRoute(),
          builder: (_) => const SwitchStyleSettingPage(),
        ),
      ),
    );
  }

  Widget _fontSettings(BuildContext context) {
    return TouchHoverIntent(
      identity: 'appearance_setting_page:0',
      builder: (context, hover) => ListTile(
        hoverColor: hover.hoverColor(),
        leading: const InterfaceSymbol(
          symbol: 'textformat',
          fallback: Icons.font_download_outlined,
        ),
        title: Text(t.settings.fontSettings),
        trailing: const InterfaceSymbol(
          symbol: 'chevron.right',
          fallback: Icons.chevron_right,
        ),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const FontSettingPage()));
        },
      ),
    );
  }

  Widget _themeColor(
    BuildContext context,
    Color selectedColor,
  ) => TouchHoverIntent(
    identity: 'widgets:0',
    builder: (context, hover) => ListTile(
      hoverColor: hover.hoverColor(),
      leading: const InterfaceSymbol(
        symbol: 'paintpalette',
        fallback: Icons.palette_outlined,
      ),
      title: Text(t.settings.themeColor),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            value:
                '#${(selectedColor.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}',
            child: SizedBox.square(
              dimension: 22,
              child: DecoratedBox(
                key: const ValueKey('appearance.theme-color-preview'),
                decoration: BoxDecoration(
                  color: selectedColor,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const InterfaceSymbol(
            symbol: 'chevron.right',
            fallback: Icons.chevron_right,
          ),
        ],
      ),
      onTap: () => openSettingPage(
        context,
        route: const ThemeColorRoute(),
        builder: (_) => const ThemeColorPage(),
      ),
    ),
  );

  Widget _isAMOLED(GlobalSettingState state, GlobalSettingCubit cubit) {
    return TouchHoverIntent(
      identity: 'appearance_setting_page.switch:1',
      builder: (context, hover) => BreezeSwitchListTile(
        SwitchListTile.adaptive(
          hoverColor: hover.hoverColor(),
          secondary: const InterfaceSymbol(
            symbol: 'circle.lefthalf.filled',
            fallback: Icons.contrast_outlined,
          ),
          title: Text(t.settings.amoled),
          thumbIcon: settingSwitchThumbIcon(context),
          value: state.isAMOLED,
          onChanged: (bool value) {
            cubit.updateState((current) => current.copyWith(isAMOLED: value));
          },
        ),
      ),
    );
  }
}

/// Hosted by the appearance page; keeps long-running picker operations local.
class CollectionCoverAppearanceSettings extends StatefulWidget {
  const CollectionCoverAppearanceSettings({
    super.key,
    this.imageStore,
    this.privacyController,
    this.fontSettings,
  });
  final LocalAppearanceImages? imageStore;
  final CollectionCoverPrivacyController? privacyController;
  final Widget? fontSettings;
  @override
  State<CollectionCoverAppearanceSettings> createState() =>
      _CollectionCoverAppearanceSettingsState();
}

class _CollectionCoverAppearanceSettingsState
    extends State<CollectionCoverAppearanceSettings> {
  late final _controller =
      widget.privacyController ?? CollectionCoverPrivacyController.instance;
  late final _images = widget.imageStore ?? LocalAppearanceImages.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _controller.ensureLoaded();
      await _images.load();
    } catch (_) {
      if (mounted) showErrorToast(t.coverPrivacy.imageSaveFailed);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) showErrorToast(t.coverPrivacy.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseImage({String? key, String? expectedPath}) async {
    if (key != null) {
      var decided = false;
      void finish(BuildContext dialog, bool value) {
        if (decided ||
            !dialog.mounted ||
            ModalRoute.of(dialog)?.isCurrent != true)
          return;
        decided = true;
        Navigator.pop(dialog, value);
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(t.coverPrivacy.replaceImageConfirmTitle),
          content: Text(t.coverPrivacy.replaceImageConfirm),
          actions: [
            TextButton(
              onPressed: () => finish(dialog, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => finish(dialog, true),
              child: Text(t.common.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          _images.collectionCovers[key] != expectedPath)
        return;
    }
    final path = await pickLocalAppearanceImage(
      context,
      imageKey: key ?? LocalAppearanceImages.collectionCoverKey,
      title: key == null
          ? t.coverPrivacy.addImage
          : t.coverPrivacy.replaceImage,
      canCommit: () =>
          mounted &&
          (key == null || _images.collectionCovers[key] == expectedPath),
      save: (_, bytes) => _images.saveCollectionCover(
        bytes,
        key: key,
        expectedPath: expectedPath,
        canCommit: () => mounted,
      ),
    );
    if (path == null || !mounted) return;
    await _controller.setStyle(CollectionCoverStyle.custom);
  }

  Future<void> _removeImage(String key, String expectedPath) => _run(() async {
    final confirmed = await confirmLocalAppearanceImageRemoval(
      context,
      title: t.coverPrivacy.removeImageConfirmTitle,
      description: t.coverPrivacy.removeImageConfirm,
    );
    if (!confirmed || !mounted || _images.collectionCovers[key] != expectedPath)
      return;
    final removed = await _images.removeCollectionCover(key, expectedPath);
    if (removed &&
        _images.collectionCovers.isEmpty &&
        _controller.state.value.style == CollectionCoverStyle.custom) {
      await _controller.setStyle(CollectionCoverStyle.blur);
    }
  });

  Future<void> _previewImage(String path, String label) async {
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: MediaQuery.sizeOf(dialog).width,
          height: MediaQuery.sizeOf(dialog).height * 0.5,
          child: Image.file(
            File(path),
            key: ValueKey('cover-privacy.preview-image:$path'),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Center(child: Text(t.coverPrivacy.previewUnavailable)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(t.common.close),
          ),
        ],
      ),
    );
  }

  Widget _galleryPreview(
    Map<String, String> covers,
    String? selectedPath,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.coverPrivacy.galleryHint,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: covers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = covers.entries.elementAt(index);
              final selected = entry.value == selectedPath;
              final label = t.coverPrivacy.imageLabel(number: index + 1);
              final colors = Theme.of(context).colorScheme;
              return SizedBox(
                width: 88,
                child: Column(
                  children: [
                    Semantics(
                      selected: selected,
                      button: true,
                      label: label,
                      child: TouchHoverIntent(
                        identity: 'cover-privacy.gallery:${entry.key}',
                        builder: (context, hover) => Material(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('cover-privacy.gallery:${entry.key}'),
                            hoverColor: hover.hoverColor(),
                            onTap: _busy
                                ? null
                                : () => _run(() async {
                                    if (await _images.selectCollectionCover(
                                          entry.key,
                                          entry.value,
                                        ) &&
                                        mounted) {
                                      await _controller.setStyle(
                                        CollectionCoverStyle.custom,
                                      );
                                    }
                                  }),
                            child: SizedBox(
                              width: 88,
                              height: 100,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(entry.value),
                                    // A gallery preview shows the whole original;
                                    // one decode dimension preserves its aspect.
                                    fit: BoxFit.contain,
                                    cacheWidth: 176,
                                    excludeFromSemantics: true,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                  if (selected)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              width: 3,
                                              color: colors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (selected)
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: DecoratedBox(
                                        key: ValueKey(
                                          'cover-privacy.selected:${entry.key}',
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.check,
                                            size: 18,
                                            color: colors.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // A sibling target: menu taps never select the thumbnail.
                    Semantics(
                      enabled: !_busy,
                      child: IgnorePointer(
                        ignoring: _busy,
                        child: NativeVideoMenu(
                          key: ValueKey('cover-privacy.menu:${entry.key}'),
                          label: '',
                          tooltip: '$label · ${t.common.more}',
                          selected: '',
                          symbol: 'ellipsis',
                          icon: Icons.more_horiz,
                          bare: true,
                          width: 44,
                          hostPresentation: true,
                          options: {
                            'preview': t.comicInfo.preview,
                            'replace': t.coverPrivacy.replaceImage,
                            'remove': t.common.delete,
                          },
                          optionIcons: const {
                            'preview': (
                              icon: Icons.visibility_outlined,
                              symbol: 'eye',
                            ),
                            'replace': (
                              icon: Icons.edit_outlined,
                              symbol: 'arrow.triangle.2.circlepath',
                            ),
                            'remove': (
                              icon: Icons.delete_outline,
                              symbol: 'trash',
                            ),
                          },
                          groups: const [
                            ['preview', 'replace'],
                            ['remove'],
                          ],
                          onSelected: (action) {
                            if (_busy ||
                                _images.collectionCovers[entry.key] !=
                                    entry.value)
                              return;
                            switch (action) {
                              case 'preview':
                                _previewImage(entry.value, label);
                              case 'replace':
                                _run(
                                  () => _chooseImage(
                                    key: entry.key,
                                    expectedPath: entry.value,
                                  ),
                                );
                              case 'remove':
                                _removeImage(entry.key, entry.value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<CollectionCoverPrivacySettings>(
    valueListenable: _controller.state,
    builder: (context, settings, _) => ValueListenableBuilder<Map<String, String>>(
      valueListenable: _images.paths,
      builder: (context, paths, _) {
        final covers = _images.collectionCovers;
        final currentPath = paths[LocalAppearanceImages.collectionCoverKey];
        final hasImage = currentPath != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingSection(
              title: widget.fontSettings != null
                  ? t.settings.appearanceOptions
                  : Localizations.localeOf(context).languageCode == 'zh'
                  ? '封面显示'
                  : 'Cover display',
              footer: Localizations.localeOf(context).languageCode == 'zh'
                  ? '原封面完整显示用柔化背景补齐；自定义保护图始终填满。'
                  : 'Entire original covers use a softened image background; custom privacy artwork always fills the frame.',
              children: [
                ?widget.fontSettings,
                const CollectionCoverFitSetting(),
              ],
            ),
            SettingSection(
              title: t.coverPrivacy.title,
              footer: !hasImage && settings.style == CollectionCoverStyle.custom
                  ? '${t.coverPrivacy.localOnly}\n${t.coverPrivacy.customEmpty}'
                  : t.coverPrivacy.localOnly,
              children: [
                TouchHoverIntent(
                  identity: 'appearance_setting_page.switch:3',
                  builder: (context, hover) => BreezeSwitchListTile(
                    SwitchListTile.adaptive(
                      hoverColor: hover.hoverColor(),
                      secondary: const InterfaceSymbol(
                        symbol: 'eye.slash',
                        fallback: Icons.visibility_off_outlined,
                      ),
                      title: Text(t.coverPrivacy.enable),
                      thumbIcon: settingSwitchThumbIcon(context),
                      value: settings.enabled,
                      onChanged: _busy || !settings.ready
                          ? null
                          : (value) =>
                                _run(() => _controller.setEnabled(value)),
                    ),
                  ),
                ),
                SettingChoiceTile<CollectionCoverStyle>(
                  leading: const InterfaceSymbol(
                    symbol: 'square.stack',
                    fallback: Icons.texture_outlined,
                  ),
                  title: t.coverPrivacy.style,
                  value: settings.style,
                  enabled: !_busy && settings.ready,
                  items: {
                    CollectionCoverStyle.blur: t.coverPrivacy.blur,
                    CollectionCoverStyle.mosaic: t.coverPrivacy.mosaic,
                    CollectionCoverStyle.glass: t.coverPrivacy.glass,
                    CollectionCoverStyle.custom: t.coverPrivacy.custom,
                  },
                  onChanged: (style) => _run(() async {
                    if (style == CollectionCoverStyle.custom && !hasImage) {
                      await _chooseImage();
                    } else {
                      await _controller.setStyle(style);
                    }
                  }),
                ),
                TouchHoverIntent(
                  identity: 'appearance_setting_page:1',
                  builder: (context, hover) => ListTile(
                    hoverColor: hover.hoverColor(),
                    leading: const InterfaceSymbol(
                      symbol: 'photo.badge.plus',
                      fallback: Icons.add_photo_alternate_outlined,
                    ),
                    title: Text(t.coverPrivacy.addImage),
                    trailing: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const InterfaceSymbol(
                            symbol: 'chevron.right',
                            fallback: Icons.chevron_right,
                          ),
                    enabled:
                        !_busy &&
                        covers.length <
                            LocalAppearanceImages.maximumCollectionCovers,
                    subtitle:
                        covers.length >=
                            LocalAppearanceImages.maximumCollectionCovers
                        ? Text(t.coverPrivacy.galleryFull)
                        : null,
                    onTap: () => _run(() => _chooseImage()),
                  ),
                ),
                if (covers.isNotEmpty) _galleryPreview(covers, currentPath),
              ],
            ),
          ],
        );
      },
    ),
  );
}
