import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';

String pluginFunctionErrorMessage(Object error) {
  final message = normalizeSearchErrorMessage(error);
  if (pluginFunctionNeedsLogin(error)) {
    return t.navigation.needLoginTitle;
  }
  if (RegExp(
    r'timeout of \d+ms exceeded|timed out|连接服务器超时',
    caseSensitive: false,
  ).hasMatch(message)) {
    return t.sourceShell.requestTimedOut;
  }
  return userFacingErrorMessage(error);
}

bool pluginFunctionNeedsLogin(Object error) {
  final message = normalizeSearchErrorMessage(error).split('\n').first;
  return RegExp(
    r'需要登录|请(?:先|重新)?登录|登录(?:已)?过期|未登录|login required|please (?:log|sign) in|not logged in|unauthorized',
    caseSensitive: false,
  ).hasMatch(message);
}

class PluginFunctionState {
  const PluginFunctionState({
    this.loading = true,
    this.error = '',
    this.loginRequired = false,
    this.scheme = const <String, dynamic>{},
    this.data = const <String, dynamic>{},
  });

  final bool loading;
  final String error;
  final bool loginRequired;
  final Map<String, dynamic> scheme;
  final Map<String, dynamic> data;

  PluginFunctionState copyWith({
    bool? loading,
    String? error,
    bool? loginRequired,
    Map<String, dynamic>? scheme,
    Map<String, dynamic>? data,
  }) {
    return PluginFunctionState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      loginRequired: loginRequired ?? this.loginRequired,
      scheme: scheme ?? this.scheme,
      data: data ?? this.data,
    );
  }
}

class PluginFunctionCubit extends Cubit<PluginFunctionState> {
  PluginFunctionCubit() : super(const PluginFunctionState());

  Future<void> load({required String from, required String functionId}) async {
    if (isClosed) return;
    _emit(
      state.copyWith(
        loading: true,
        error: '',
        loginRequired: false,
        scheme: const <String, dynamic>{},
        data: const <String, dynamic>{},
      ),
    );
    try {
      Map<String, dynamic> response;
      response = await callUnifiedComicPlugin(
        from: from,
        fnPath: 'getFunctionPage',
        core: {'id': functionId},
        extern: const <String, dynamic>{},
      );

      final envelope = UnifiedPluginEnvelope.fromMap(response);
      _emit(
        state.copyWith(
          loading: false,
          error: '',
          scheme: envelope.scheme,
          data: asJsonMap(envelope.data),
        ),
      );
    } catch (e) {
      _emit(
        state.copyWith(
          loading: false,
          error: pluginFunctionErrorMessage(e),
          loginRequired: pluginFunctionNeedsLogin(e),
        ),
      );
    }
  }

  void _emit(PluginFunctionState nextState) {
    if (!isClosed) emit(nextState);
  }
}
