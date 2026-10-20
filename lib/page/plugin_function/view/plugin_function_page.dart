import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/page/discover/view/discover_scheme_renderer.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_routes;
import 'package:zephyr/i18n/strings.g.dart';

@RoutePage()
class PluginFunctionPage extends StatelessWidget {
  const PluginFunctionPage({
    super.key,
    required this.from,
    required this.functionId,
    required this.title,
    required this.onAction,
  });

  final String from;
  final String functionId;
  final String title;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PluginFunctionContent(
        from: from,
        functionId: functionId,
        onAction: onAction,
      ),
    );
  }
}

/// The same plugin-defined page can live in a route or a persistent source tab.
class PluginFunctionContent extends StatelessWidget {
  const PluginFunctionContent({
    super.key,
    required this.from,
    required this.functionId,
    required this.onAction,
  });

  final String from;
  final String functionId;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PluginFunctionCubit()..load(from: from, functionId: functionId),
      child: _PluginFunctionView(
        from: from,
        functionId: functionId,
        onAction: onAction,
      ),
    );
  }
}

class _PluginFunctionView extends StatelessWidget {
  const _PluginFunctionView({
    required this.from,
    required this.functionId,
    required this.onAction,
  });

  final String from;
  final String functionId;
  final Future<void> Function(Map<String, dynamic> action) onAction;

  @override
  Widget build(BuildContext context) {
    final renderer = const DiscoverSchemeRenderer();
    return BlocBuilder<PluginFunctionCubit, PluginFunctionState>(
      builder: (context, state) => state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.loginRequired
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 44),
                  const SizedBox(height: 16),
                  Text(t.navigation.needLoginTitle),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () =>
                        context.pushRoute(app_routes.LoginRoute(from: from)),
                    child: Text(t.navigation.goLogin),
                  ),
                ],
              ),
            )
          : state.error.isNotEmpty
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_outlined,
                        size: 44,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(state.error, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => context
                            .read<PluginFunctionCubit>()
                            .load(from: from, functionId: functionId),
                        child: Text(t.common.retry),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : renderer.buildPage(
              context,
              from: from,
              scheme: state.scheme,
              data: state.data,
              onReachBottom: () async {},
              onAction: onAction,
              isLoadingMore: false,
              showLoadMoreRetry: false,
              onRetryLoadMore: () {},
            ),
    );
  }
}
