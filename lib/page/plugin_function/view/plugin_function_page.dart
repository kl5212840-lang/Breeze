import 'dart:async';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/page/discover/view/discover_scheme_renderer.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_routes;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/widgets/bika_connection_notice.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';

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
  Widget build(BuildContext context) =>
      SourceExperienceBoundary(source: from, builder: _buildSourcePage);

  Widget _buildSourcePage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SourceBackButton(),
        title: Text(title),
        actions: [SourceMoreButton(source: from)],
      ),
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
    this.extern = const {},
  });

  final String from;
  final String functionId;
  final Future<void> Function(Map<String, dynamic> action) onAction;
  final Map<String, dynamic> extern;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PluginFunctionCubit()
            ..load(from: from, functionId: functionId, extern: extern),
      child: Builder(
        builder: (context) => ReadRecoveryHost(
          onActiveChanged: context.read<PluginFunctionCubit>().setReadActive,
          child: _PluginFunctionView(
            from: from,
            functionId: functionId,
            extern: extern,
            onAction: onAction,
          ),
        ),
      ),
    );
  }
}

class _PluginFunctionView extends StatelessWidget {
  const _PluginFunctionView({
    required this.from,
    required this.functionId,
    required this.onAction,
    required this.extern,
  });

  final String from;
  final String functionId;
  final Future<void> Function(Map<String, dynamic> action) onAction;
  final Map<String, dynamic> extern;

  @override
  Widget build(BuildContext context) {
    final renderer = const DiscoverSchemeRenderer();
    return BlocBuilder<PluginFunctionCubit, PluginFunctionState>(
      builder: (context, state) {
        final cubit = context.read<PluginFunctionCubit>();
        Future<bool> reload() => cubit.load(
          from: from,
          functionId: functionId,
          extern: extern,
          refresh: true,
        );
        final child = state.loading && !state.hasContent
            ? Center(child: SourceLoadingIndicator(source: from))
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
            : state.error.isNotEmpty && !state.hasContent
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
                          onPressed: reload,
                          child: Text(t.common.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : PullRefreshFeedback.indicator(
                active: ReadRecoveryScope.activeOf(context),
                scope: (from, functionId),
                onRefresh: () async {
                  final applied = await reload();
                  if (!context.mounted || cubit.isClosed) {
                    return PullRefreshResult.ignored;
                  }
                  if (!applied) {
                    return cubit.state.hasContent
                        ? PullRefreshResult.retained
                        : PullRefreshResult.ignored;
                  }
                  return PullRefreshResult.checked;
                },
                child: renderer.buildPage(
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
        return BikaConnectionNotice.wrap(
          source: from,
          scope: functionId,
          failure: !state.loading && !state.hasContent && !state.loginRequired
              ? state.error
              : null,
          ready: state.hasContent && !state.loading && state.error.isEmpty,
          retry: () => unawaited(reload()),
          child: child,
        );
      },
    );
  }
}
