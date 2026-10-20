import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/page/discover/view/discover_scheme_renderer.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';

class PluginFunctionDialog extends StatelessWidget {
  const PluginFunctionDialog({
    super.key,
    required this.from,
    required this.functionId,
    required this.title,
    required this.onAction,
    required this.onLogin,
    required this.dialogWidth,
  });

  final String from;
  final String functionId;
  final String title;
  final Future<void> Function(Map<String, dynamic> action) onAction;
  final VoidCallback onLogin;
  final double dialogWidth;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PluginFunctionCubit()..load(from: from, functionId: functionId),
      child: AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.only(top: 8),
        content: BlocBuilder<PluginFunctionCubit, PluginFunctionState>(
          builder: (context, state) {
            if (state.loginRequired) {
              return SizedBox(
                width: dialogWidth,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.navigation.needLoginTitle),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onLogin();
                        },
                        child: Text(t.navigation.goLogin),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state.error.isNotEmpty) {
              return SizedBox(
                width: dialogWidth,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context
                            .read<PluginFunctionCubit>()
                            .load(from: from, functionId: functionId),
                        child: Text(t.common.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            final renderer = const DiscoverSchemeRenderer();
            return SizedBox(
              width: dialogWidth,
              height: 320,
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
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
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.close),
          ),
        ],
      ),
    );
  }
}
