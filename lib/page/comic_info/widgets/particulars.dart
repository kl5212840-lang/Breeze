import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/page/comic_info/widgets/reading_history_banner.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/download/download_byte_amount.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/comic_info/comic_info.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    show ComicInfo, ComicInfoActionItem;
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/api/simple.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';
import 'package:zephyr/widgets/toast.dart';

class ComicParticularsWidget extends StatelessWidget {
  final ComicInfo comicInfo;
  final String from;
  final ComicEntryType type;
  final VoidCallback? onContinueRead;
  final VoidCallback? onCoverTap;
  final Widget? sideActions;

  const ComicParticularsWidget({
    super.key,
    required this.comicInfo,
    required this.from,
    required this.type,
    this.onContinueRead,
    this.onCoverTap,
    this.sideActions,
  });

  @override
  Widget build(BuildContext context) {
    final pictureInfo = PictureInfo(
      from: from,
      url: comicInfo.cover.url,
      path: comicInfo.cover.path,
      chapterId: '',
      pictureType: PictureType.cover,
      cartoonId: comicInfo.id,
    );

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final info = _InfoColumn(
            comicInfo: comicInfo,
            from: from,
            type: type,
            onContinueRead: onContinueRead,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Cover(
                      pictureInfo: pictureInfo,
                      height: 176,
                      borderRadius: 14,
                      onTap: onCoverTap,
                    ),
                    if (sideActions != null) ...[
                      const SizedBox(width: 14),
                      Expanded(child: sideActions!),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                info,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cover(
                pictureInfo: pictureInfo,
                height: 230,
                borderRadius: 14,
                onTap: onCoverTap,
              ),
              const SizedBox(width: 16),
              Expanded(child: info),
              if (sideActions != null) ...[
                const SizedBox(width: 16),
                SizedBox(width: 170, child: sideActions!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoColumn extends StatefulWidget {
  const _InfoColumn({
    required this.comicInfo,
    required this.from,
    required this.type,
    required this.onContinueRead,
  });

  final ComicInfo comicInfo;
  final String from;
  final ComicEntryType type;
  final VoidCallback? onContinueRead;

  @override
  State<_InfoColumn> createState() => _InfoColumnState();
}

class _InfoColumnState extends State<_InfoColumn> {
  int? _storageSize;

  @override
  void initState() {
    super.initState();
    if (widget.type == ComicEntryType.download) {
      _calculateStorageSize();
    }
  }

  Future<void> _calculateStorageSize() async {
    try {
      final downloadPath = await getDownloadPath();
      int totalSize = 0;
      var foundDirectory = false;

      for (final storagePath in await _storageRoots(downloadPath)) {
        final dir = Directory(storagePath);
        try {
          if (!await dir.exists()) continue;
          foundDirectory = true;
          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              try {
                totalSize += await entity.length();
              } on FileSystemException {
                continue;
              }
            }
          }
        } on FileSystemException {
          // 某个历史目录不可访问时，继续统计其他兼容目录。
        }
      }

      if (foundDirectory && mounted) {
        setState(() => _storageSize = totalSize);
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<List<String>> _storageRoots(String downloadPath) async {
    final roots = <String, String>{};
    void addRoot(String path) {
      final normalized = p.normalize(p.absolute(path));
      final key = Platform.isWindows ? normalized.toLowerCase() : normalized;
      roots[key] = normalized;
    }

    final comicId = widget.comicInfo.id.trim();
    final sourceCandidates = <String>{
      widget.from.trim(),
      normalizePluginId(widget.from),
    }..removeWhere((source) => source.isEmpty);

    for (final source in sourceCandidates) {
      // 当前下载布局：hash(from)/hash(cartoonId)。
      try {
        addRoot(
          p.join(
            downloadPath,
            encodePath(path: source),
            encodePath(path: comicId),
          ),
        );
      } catch (_) {
        // Rust 编码服务尚未就绪时，仍继续统计历史目录。
      }

      // c703e334 产生的旧编码目录。
      try {
        addRoot(
          p.join(downloadPath, source, 'original', encodePath(path: comicId)),
        );
      } catch (_) {}

      // 更早的未编码目录。
      addRoot(p.join(downloadPath, source, 'original', comicId));
    }

    // 旧数据库记录可能保存了当时实际使用的绝对 storageRoot。
    for (final source in sourceCandidates) {
      final query = objectbox.unifiedDownloadBox
          .query(UnifiedComicDownload_.uniqueKey.equals('$source:$comicId'))
          .build();
      UnifiedComicDownload? download;
      try {
        download = query.findFirst();
      } finally {
        query.close();
      }
      final storedRoot = download?.storageRoot.trim() ?? '';
      if (storedRoot.isNotEmpty && p.isAbsolute(storedRoot)) {
        addRoot(storedRoot);
      }
    }

    return roots.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final displaySource = _resolvePluginDisplayName(widget.from);
    final titleStyle = context.theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: context.textColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: context.theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Text(
                displaySource,
                style: context.theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_storageSize != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: context.theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 14,
                      color: context.textColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      downloadByteAmount(_storageSize!),
                      style: context.theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          widget.comicInfo.title.let(convertChineseForDisplay),
          style: titleStyle,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.comicInfo.titleMeta
              .map((item) => ComicMetadataCopyPill(item: item))
              .toList(),
        ),
        ComicReadingHistoryBanner(
          source: widget.from,
          comicId: widget.comicInfo.id,
          comicTitle: widget.comicInfo.title,
          onContinueRead: widget.onContinueRead,
        ),
      ],
    );
  }

  String _resolvePluginDisplayName(String pluginIdRaw) {
    final pluginId = _normalizePluginId(pluginIdRaw);
    if (pluginId.isEmpty) {
      return pluginIdRaw.trim();
    }
    final info = PluginRegistryService.I.getCachedPluginInfo(pluginId);
    final name = info?['name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : pluginId;
  }

  String _normalizePluginId(String raw) {
    var value = raw.trim();
    while (value.length >= 2 && value.startsWith('(') && value.endsWith(')')) {
      value = value.substring(1, value.length - 1).trim();
    }
    return value;
  }
}

class ComicMetadataCopyPill extends StatelessWidget {
  const ComicMetadataCopyPill({super.key, required this.item});

  final ComicInfoActionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () async {
          final copyText = item.onLongPress?.trim().isNotEmpty == true
              ? item.onLongPress!.trim()
              : item.name;
          await Clipboard.setData(ClipboardData(text: copyText));
          showSuccessToast(
            t.comicInfo.copied(label: item.name.let(convertChineseForDisplay)),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Ink(
              decoration: BoxDecoration(
                color: context.theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.32,
                  ),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 38),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Text(
                    item.name.let(convertChineseForDisplay),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
