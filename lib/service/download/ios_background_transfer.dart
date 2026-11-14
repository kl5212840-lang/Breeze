import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class IosBackgroundStage {
  IosBackgroundStage._(this.path, this._token);

  final String path;
  final String _token;

  Future<void> release() async {
    await IosBackgroundTransfer.channel.invokeMethod<void>(
      'releaseStage',
      _token,
    );
  }
}

abstract final class IosBackgroundTransfer {
  static const channel = MethodChannel('breeze.download.files');
  static final _changes = StreamController<void>.broadcast();
  static bool _listening = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Stream<void> get changes {
    if (!_listening) {
      _listening = true;
      channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') _changes.add(null);
      });
    }
    return _changes.stream;
  }

  static Future<bool> submit(
    Map<String, dynamic> binding,
    List<Map<String, dynamic>> items, {
    required int concurrency,
  }) async =>
      await channel.invokeMethod<bool>('submit', {
        ...binding,
        'items': items,
        'concurrency': concurrency,
      }) ==
      true;

  static Future<List<Map<String, dynamic>>> snapshot() async =>
      (await channel.invokeListMethod<Object?>('snapshot') ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  static Future<IosBackgroundStage?> holdStage(
    Map<String, dynamic> binding,
    int index,
  ) async {
    final row = await channel.invokeMapMethod<String, String>('holdStage', {
      ...binding,
      'index': index,
    });
    final path = row?['path'], token = row?['lease'];
    return path == null || token == null
        ? null
        : IosBackgroundStage._(path, token);
  }

  static Future<String?> linkVideoStage(Map<String, dynamic> binding) =>
      channel.invokeMethod<String>('linkVideoStage', binding);

  static Future<bool> cancel(Map<String, dynamic> binding) async =>
      await channel.invokeMethod<bool>('cancel', binding) == true;

  static Future<bool> ack(Map<String, dynamic> binding) async =>
      await channel.invokeMethod<bool>('ack', binding) == true;
}
