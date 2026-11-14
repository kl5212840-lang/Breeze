import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';

enum SourceNetworkMode { inherit, system, proxy }

/// Device-local preferences. In particular, loopback endpoints never enter
/// cloud settings or the plugin's account/configuration storage.
class SourceNetworkPreference {
  const SourceNetworkPreference({
    this.mode = SourceNetworkMode.inherit,
    this.address = '',
    this.socks = false,
  });
  final SourceNetworkMode mode;
  final String address;
  final bool socks;

  static String proxyUrl(String raw, bool socks) {
    final value = raw.trim();
    final scheme = socks ? 'socks5' : 'http';
    final explicitScheme = value.contains('://');
    final uri = Uri.tryParse(explicitScheme ? value : '$scheme://$value');
    if (uri == null ||
        (socks
            ? uri.scheme != scheme
            : !const {'http', 'https'}.contains(uri.scheme)) ||
        uri.host.isEmpty ||
        (!uri.hasPort && !(explicitScheme && !socks)) ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid proxy address');
    }
    return uri.replace(path: '').toString();
  }

  String effectiveProxy(ProxySettingState global) => switch (mode) {
    SourceNetworkMode.system => '',
    SourceNetworkMode.proxy => proxyUrl(address, socks),
    SourceNetworkMode.inherit =>
      global.enabled && global.address.trim().isNotEmpty
          ? proxyUrl(global.address, global.type == ProxyType.socks5)
          : '',
  };
}

class SourceNetworkSnapshot {
  const SourceNetworkSnapshot({required this.source, required this.proxy});
  final String source;
  final String proxy;

  String get runtimeName =>
      '$source@net.${sha256.convert(utf8.encode(proxy)).toString().substring(0, 12)}';
}

class _SourceVisit {
  _SourceVisit(this.snapshot);
  final SourceNetworkSnapshot snapshot;
  int owners = 0;
}

class SourceNetworkLease {
  SourceNetworkLease._(this._visit);
  final _SourceVisit _visit;
  bool _closed = false;
  SourceNetworkSnapshot get snapshot => _visit.snapshot;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _visit.owners--;
    if (_visit.owners == 0 &&
        identical(SourceNetworkPolicies._visits[snapshot.source], _visit)) {
      SourceNetworkPolicies._visits.remove(snapshot.source);
    }
  }
}

abstract final class SourceNetworkPolicies {
  static ProxySettingState Function() _readGlobal = () =>
      const ProxySettingState();
  static String? _developmentProxy;
  static final _changes = StreamController<String>.broadcast(sync: true);
  static Stream<String> get changes => _changes.stream;
  static final _visits = <String, _SourceVisit>{};
  static final _opening = <String, Future<_SourceVisit>>{};
  static final _sourcePattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _runtimePattern = RegExp(r'@net\.[0-9a-f]{12}(?=$|[.:])');

  static void initialize(
    ProxySettingState Function() readGlobal, {
    String? developmentProxy,
  }) {
    _readGlobal = readGlobal;
    // A validated debug endpoint is process-local. Release builds and explicit
    // user routes never inherit a simulator's host-only proxy address.
    _developmentProxy = kDebugMode && developmentProxy != null
        ? SourceNetworkPreference.proxyUrl(developmentProxy, false)
        : null;
  }

  static String canonicalSource(String runtime) {
    final match = _runtimePattern.firstMatch(runtime);
    if (match == null) return runtime;
    final candidate = runtime.substring(0, match.start);
    return _sourcePattern.hasMatch(candidate) ? candidate : runtime;
  }

  static bool supports(String source) => _sourcePattern.hasMatch(source);
  static String storageKey(String source) => 'breeze.source.network.v1.$source';

  /// Inspection only: the export helper must not alter an existing transport.
  static Future<bool> hasBuiltInProxy(String source) async =>
      (await read(source)).effectiveProxy(_readGlobal()).isNotEmpty;

  static Future<SourceNetworkPreference> read(String source) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(storageKey(source)) ??
        (source == 'ccc2fe17-c0a8-4fd8-a596-835772686404'
            ? prefs.getString('breeze.omo.network.v1')
            : null);
    if (raw == null) return const SourceNetworkPreference();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SourceNetworkPreference(
        mode: SourceNetworkMode.values.byName(json['mode'] as String),
        address: json['address'] as String? ?? '',
        socks: json['socks'] == true,
      );
    } catch (_) {
      // Invalid stored explicit configuration must not silently become direct.
      throw const FormatException('Invalid saved network preference');
    }
  }

  static Future<void> save(String source, SourceNetworkPreference value) async {
    if (!supports(source)) throw const FormatException('Invalid source');
    if (value.mode == SourceNetworkMode.proxy) {
      SourceNetworkPreference.proxyUrl(value.address, value.socks);
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey(source),
      jsonEncode({
        'mode': value.mode.name,
        'address': value.address.trim(),
        'socks': value.socks,
      }),
    )) {
      throw StateError('Preference was not saved');
    }
    _changes.add(source);
  }

  static Future<SourceNetworkSnapshot> _snapshot(String source) async {
    final preference = await read(source);
    var global = _readGlobal();
    final debugProxy = _developmentProxy;
    if (!global.enabled && debugProxy != null) {
      global = ProxySettingState(enabled: true, address: debugProxy);
    }
    return SourceNetworkSnapshot(
      source: source,
      proxy: preference.effectiveProxy(global),
    );
  }

  static Future<SourceNetworkSnapshot> resolve(String source) async {
    source = canonicalSource(source);
    final pending = _opening[source];
    if (pending != null) return (await pending).snapshot;
    return _visits[source]?.snapshot ?? await _snapshot(source);
  }

  static Future<SourceNetworkLease> acquire(String source) async {
    source = canonicalSource(source);
    if (!supports(source)) throw const FormatException('Invalid source');
    var visit = _visits[source];
    if (visit == null) {
      final opening = _opening[source] ??= _snapshot(
        source,
      ).then(_SourceVisit.new);
      try {
        visit = await opening;
        _visits[source] = visit;
      } finally {
        if (identical(_opening[source], opening)) _opening.remove(source);
      }
    }
    visit.owners++;
    return SourceNetworkLease._(visit);
  }
}
