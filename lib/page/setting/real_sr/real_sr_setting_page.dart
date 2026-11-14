import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/real_sr/service/android_ncnn_model_config.dart';
import 'package:zephyr/page/setting/real_sr/service/desktop_ncnn_model_config.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_settings.dart';
import 'package:zephyr/page/setting/real_sr/service/real_sr_super_resolution.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/coreml_model_config.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

final Map<int, String> _concurrencyLabels = {
  1: '1',
  2: '2',
  4: '4',
  6: '6',
  8: '8',
  0: t.realSr.unlimited,
};

const Map<int, String> _tileSizeLabels = {
  0: '0',
  128: '128',
  256: '256',
  512: '512',
  1024: '1024',
};

final List<int> _concurrencyOptions = _concurrencyLabels.keys.toList()..sort();
final List<int> _tileSizeOptions = _tileSizeLabels.keys.toList()..sort();

@RoutePage()
class RealSrSettingPage extends StatefulWidget {
  const RealSrSettingPage({super.key});

  @override
  State<RealSrSettingPage> createState() => _RealSrSettingPageState();
}

class _RealSrSettingPageState extends State<RealSrSettingPage> {
  bool _loading = true;
  bool _autoUpscale = false;
  RealSrResolutionThreshold _resolutionThreshold =
      RealSrResolutionThreshold.p720;
  int _concurrency = 2;
  int _tileSize = 0;
  AndroidNcnnMode _desktopNcnnMode = DesktopNcnnModelConfig.defaultMode;
  AndroidNcnnNoise _desktopNcnnNoise = DesktopNcnnModelConfig.defaultNoise;
  CoreMLModelFamily _coreMLFamily = CoreMLModelConfig.defaultFamily;
  CoreMLModelVariant _coreMLVariant = CoreMLModelConfig.defaultVariant;
  bool _isAvailable = false;
  bool _downloading = false;
  bool _importing = false;
  double _downloadProgress = 0;

  bool get _usesCoreML => Platform.isIOS || Platform.isMacOS;

