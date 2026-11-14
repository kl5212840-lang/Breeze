import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_sections.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/widgets/plugin_icon.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/action_feedback.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_display_name_tile.dart';

/// Device-owned artwork is independent of plugin settings/schema and accounts.
class PluginLocalAppearanceSection extends StatefulWidget {
  const PluginLocalAppearanceSection({
    super.key,
    required this.pluginUuid,
    this.defaultIconUrl = '',
    this.enabled = true,
    this.imageStore,
    this.pickBytes,
    this.prepareImage,
  });
  final String pluginUuid, defaultIconUrl;
  final bool enabled;
  final LocalAppearanceImages? imageStore;
  final Future<Uint8List?> Function()? pickBytes;
  final Future<Uint8List> Function(Uint8List)? prepareImage;
  @override
  State<PluginLocalAppearanceSection> createState() =>
      _PluginLocalAppearanceSectionState();
}

class _PluginLocalAppearanceSectionState
    extends State<PluginLocalAppearanceSection> {
  LocalAppearanceImages get _images =>
      widget.imageStore ?? LocalAppearanceImages.instance;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _images.load();
    } catch (_) {
      if (mounted) showErrorToast(t.pluginAppearance.saveFailed);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) showErrorToast(t.pluginAppearance.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() => _run(() async {
    final key = LocalAppearanceImages.pluginIconKey(widget.pluginUuid);
    if (key == null) return;
    final saved = await pickLocalAppearanceImage(
      context,
      imageKey: key,
      title: t.pluginAppearance.chooseIcon,
      aspectRatio: 1,
      pickBytes: widget.pickBytes,
      prepare: widget.prepareImage,
      save: _images.save,
      canCommit: () =>
          mounted &&
          widget.enabled &&
          LocalAppearanceImages.pluginIconKey(widget.pluginUuid) == key,
    );
    if (saved != null &&
        mounted &&
        widget.enabled &&
        LocalAppearanceImages.pluginIconKey(widget.pluginUuid) == key &&
        _images.paths.value[key] == saved)
      showActionFeedback(context, t.common.saved);
  });
  Future<void> _restore(String expectedPath) => _run(() async {
    final uuid = widget.pluginUuid;
    final confirmed = await confirmLocalAppearanceImageRemoval(
      context,
      title: t.pluginAppearance.restoreConfirmTitle,
      description: t.pluginAppearance.restoreConfirm,
    );
    if (!confirmed ||
        !mounted ||
        !widget.enabled ||
        widget.pluginUuid != uuid) {
      return;
    }
    final removed = await _images.resetPluginIcon(uuid, expectedPath);
    if (removed &&
        mounted &&
        widget.enabled &&
        widget.pluginUuid == uuid &&
        _images.pluginIconPath(uuid) == null)
      showActionFeedback(context, t.common.saved);
  });
  @override
  Widget build(BuildContext context) {
    final key = LocalAppearanceImages.pluginIconKey(widget.pluginUuid);
    if (key == null) return const SizedBox.shrink();
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: _images.paths,
      builder: (context, paths, _) {
        final path = paths[key];
        return PluginSettingsSectionCard(
          title: t.pluginAppearance.title,
          colorScheme: Theme.of(context).colorScheme,
          footer: t.pluginAppearance.localOnly,
          children: [
            PluginDisplayNameTile(
              source: widget.pluginUuid,
              enabled: widget.enabled,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.pluginAppearance.icon,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox.square(
                        dimension: 88,
                        child: PluginIcon(
                          pluginUuid: widget.pluginUuid,
                          imageStore: _images,
                          url: widget.defaultIconUrl,
                          placeholder: ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            child: const Icon(
                              Icons.extension_outlined,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PluginSettingsFieldRow(
              title: t.pluginAppearance.chooseIcon,
              subtitle: '',
              trailing: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              onTap: _busy || !widget.enabled ? null : _choose,
            ),
            if (path != null)
              PluginSettingsFieldRow(
                title: t.pluginAppearance.restoreIcon,
                subtitle: '',
                trailing: const Icon(Icons.restore),
                onTap: _busy || !widget.enabled ? null : () => _restore(path),
              ),
          ],
        );
      },
    );
  }
}
