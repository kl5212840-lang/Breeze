import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_routes;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/util/event/event.dart';

@RoutePage()
class SourceShellPage extends StatefulWidget {
  const SourceShellPage({
    super.key,
    required this.source,
    required this.sourceName,
    required this.sections,
  });

  final String source;
  final String sourceName;
  final List<SourceShellSection> sections;

  @override
  State<SourceShellPage> createState() => _SourceShellPageState();
}

class _SourceShellPageState extends State<SourceShellPage> {
  int _selectedIndex = 0;
  final Set<int> _visitedIndexes = {0};
  final Map<int, int> _tabRevisions = {};
  StreamSubscription<PluginLoginSucceeded>? _loginSubscription;

  @override
  void initState() {
    super.initState();
    _loginSubscription = eventBus.on<PluginLoginSucceeded>().listen((event) {
      if (!mounted || event.from != widget.source) return;
      setState(() {
        _tabRevisions[_selectedIndex] =
            (_tabRevisions[_selectedIndex] ?? 0) + 1;
      });
    });
  }

  @override
  void dispose() {
    _loginSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openLogin() async {
    await context.pushRoute(app_routes.LoginRoute(from: widget.source));
  }

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _visitedIndexes.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sourceName),
        actions: [
          IconButton(
            tooltip: t.sourceShell.search,
            icon: const Icon(Icons.search),
            onPressed: () => context.pushRoute(
              app_routes.SearchRoute(
                searchState: SearchStates.initial().copyWith(
                  from: widget.source,
                ),
                aggregateMode: false,
              ),
            ),
          ),
          IconButton(
            tooltip: t.sourceShell.account,
            icon: const Icon(Icons.person_outline),
            onPressed: _openLogin,
          ),
          IconButton(
            tooltip: t.sourceShell.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushRoute(
              app_routes.PluginSettingsRoute(
                from: widget.source,
                pluginUuid: widget.source,
                pluginRuntimeName: widget.source,
                pluginDisplayName: widget.sourceName,
              ),
            ),
          ),
        ],
      ),
      body: sections.isEmpty
          ? Center(child: Text(t.sourceShell.noSections))
          : IndexedStack(
              index: _selectedIndex,
              children: [
                for (var index = 0; index < sections.length; index++)
                  if (_visitedIndexes.contains(index))
                    ComicListPage(
                      key: ValueKey(
                        '${sections[index].id}-${_tabRevisions[index] ?? 0}',
                      ),
                      title: sections[index].title,
                      scene: sections[index].scene,
                      embedded: true,
                    )
                  else
                    const SizedBox.shrink(),
              ],
            ),
      bottomNavigationBar: sections.length > 1
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: _select,
              destinations: [
                for (final section in sections)
                  NavigationDestination(
                    icon: Icon(section.icon),
                    label: section.title,
                    tooltip: section.title,
                  ),
              ],
            )
          : null,
    );
  }
}
