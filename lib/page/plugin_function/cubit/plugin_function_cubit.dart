import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'dart:async';
import 'dart:convert';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
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
  if (error is PluginLoginRequiredException) return true;
  final message = normalizeSearchErrorMessage(error).split('\n').first;
  return RegExp(
    r'需要登录|请(?:先|重新)?登录|登录(?:已)?过期|未登录|login required|please (?:log|sign) in|not logged in|unauthorized',
    caseSensitive: false,
  ).hasMatch(message);
}

class PluginFunctionState {
  const PluginFunctionState({
    this.loading = true,
    this.hasContent = false,
    this.error = '',
    this.loginRequired = false,
    this.scheme = const <String, dynamic>{},
    this.data = const <String, dynamic>{},
  });

  final bool loading;
  final bool hasContent;
  final String error;
  final bool loginRequired;
  final Map<String, dynamic> scheme;
  final Map<String, dynamic> data;

  PluginFunctionState copyWith({
    bool? loading,
    bool? hasContent,
    String? error,
    bool? loginRequired,
    Map<String, dynamic>? scheme,
    Map<String, dynamic>? data,
  }) {
    return PluginFunctionState(
      loading: loading ?? this.loading,
      hasContent: hasContent ?? this.hasContent,
      error: error ?? this.error,
      loginRequired: loginRequired ?? this.loginRequired,
      scheme: scheme ?? this.scheme,
      data: data ?? this.data,
    );
  }
}

class PluginFunctionCubit extends Cubit<PluginFunctionState> {
  PluginFunctionCubit({
    Future<Map<String, dynamic>> Function(String, String, Map<String, dynamic>)?
    request,
  }) : _request = request,
       super(const PluginFunctionState()) {
    _session = pluginSessionWriteFence.changes.listen((boundary) {
      if (isClosed || boundary.source != _from) return;
      _epoch++;
      unawaited(_reads.cancel());
      _pending = null;
      _recovery?.reset();
      _emit(const PluginFunctionState());
      if (!boundary.changing) _recovery?.invalidate();
    });
  }

  final Future<Map<String, dynamic>> Function(
    String,
    String,
    Map<String, dynamic>,
  )?
  _request;
  final _reads = PageReadTasks();
  late final StreamSubscription<PluginSessionBoundary> _session;
  ReadRecoveryController? _recovery;
  String _from = '', _function = '', _query = '';
  Map<String, dynamic> _extern = const {};
  int _epoch = 0;
  bool _active = false;
  Future<bool>? _pending;

  void setReadActive(bool active) {
    _active = active;
    _recovery?.setActive(active);
  }

  Future<bool> load({
    required String from,
    required String functionId,
    Map<String, dynamic> extern = const {},
    bool refresh = false,
  }) {
    if (isClosed) return Future.value(false);
    final query = jsonEncode([from, functionId, extern]);
    if (_query == query && _pending != null) return _pending!;
    final changed = _query != query;
    if (changed) {
      unawaited(_reads.cancel());
      _query = query;
      _from = from;
      _function = functionId;
      _extern = Map<String, dynamic>.from(extern);
      _recovery?.dispose();
      _recovery = ReadRecoveryController(
        source: from,
        active: _active,
        retry: () => load(from: _from, functionId: _function, extern: _extern),
      );
      _emit(const PluginFunctionState());
    }
    if (pluginSessionWriteFence.isChanging(from)) return Future.value(false);
    final epoch = ++_epoch;
    final generation = pluginSessionWriteFence.generation(from);
    final task = _load(from, functionId, extern, epoch, generation, refresh);
    _pending = task;
    return task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    });
  }

  bool _current(String from, int epoch, int generation) =>
      !isClosed &&
      epoch == _epoch &&
      generation == pluginSessionWriteFence.generation(from) &&
      !pluginSessionWriteFence.isChanging(from);

  Future<bool> _load(
    String from,
    String functionId,
    Map<String, dynamic> extern,
    int epoch,
    int generation,
    bool refresh,
  ) async {
    _emit(state.copyWith(loading: true, error: '', loginRequired: false));
    try {
      final response = await (_request != null
          ? _request(from, functionId, extern)
          : _reads.run(
              from,
              (group) => callUnifiedComicPlugin(
                from: from,
                fnPath: 'getFunctionPage',
                core: {'id': functionId},
                extern: extern,
                taskGroupKey: group,
                refresh: refresh,
              ),
            ));
      if (!_current(from, epoch, generation)) return false;
      requireSuccessfulPluginEnvelope(response);
      final envelope = UnifiedPluginEnvelope.fromMap(response);
      requireSuccessfulPluginEnvelope(envelope.data);
      _recovery?.succeeded();
      _emit(
        state.copyWith(
          loading: false,
          hasContent: true,
          error: '',
          loginRequired: false,
          scheme: envelope.scheme,
          data: asJsonMap(envelope.data),
        ),
      );
      return true;
    } catch (error) {
      if (!_current(from, epoch, generation)) return false;
      _recovery?.failed(error);
      final login = pluginFunctionNeedsLogin(error);
      _emit(
        state.copyWith(
          loading: false,
          error: pluginFunctionErrorMessage(error),
          loginRequired: login,
          hasContent: login ? false : state.hasContent,
          scheme: login ? const {} : state.scheme,
          data: login ? const {} : state.data,
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() async {
    _epoch++;
    _recovery?.dispose();
    await _session.cancel();
    await _reads.cancel();
    return super.close();
  }

  void _emit(PluginFunctionState nextState) {
    if (!isClosed) emit(nextState);
  }
}
