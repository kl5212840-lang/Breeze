import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/src/rust/api/qjs.dart';

final Map<String, String> _conversionCache = {};

String _cachedConversion(String key, String Function() convert) {
  final cached = _conversionCache[key];
  if (cached != null) return cached;
  final result = convert();
  if (_conversionCache.length >= 2000) _conversionCache.clear();
  _conversionCache[key] = result;
  return result;
}

/// 用来简化调用，将繁体中文转换为简体中文/包括日本汉字
String t2s(String text) {
  try {
    return _cachedConversion('match|$text', () {
      final traditional = openccConvert(text: text, config: 'jp2t.json');
      return openccConvert(text: traditional, config: 'tw2sp.json');
    });
  } catch (e) {
    logger.e(e);
    return text;
  }
}

/// 按全局设置转换漫画文本用于显示;关闭时原样返回。
/// 与 t2s 的区别:t2s 固定转简体(用于搜索/屏蔽词的繁简无关匹配),
/// 本函数受用户「简繁转换」开关控制,仅作用于显示层。
String convertChineseForDisplay(String text) =>
    _convertForDisplay(text, globalSetting.chineseConvertMode);

String Function(String) watchChineseDisplayConverter(BuildContext context) {
  final mode = context.select<GlobalSettingCubit?, ChineseConvertMode?>(
    (cubit) => cubit?.state.chineseConvertMode,
  );
  return mode == null
      ? convertChineseForDisplay
      : (text) => _convertForDisplay(text, mode);
}

String _convertForDisplay(String text, ChineseConvertMode mode) {
  if (mode == ChineseConvertMode.off || text.isEmpty) return text;
  final config = mode.openccConfig;
  return _cachedConversion(
    '${mode.name}|$text',
    () => openccConvert(text: text, config: config),
  );
}
