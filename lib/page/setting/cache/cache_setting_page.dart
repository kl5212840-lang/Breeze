import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';

import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

const Map<int, String> _cacheLimitLabels = {
  536870912: '512 MB',
  1073741824: '1 GB',
  2147483648: '2 GB',
  4294967296: '4 GB',
  8589934592: '8 GB',
  17179869184: '16 GB',
};

@RoutePage()
class CacheSettingPage extends StatefulWidget {
  const CacheSettingPage({super.key, this.source, this.sourceName});

  final String? source;
  final String? sourceName;

  @override
  State<CacheSettingPage> createState() => _CacheSettingPageState();
}

class _CacheSettingPageState extends State<CacheSettingPage> {
  int? _cacheSizeBytes;
  bool _calculating = false;
  bool _clearing = false;
  int _measurementGeneration = 0;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  @override
  void didUpdateWidget(covariant CacheSettingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _measurementGeneration++;
      _calculating = false;
      _cacheSizeBytes = null;
      _calculateCacheSize();
    }
  }

  Future<void> _calculateCacheSize() async {
    if (_calculating) return;
    final generation = ++_measurementGeneration;
    final source = widget.source;
    setState(() => _calculating = true);

    try {
      final cachePath = await getCachePath();
      final totalSize = await imageCacheSize(cachePath, source: source);

      if (!mounted || generation != _measurementGeneration) return;
      setState(() {
        _cacheSizeBytes = totalSize;
        _calculating = false;
      });
    } catch (_) {
      if (!mounted || generation != _measurementGeneration) return;
      setState(() {
        _cacheSizeBytes = null;
        _calculating = false;
      });
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return t.cache.calculateFailed;
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

  Future<void> _handleClearCache(BuildContext pageContext) async {
    if (_clearing) return;
    final source = widget.source;
    final confirmed = await showDialog<bool>(
      context: pageContext,
      builder: (context) => AlertDialog(
        title: Text(t.cache.clearCache),
        content: Text(
          source == null
              ? t.cache.clearCacheConfirm
              : t.cache.sourceClearConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.cache.clear),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _clearing || source != widget.source) {
      return;
    }
    setState(() => _clearing = true);

    try {
      final cachePath = await getCachePath();
      if (!mounted || source != widget.source) return;
      await clearCache(cachePath, source: source);
      if (!mounted || source != widget.source) return;
      showSuccessToast(t.cache.cleared);
      _measurementGeneration++;
      _calculating = false;
      await _calculateCacheSize();
    } on CacheWorkspaceBusy {
      if (mounted && source == widget.source) {
        showErrorToast(t.cache.backupBusy);
      }
    } catch (_) {
      if (mounted && source == widget.source) {
        showErrorToast(t.cache.clearFailed);
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.source == null
      ? _buildSettings(context)
      : SourceExperienceBoundary(
          source: widget.source!,
          builder: _buildSettings,
        );

  Widget _buildSettings(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final settings = cubit.state.cacheSetting;
    final savedLimit = settings.cacheSizeLimit;
    final effectiveCacheLimit = _cacheLimitLabels.containsKey(savedLimit)
        ? savedLimit
        : 1073741824;
    final sourceScoped = widget.source != null;
    final name = widget.sourceName?.trim() ?? '';

    return SettingPageShell(
      grouped: true,
      title: sourceScoped
          ? (name.isEmpty ? t.cache.sourceTitle : '$name · ${t.cache.title}')
          : t.cache.title,
      child: SettingListView(
        children: [
          settingSectionTitle(context, t.cache.currentCache),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(t.cache.cacheSize),
            subtitle: Text(
              _calculating ? t.cache.calculating : _formatSize(_cacheSizeBytes),
            ),
            trailing: _calculating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _cacheSizeBytes != null
                ? null
                : TouchHoverIntent(
                    identity: 'cache.recalculate',
                    builder: (context, hover) => IconButton(
                      style: ButtonStyle(
                        overlayColor: hover.overlayColor(null),
                      ),
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: t.cache.recalculate,
                      onPressed: _calculateCacheSize,
                    ),
                  ),
          ),
          TouchHoverIntent(
            identity: 'cache.clear',
            builder: (context, hover) => ListTile(
              hoverColor: hover.hoverColor(),
              leading: const Icon(Icons.cleaning_services_outlined),
              title: Text(t.cache.clearCache),
              trailing: _clearing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _clearing ? null : () => _handleClearCache(context),
            ),
          ),

          if (!sourceScoped) ...[
            settingSectionTitle(context, t.cache.cacheLimit),
            TouchHoverIntent(
              identity: 'cache.autoClear',
              builder: (context, hover) => BreezeSwitchListTile(
                SwitchListTile.adaptive(
                  hoverColor: hover.hoverColor(),
                  secondary: const Icon(Icons.auto_delete_outlined),
                  title: Text(t.cache.autoClean),
                  subtitle: Text(t.cache.autoCleanSubtitle),
                  thumbIcon: settingSwitchThumbIcon(context),
                  value: settings.autoCleanCache,
                  onChanged: (bool value) {
                    cubit.updateCacheSetting(
                      (current) => current.copyWith(autoCleanCache: value),
                    );
                  },
                ),
              ),
            ),
            if (settings.autoCleanCache)
              SettingChoiceTile<int>(
                leading: const Icon(Icons.data_thresholding_outlined),
                title: t.cache.sizeLimit,
                value: effectiveCacheLimit,
                valueIsFallback: effectiveCacheLimit != savedLimit,
                items: _cacheLimitLabels,
                onChanged: (int value) {
                  cubit.updateCacheSetting(
                    (current) => current.copyWith(cacheSizeLimit: value),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}
