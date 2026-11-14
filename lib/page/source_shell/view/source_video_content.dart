import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/models/source_video_module.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

/// One source tab, with independent visited libraries and one outer navigation.
class SourceVideoContent extends StatefulWidget {
  const SourceVideoContent({
    super.key,
    required this.source,
    required this.actions,
    required this.leading,
    this.active = true,
    this.browseOnly,
    this.pluginCall,
  });

  final String source;
  final List<SourceShellAction> actions;
  final Widget leading;
  final bool active;
  final bool? browseOnly;
  final ApiVideoPluginCall? pluginCall;

  @override
  State<SourceVideoContent> createState() => _SourceVideoContentState();
}

class _SourceVideoContentState extends State<SourceVideoContent> {
  late final _modules = [
    for (final entry in widget.actions)
      ?SourceVideoModule.fromAction(entry.action, widget.source),
  ];
  late final _repositories = {
    for (final module in _modules)
      module.id: module.repository(pluginCall: widget.pluginCall),
  };
  int _selected = 0;
  final _visited = <int>{0};

  void _select(String id) {
    final index = _modules.indexWhere((module) => module.id == id);
    if (index < 0 || index == _selected) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_modules.isEmpty) return const SizedBox.shrink();
    return IndexedStack(
      index: _selected,
      children: [
        for (var index = 0; index < _modules.length; index++)
          if (_visited.contains(index))
            ApiVideoLibraryPage(
              key: ValueKey('${widget.source}:${_modules[index].id}'),
              repository: _repositories[_modules[index].id]!,
              title: _modules[index].title,
              embedded: true,
              browseOnly:
                  widget.browseOnly ??
                  (widget.source == 'e9f18928-3ba8-4d86-a12e-b53a62f47933'),
              active: widget.active && _selected == index,
              leading: widget.leading,
              moduleControl: _modules.length > 1
                  ? NativeVideoSegmentedControl(
                      key: const ValueKey('source-video.modules'),
                      options: {
                        for (final module in _modules) module.id: module.title,
                      },
                      selected: _modules[_selected].id,
                      onSelected: _select,
                    )
                  : null,
            )
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
