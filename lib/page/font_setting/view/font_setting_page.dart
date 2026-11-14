import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:auto_route/annotations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:zephyr/util/font/font_profile.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class FontSettingPage extends StatefulWidget {
  const FontSettingPage({super.key});
  @override
  State<FontSettingPage> createState() => _FontSettingPageState();
}

class _FontSettingPageState extends State<FontSettingPage> {
  bool _busy = false;

  static const _weights = <int>[100, 200, 300, 400, 500, 600, 700, 800, 900];
  static final _sampleText = t.fontSetting.sampleText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.fontSetting.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: t.fontSetting.clear,
            onPressed: _busy ? null : _clearAll,
            icon: const Icon(Icons.restart_alt_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: FontProfileController.instance,
        builder: (context, _) {
          final controller = FontProfileController.instance;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(t.fontSetting.hint),
              ),
              ..._weights.map((weight) {
                final filePath = controller.pathForWeight(weight) ?? '';
                return _FontWeightTile(
                  weight: weight,
                  label: fontWeightLabels[weight]!,
                  filePath: filePath,
                  sampleText: _sampleText,
                  onPick: _busy ? null : () => _pickWeight(weight),
                  onClear: _busy || filePath.isEmpty
                      ? null
                      : () => _clearWeight(weight, filePath),
                );
              }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) showErrorToast(t.fontSetting.operationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickWeight(int weight) => _run(() async {
    const typeGroup = XTypeGroup(
      label: 'font',
      extensions: ['ttf', 'otf', 'ttc'],
      uniformTypeIdentifiers: ['public.font'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;
    await _saveWeight(weight, file.path);
  });

  Future<void> _saveWeight(int weight, String filePath) async {
    final ok = await FontProfileController.instance.setPath(weight, filePath);
    if (!mounted) return;
    if (!ok) {
      showErrorToast(t.fontSetting.loadFailed);
      return;
    }
    showSuccessToast(
      filePath.isEmpty ? t.fontSetting.cleared : t.fontSetting.saved,
    );
  }

  Future<bool> _confirmClear({int? weight}) async {
    var decided = false;
    void finish(BuildContext dialog, bool result) {
      if (decided ||
          !dialog.mounted ||
          ModalRoute.of(dialog)?.isCurrent != true) {
        return;
      }
      decided = true;
      Navigator.pop(dialog, result);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(
          weight == null
              ? t.fontSetting.clearAllConfirmTitle
              : t.fontSetting.clearFileConfirmTitle,
        ),
        content: Text(
          weight == null
              ? t.fontSetting.clearAllConfirm
              : t.fontSetting.clearFileConfirm(weight: weight),
        ),
        actions: [
          TextButton(
            onPressed: () => finish(dialog, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => finish(dialog, true),
            child: Text(
              t.common.remove,
              style: TextStyle(color: Theme.of(dialog).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _clearWeight(int weight, String expectedPath) => _run(() async {
    if (!await _confirmClear(weight: weight)) return;
    if (FontProfileController.instance.pathForWeight(weight) != expectedPath) {
      return;
    }
    await _saveWeight(weight, '');
  });

  Future<void> _clearAll() => _run(() async {
    final expected = {...FontProfileController.instance.paths};
    if (!await _confirmClear()) return;
    final current = FontProfileController.instance.paths;
    if (current.length != expected.length ||
        expected.entries.any((entry) => current[entry.key] != entry.value)) {
      return;
    }
    await FontProfileController.instance.clearAll();
    if (mounted) showSuccessToast(t.fontSetting.allCleared);
  });
}

class _FontWeightTile extends StatelessWidget {
  const _FontWeightTile({
    required this.weight,
    required this.label,
    required this.filePath,
    required this.sampleText,
    required this.onPick,
    required this.onClear,
  });

  final int weight;
  final String label;
  final String filePath;
  final String sampleText;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontWeight = _toFontWeight(weight);
    final previewStyle = FontProfileController.instance.applyStyleForWeight(
      TextStyle(fontWeight: fontWeight, fontSize: 16),
      weight,
    );

    return ListTile(
      leading: SizedBox(
        width: 86,
        child: Text(
          'w$weight\n$label',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        filePath.isEmpty
            ? t.fontSetting.noFileSelected
            : path.basename(filePath),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (filePath.isNotEmpty)
              Text(
                filePath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            Text(sampleText, style: previewStyle),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onClear != null) ...[
                    _action(
                      identity: (weight, 'font-button:0'),
                      tooltip: t.fontSetting.clearFile,
                      onPressed: onClear,
                      icon: Icons.close_outlined,
                    ),
                    const SizedBox(width: 4),
                  ],
                  _action(
                    identity: (weight, 'font-button:1'),
                    tooltip: t.fontSetting.selectFile,
                    onPressed: onPick,
                    icon: Icons.folder_open_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required Object identity,
    required String tooltip,
    required VoidCallback? onPressed,
    required IconData icon,
  }) => TouchHoverIntent(
    identity: identity,
    builder: (context, hover) {
      final style = IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        fixedSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      );
      return IconButton(
        style: style.copyWith(
          overlayColor: hover.overlayColor(style.overlayColor),
        ),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      );
    },
  );

  FontWeight _toFontWeight(int weight) {
    switch (weight) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      default:
        return FontWeight.w900;
    }
  }
}
