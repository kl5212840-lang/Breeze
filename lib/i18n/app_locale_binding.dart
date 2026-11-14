import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/i18n_helper.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Applies locale changes to the mounted app without replacing its Navigator.
class AppLocaleBinding extends StatefulWidget {
  const AppLocaleBinding({super.key, required this.child});

  final Widget child;

  @override
  State<AppLocaleBinding> createState() => _AppLocaleBindingState();
}

class _AppLocaleBindingState extends State<AppLocaleBinding>
    with WidgetsBindingObserver {
  AppLocale? _locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final settings = context.read<GlobalSettingCubit>();
    if (!settings.state.localeFollowsSystem ||
        locales == null ||
        locales.isEmpty) {
      return;
    }
    final preferred = locales.firstWhere(
      (locale) => I18nHelper.toAppLocale(locale) != null,
      orElse: () => locales.first,
    );
    unawaited(settings.refreshDisplayLocale(systemLocale: preferred));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TranslationProvider.of(context).locale;
    final previous = _locale;
    _locale = next;
    if (previous == null || previous == next) return;

    // Legacy widgets still read the global slang getter during build. Refresh
    // their mounted elements once per locale switch, including retained tabs
    // and covered routes. Wait until the framework unlocks the element tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _locale == next) {
        context.visitChildElements(_refreshTranslations);
      }
    });
  }

  void _refreshTranslations(Element element) {
    if (element is StatelessElement || element is StatefulElement) {
      element.markNeedsBuild();
    }
    element.visitChildElements(_refreshTranslations);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GlobalSettingCubit, GlobalSettingState>(
      listenWhen: (previous, current) =>
          previous.locale != current.locale ||
          previous.localeFollowsSystem != current.localeFollowsSystem,
      listener: (context, _) =>
          unawaited(context.read<GlobalSettingCubit>().refreshDisplayLocale()),
      child: widget.child,
    );
  }
}