  List<RealSrResolutionThreshold> get _availableThresholds {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return RealSrResolutionThreshold.values;
    }
    return const [
      RealSrResolutionThreshold.p540,
      RealSrResolutionThreshold.p720,
      RealSrResolutionThreshold.p1080,
    ];
  }

  RealSrResolutionThreshold get _effectiveThreshold {
    if (_availableThresholds.contains(_resolutionThreshold)) {
      return _resolutionThreshold;
    }
    return RealSrResolutionThreshold.p1080;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final family = await RealSrSettings.loadCoreMLFamily();
    final variant = await RealSrSettings.loadCoreMLVariant(family);
    final results = await Future.wait([
      RealSrSettings.loadAutoUpscale(),
      RealSrSettings.loadResolutionThreshold(),
      RealSrSettings.loadConcurrency(),
      RealSrSettings.loadTileSize(),
      RealSrSettings.loadDesktopNcnnMode(),
      RealSrSettings.loadDesktopNcnnNoise(),
      RealSrSuperResolution.isAvailable,
    ]);

    if (!mounted) return;
    setState(() {
      _autoUpscale = results[0] as bool;
      _resolutionThreshold = results[1] as RealSrResolutionThreshold;
      _concurrency = results[2] as int;
      _tileSize = results[3] as int;
      _desktopNcnnMode = results[4] as AndroidNcnnMode;
      _desktopNcnnNoise = results[5] as AndroidNcnnNoise;
      _isAvailable = results[6] as bool;
      _coreMLFamily = family;
      _coreMLVariant = variant;
      _loading = false;
    });
  }

  Future<void> _setAutoUpscale(bool value) async {
    await RealSrSettings.saveAutoUpscale(value);
    setState(() => _autoUpscale = value);
  }

  Future<void> _setResolutionThreshold(RealSrResolutionThreshold value) async {
    await RealSrSettings.saveResolutionThreshold(value);
    setState(() => _resolutionThreshold = value);
  }

  Future<void> _setConcurrency(int value) async {
    await RealSrSettings.saveConcurrency(value);
    setState(() => _concurrency = value);
  }

  Future<void> _setTileSize(int value) async {
    await RealSrSettings.saveTileSize(value);
    setState(() => _tileSize = value);
  }

  Future<void> _setDesktopNcnnMode(AndroidNcnnMode value) async {
    await RealSrSettings.saveDesktopNcnnMode(value);
    setState(() => _desktopNcnnMode = value);
  }

  Future<void> _setDesktopNcnnNoise(AndroidNcnnNoise value) async {
    await RealSrSettings.saveDesktopNcnnNoise(value);
    setState(() => _desktopNcnnNoise = value);
  }

  Future<void> _setCoreMLFamily(CoreMLModelFamily value) async {
    final newVariant = value.variants.first;
    await Future.wait([
      RealSrSettings.saveCoreMLFamily(value),
      RealSrSettings.saveCoreMLVariant(newVariant),
    ]);
    setState(() {
      _coreMLFamily = value;
      _coreMLVariant = newVariant;
    });
  }

  Future<void> _setCoreMLVariant(CoreMLModelVariant value) async {
    await RealSrSettings.saveCoreMLVariant(value);
    setState(() => _coreMLVariant = value);
  }

  Future<void> _refreshAvailability() async {
    final available = await RealSrSuperResolution.isAvailable;
    if (mounted) setState(() => _isAvailable = available);
  }

  Future<void> _downloadModel() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      await RealSrSuperResolution.downloadModel(
        force: _isAvailable,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _downloadProgress = received / total);
        },
      );
    } catch (e, s) {
      logger.e('模型下载失败', error: e, stackTrace: s);
      showErrorToast('${t.realSr.modelDownloadFailed}: $e');
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        await _refreshAvailability();
      }
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.realSr.deleteModel),
        content: Text(t.realSr.deleteModelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await RealSrSuperResolution.deleteModel();
      showSuccessToast(t.realSr.modelDeleted);
    } catch (e, s) {
      logger.e('模型删除失败', error: e, stackTrace: s);
      showErrorToast('${t.realSr.modelDeleteFailed}: $e');
    } finally {
      if (mounted) await _refreshAvailability();
    }
  }

  Future<void> _openManualDownloadUrl() async {
    final url = RealSrSuperResolution.manualDownloadUrl;
    if (url == null) {
      showErrorToast(t.realSr.manualDownloadUnsupported);
      return;
    }
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showErrorToast(t.realSr.openDownloadUrlFailed);
    }
  }

  Future<void> _importModel() async {
    // iOS 没有系统声明的 7z UTI，使用通用数据类型后由导入逻辑校验 7z 魔数。
    final typeGroup = Platform.isIOS
        ? const XTypeGroup(label: '7z')
        : const XTypeGroup(label: '7z', extensions: ['7z']);
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: [typeGroup]);
    } catch (e) {
      showErrorToast('${t.realSr.modelImportFailed}: $e');
      return;
    }
    if (file == null) return;

    setState(() => _importing = true);
    try {
      await RealSrSuperResolution.importModelArchive(file.path);
      if (mounted) showSuccessToast(t.realSr.modelImportSuccess);
    } catch (e, s) {
      logger.e('模型导入失败', error: e, stackTrace: s);
      if (mounted) {
        showErrorToast('${t.realSr.modelImportFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
        await _refreshAvailability();
      }
    }
  }

  String get _coreMLBlockInfo {
    final blockSize = _coreMLVariant.config['blockSize'] as int? ?? 0;
    final shrinkSize = _coreMLVariant.config['shrinkSize'] as int? ?? 0;
    final contentSize = CoreMLModelConfig.contentBlockSize(_coreMLVariant);
    return t.realSr.blockInfoFormat(
      contentSize: contentSize,
      blockSize: blockSize,
      shrinkSize: shrinkSize,
    );
  }

  List<Widget> _buildModelItems() {
    if (_usesCoreML) {
      return [
        SettingChoiceTile<CoreMLModelFamily>(
          leading: const Icon(Icons.speed_outlined),
          title: t.realSr.model,
          description: t.realSr.modelSubtitle,
          value: _coreMLFamily,
          items: {
            for (final family in CoreMLModelConfig.families)
              family: family.localizedLabel,
          },
          onChanged: _setCoreMLFamily,
        ),
        SettingChoiceTile<CoreMLModelVariant>(
          leading: const Icon(Icons.healing_outlined),
          title: t.realSr.noiseLevel,
          description: t.realSr.noiseLevelSubtitle,
          value: _coreMLVariant,
          items: {
            for (final variant in _coreMLFamily.variants)
              variant: variant.localizedDisplayName,
          },
          onChanged: _setCoreMLVariant,
        ),
        SettingDetailsNotes(
          sectionTitle: t.realSr.blockInfo,
          details: {'': '$_coreMLBlockInfo\n\n${t.realSr.blockInfoTooltip}'},
        ),
      ];
    }

    if (Platform.isAndroid) {
      return [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(t.realSr.androidSuperResolution),
          subtitle: Text(t.realSr.androidSuperResolutionSubtitle),
        ),
      ];
    }

    return [
      SettingChoiceTile<AndroidNcnnMode>(
        leading: const Icon(Icons.speed_outlined),
        title: t.realSr.desktopStrategy,
        description: t.realSr.desktopStrategySubtitle,
        value: _desktopNcnnMode,
        items: {for (final mode in AndroidNcnnMode.values) mode: mode.label},
        onChanged: _setDesktopNcnnMode,
      ),
      SettingChoiceTile<AndroidNcnnNoise>(
        leading: const Icon(Icons.healing_outlined),
        title: t.realSr.desktopNoiseLevel,
        description: t.realSr.desktopNoiseLevelSubtitle,
        value: _desktopNcnnNoise,
        items: {
          for (final noise in AndroidNcnnNoise.values) noise: noise.label,
        },
        onChanged: _setDesktopNcnnNoise,
      ),
    ];
  }

  Widget _buildModelManagementTile() {
    if (_downloading) {
      return ListTile(
        leading: const Icon(Icons.downloading_outlined),
        title: Text(t.realSr.downloadingModel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 4),
            Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
          ],
        ),
      );
    }

    if (_isAvailable) {
      return ListTile(
        leading: Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(t.realSr.modelReady),
        subtitle: Wrap(
          spacing: 8,
          children: [
            TouchHoverIntent(
              identity: 'real_sr_setting_page.button:0',
              builder: (context, hover) {
                final style = TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                );
                return TextButton(
                  style: style.copyWith(
                    overlayColor: hover.overlayColor(style.overlayColor),
                  ),
                  onPressed: _deleteModel,
                  child: Text(t.realSr.deleteModel),
                );
              },
            ),
            TouchHoverIntent(
              identity: 'real_sr_setting_page.button:1',
              builder: (context, hover) {
                final style = TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                );
                return TextButton(
                  style: style.copyWith(
                    overlayColor: hover.overlayColor(style.overlayColor),
                  ),
                  onPressed: _downloadModel,
                  child: Text(t.realSr.redownload),
                );
              },
            ),
          ],
        ),
      );
    }

    return ListTile(
      leading: const Icon(Icons.warning_amber_rounded),
      title: Text(t.realSr.modelNotDownloaded),
      subtitle: Text(t.realSr.modelNotDownloadedSubtitle),
      trailing: TouchHoverIntent(
        identity: 'real_sr_setting_page.button:2',
        builder: (context, hover) {
          final style = ElevatedButton.styleFrom(
            minimumSize: const Size(44, 44),
          );
          return ElevatedButton(
            style: style.copyWith(
              overlayColor: hover.overlayColor(style.overlayColor),
            ),
            onPressed: _downloadModel,
            child: Text(t.realSr.downloadModel),
          );
        },
      ),
    );
  }

  Widget _buildManualDownloadTile() {
    final url = RealSrSuperResolution.manualDownloadUrl;
    if (url == null) {
      return ListTile(
        leading: const Icon(Icons.open_in_browser_outlined),
        title: Text(t.realSr.manualDownload),
        subtitle: Text(t.realSr.manualDownloadUnsupported),
      );
    }
    return ListTile(
      leading: const Icon(Icons.open_in_browser_outlined),
      title: Text(t.realSr.manualDownload),
      subtitle: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: TouchHoverIntent(
        identity: 'real_sr_setting_page.button:3',
        builder: (context, hover) {
          final style = TextButton.styleFrom(minimumSize: const Size(44, 44));
          return TextButton(
            style: style.copyWith(
              overlayColor: hover.overlayColor(style.overlayColor),
            ),
            onPressed: _openManualDownloadUrl,
            child: Text(t.realSr.openDownloadUrl),
          );
        },
      ),
    );
  }

  Widget _buildImportModelTile() {
    return ListTile(
      leading: const Icon(Icons.file_open_outlined),
      title: Text(t.realSr.importModel),
      subtitle: Text(t.realSr.importModelSubtitle),
      trailing: _importing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TouchHoverIntent(
              identity: 'real_sr_setting_page.button:4',
              builder: (context, hover) {
                final style = TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                );
                return TextButton(
                  style: style.copyWith(
                    overlayColor: hover.overlayColor(style.overlayColor),
                  ),
                  onPressed: _importModel,
                  child: Text(t.realSr.importModelAction),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingPageShell(
      grouped: true,
      title: t.realSr.title,
      child: _loading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : SettingListView(
              children: [
                settingSectionTitle(context, t.realSr.autoUpscaleSection),
                TouchHoverIntent(
                  identity: 'real_sr_setting_page.switch:0',
                  builder: (context, hover) => BreezeSwitchListTile(
                    SwitchListTile.adaptive(
                      hoverColor: hover.hoverColor(),
                      secondary: const Icon(Icons.auto_fix_high_outlined),
                      title: Text(t.realSr.autoUpscale),
                      subtitle: Text(
                        !_isAvailable
                            ? t.realSr.autoUpscaleSubtitleUnavailable
                            : t.realSr.autoUpscaleSubtitleAvailable,
                      ),
                      thumbIcon: settingSwitchThumbIcon(context),
                      value: _autoUpscale,
                      onChanged: _setAutoUpscale,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.3),
                settingSectionTitle(context, t.realSr.conditionSection),
                SettingChoiceTile<RealSrResolutionThreshold>(
                  leading: const Icon(Icons.hd_outlined),
                  title: t.realSr.resolutionThreshold,
                  description: t.realSr.resolutionThresholdSubtitle,
                  value: _effectiveThreshold,
                  valueIsFallback: _effectiveThreshold != _resolutionThreshold,
                  items: {
                    for (final threshold in _availableThresholds)
                      threshold: threshold.label,
                  },
                  onChanged: _setResolutionThreshold,
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.3),
                settingSectionTitle(context, t.realSr.performanceSection),
                Builder(
                  builder: (context) {
                    final effective = _concurrencyOptions.contains(_concurrency)
                        ? _concurrency
                        : RealSrSettings.defaultConcurrency;
                    return SettingChoiceTile<int>(
                      leading: const Icon(Icons.speed_outlined),
                      title: t.realSr.concurrency,
                      description: t.realSr.concurrencySubtitle,
                      value: effective,
                      valueIsFallback: effective != _concurrency,
                      items: {
                        for (final option in _concurrencyOptions)
                          option: _concurrencyLabels[option]!,
                      },
                      onChanged: _setConcurrency,
                    );
                  },
                ),
                if (!_usesCoreML)
                  Builder(
                    builder: (context) {
                      final effective = _tileSizeOptions.contains(_tileSize)
                          ? _tileSize
                          : 0;
                      return SettingChoiceTile<int>(
                        leading: const Icon(Icons.grid_on_outlined),
                        title: t.realSr.tileSize,
                        description: t.realSr.tileSizeSubtitle,
                        value: effective,
                        valueIsFallback: effective != _tileSize,
                        items: {
                          for (final option in _tileSizeOptions)
                            option: _tileSizeLabels[option]!,
                        },
                        onChanged: _setTileSize,
                      );
                    },
                  ),

                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.3),
                settingSectionTitle(context, t.realSr.modelSection),
                ..._buildModelItems(),

                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.3),
                settingSectionTitle(context, t.realSr.modelManagementSection),
                _buildModelManagementTile(),
                _buildManualDownloadTile(),
                _buildImportModelTile(),
              ],
            ),
    );
  }
}
