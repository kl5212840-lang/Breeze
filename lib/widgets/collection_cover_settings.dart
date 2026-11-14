import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/appearance_setting_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

const collectionCoverSettingsAction = '__cover_settings';
const collectionCoverSettingsRouteName = 'breeze.settings.cover-privacy';

String collectionCoverSettingsLabel(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh'
    ? '封面设置'
    : 'Cover settings';

/// Open the same group used by Appearance without another preference store.
/// A normal page route works in both AutoRoute pages and nested/tab hosts.
Future<void> openCollectionCoverSettings(BuildContext context) {
  final route = videoPageRoute<void>(
    settings: const RouteSettings(name: collectionCoverSettingsRouteName),
    builder: (context) => SettingPageShell(
      grouped: true,
      title: collectionCoverSettingsLabel(context),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [CollectionCoverAppearanceSettings()],
      ),
    ),
  );
  final completion = Navigator.of(context).push<void>(route);
  NativeCompositionObserver.observeSharedDestination(context, route);
  return completion;
}

/// Page hosts without a More menu use the same native/Breeze menu control.
class CollectionCoverSettingsMoreButton extends StatelessWidget {
  const CollectionCoverSettingsMoreButton({super.key});

  @override
  Widget build(BuildContext context) => VideoControlAppearance(
    systemControls: usesNativeSourceChrome(context),
    child: NativeVideoMenu(
      width: 44,
      label: '',
      tooltip: t.common.more,
      selected: '',
      icon: Icons.more_horiz,
      symbol: 'ellipsis',
      hostPresentation: true,
      selectAfterDismissal: const {collectionCoverSettingsAction},
      options: {
        collectionCoverSettingsAction: collectionCoverSettingsLabel(context),
      },
      optionIcons: const {
        collectionCoverSettingsAction: (
          icon: Icons.visibility_off_outlined,
          symbol: 'eye.slash',
        ),
      },
      onSelected: (value) {
        if (value == collectionCoverSettingsAction && context.mounted) {
          unawaited(openCollectionCoverSettings(context));
        }
      },
    ),
  );
}
