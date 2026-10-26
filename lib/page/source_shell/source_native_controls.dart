import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_website.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';

/// Source chrome follows the platform, independently of playback preferences.
/// E-ink keeps the existing flat controls and navigation.
bool usesNativeSourceChrome(BuildContext context) {
  final eInk = context.select<GlobalSettingCubit?, bool>(
    (cubit) => cubit?.state.eInkSetting.enabled ?? false,
  );
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && !eInk;
}

/// Explicit exit disposes every source route on the way back to Discover.
void exitSourceToDiscover(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(context, rootNavigator: true).popUntil(
    (route) => route.isFirst || route.settings.name == 'NavigationBar',
  );
}

class SourceChromeIconButton extends StatelessWidget {
  const SourceChromeIconButton({
    super.key,
    required this.icon,
    required this.symbol,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String symbol, tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: usesNativeSourceChrome(context)
        ? VideoControlAppearance(
            systemControls: true,
            child: NativeVideoIconButton(
              light: false,
              tooltip: tooltip,
              icon: icon,
              symbol: symbol,
              onPressed: onPressed,
            ),
          )
        : SizedBox.square(
            dimension: 44,
            child: IconButton(
              tooltip: tooltip,
              icon: Icon(icon, size: 22),
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              onPressed: onPressed,
            ),
          ),
  );
}

class SourceMenuAction {
  const SourceMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.symbol,
    required this.onSelected,
  });

  final String id, label, symbol;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Every source menu offers the same explicit exit after its page actions.
class SourceMoreButton extends StatelessWidget {
  const SourceMoreButton({
    super.key,
    this.source = '',
    this.actions = const [],
  });

  final String source;
  final List<SourceMenuAction> actions;
  static const _websiteId = '__source_website';
  static const _exitId = '__source_exit';

  @override
  Widget build(BuildContext context) {
    final website = sourceOfficialWebsite(source);
    final menuActions = [
      ...actions,
      if (website != null)
        SourceMenuAction(
          id: _websiteId,
          label: t.sourceShell.openOfficialWebsite,
          icon: Icons.open_in_browser_outlined,
          symbol: 'safari',
          onSelected: () =>
              unawaited(openSourceOfficialWebsite(context, website)),
        ),
      SourceMenuAction(
        id: _exitId,
        label: t.sourceShell.exitPlugin,
        icon: Icons.exit_to_app,
        symbol: 'rectangle.portrait.and.arrow.right',
        onSelected: () => exitSourceToDiscover(context),
      ),
    ];
    void select(String id) {
      for (final action in menuActions) {
        if (action.id == id) {
          action.onSelected();
          return;
        }
      }
    }

    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: usesNativeSourceChrome(context)
          ? VideoControlAppearance(
              systemControls: true,
              child: NativeVideoMenu(
                width: 44,
                label: '',
                tooltip: t.sourceShell.navigationActions,
                icon: Icons.more_horiz,
                symbol: 'ellipsis',
                selected: '',
                hostPresentation: true,
                options: {
                  for (final action in menuActions) action.id: action.label,
                },
                optionIcons: {
                  for (final action in menuActions)
                    action.id: (icon: action.icon, symbol: action.symbol),
                },
                onSelected: select,
              ),
            )
          : FluentPopupMenuButton<String>(
              tooltip: t.sourceShell.navigationActions,
              itemBuilder: (_) => [
                for (final action in menuActions)
                  FluentPopupMenuItem(
                    value: action.id,
                    leading: Icon(action.icon, size: 22),
                    title: Text(action.label),
                  ),
              ],
              onSelected: select,
              child: Tooltip(
                message: t.sourceShell.navigationActions,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(child: Icon(Icons.more_horiz, size: 22)),
                ),
              ),
            ),
    );
  }
}
