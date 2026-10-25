import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Hierarchy navigation on iOS has one owner: the native-style route. Data
/// refreshes and web-document restoration never push another visual page.
PageRoute<T> videoPageRoute<T>({required WidgetBuilder builder}) =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
    ? CupertinoPageRoute<T>(builder: builder)
    : MaterialPageRoute<T>(builder: builder);
