import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/setting/cache/cache_setting_page.dart';
import 'package:zephyr/page/setting/data_backup/data_backup_page.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class StorageSettingPage extends StatefulWidget {
  const StorageSettingPage({super.key});

  @override
  State<StorageSettingPage> createState() => _StorageSettingPageState();
}

class _StorageSettingPageState extends State<StorageSettingPage> {
  int? _cacheSizeBytes;
  bool _cacheCalculating = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    if (_cacheCalculating) return;
    setState(() => _cacheCalculating = true);

    try {
      final cachePath = await getCachePath();
      final totalSize = await imageCacheSize(cachePath);

      if (!mounted) return;
      setState(() {
        _cacheSizeBytes = totalSize;
        _cacheCalculating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cacheSizeBytes = null;
        _cacheCalculating = false;
      });
    }
  }

  String _formatCacheSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes == 0) return '0 B';

    const gb = 1 << 30;
    const mb = 1 << 20;
    const kb = 1 << 10;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  Widget _customExportPath(GlobalSettingState state, GlobalSettingCubit cubit) {
    final exportPath = state.customExportPath.trim();
    return TouchHoverIntent(
      identity: 'storage_setting_page:0',
      builder: (context, hover) => ListTile(
        hoverColor: hover.hoverColor(),
        leading: const InterfaceSymbol(
          symbol: 'folder',
          fallback: Icons.folder_outlined,
        ),
        title: Text(t.settings.customExportPath),
        subtitle: Text(
          exportPath.isEmpty ? t.settings.notSet : exportPath,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exportPath.isNotEmpty)
              TouchHoverIntent(
                identity: 'storage_setting_page.button:0',
                builder: (context, hover) {
                  const style = ButtonStyle();
                  return IconButton(
                    style: style.copyWith(
                      overlayColor: hover.overlayColor(style.overlayColor),
                    ),
                    icon: const Icon(Icons.clear, size: 20),
                    tooltip: t.common.clear,
                    onPressed: () {
                      cubit.updateState(
                        (current) => current.copyWith(customExportPath: ''),
                      );
                      showSuccessToast(t.common.settingSaved);
                    },
                  );
                },
              ),
            const InterfaceSymbol(
              symbol: 'chevron.right',
              fallback: Icons.chevron_right,
            ),
          ],
        ),
        onTap: () async {
          final selected = await getDirectoryPath();
          if (selected != null && selected.trim().isNotEmpty) {
            cubit.updateState(
              (current) => current.copyWith(customExportPath: selected),
            );
            showSuccessToast(t.common.settingSaved);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final state = cubit.state;
    final sizeText = _cacheCalculating
        ? t.settings.calculatingCache
        : _formatCacheSize(_cacheSizeBytes);

    return SettingPageShell(
      grouped: true,
      title: t.settings.storage,
      child: SettingListView(
        children: [
          settingSectionTitle(
            context,
            t.settings.storage,
            icon: Icons.storage_outlined,
          ),
          TouchHoverIntent(
            identity: 'storage_setting_page:1',
            builder: (context, hover) => ListTile(
              hoverColor: hover.hoverColor(),
              leading: const InterfaceSymbol(
                symbol: 'trash',
                fallback: Icons.cleaning_services_outlined,
              ),
              title: Text(t.settings.cache),
              subtitle: Text(sizeText.isEmpty ? t.settings.cache : sizeText),
              trailing: const InterfaceSymbol(
                symbol: 'chevron.right',
                fallback: Icons.chevron_right,
              ),
              onTap: () async {
                await openSettingPage(
                  context,
                  route: CacheSettingRoute(),
                  builder: (_) => const CacheSettingPage(),
                );
                if (mounted) await _loadCacheSize();
              },
            ),
          ),
          TouchHoverIntent(
            identity: 'storage_setting_page:2',
            builder: (context, hover) => ListTile(
              hoverColor: hover.hoverColor(),
              leading: const InterfaceSymbol(
                symbol: 'arrow.up.arrow.down',
                fallback: Icons.import_export_outlined,
              ),
              title: Text(t.settings.dataBackup),
              subtitle: Text(t.settings.dataBackupSubtitle),
              trailing: const InterfaceSymbol(
                symbol: 'chevron.right',
                fallback: Icons.chevron_right,
              ),
              onTap: () => openSettingPage(
                context,
                route: DataBackupRoute(),
                builder: (_) => const DataBackupPage(),
              ),
            ),
          ),
          if (!Platform.isIOS) _customExportPath(state, cubit),
        ],
      ),
    );
  }
}
