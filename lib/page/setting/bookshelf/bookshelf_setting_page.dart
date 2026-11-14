import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/toast.dart';

@RoutePage()
class BookshelfSettingPage extends StatelessWidget {
  const BookshelfSettingPage({super.key});

  @override
  Widget build(BuildContext context) => SettingPageShell(
    grouped: true,
    title: t.settings.bookshelf,
    child: const SettingListView(children: [BookshelfDefaultSectionTile()]),
  );
}

class BookshelfDefaultSectionTile extends StatelessWidget {
  const BookshelfDefaultSectionTile({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<GlobalSettingCubit>();
    final index = cubit.state.bookshelfSetting.homePageIndex == 1 ? 1 : 0;

    return SettingChoiceTile<int>(
      leading: const Icon(Icons.home_outlined),
      title: t.settings.bookshelfHomePage,
      description: t.settings.bookshelfScope,
      value: index,
      items: {0: t.bookshelf.favorite, 1: t.bookshelf.history},
      onChanged: (int value) {
        if (value == index) return;
        cubit.updateBookshelfSetting(
          (current) => current.copyWith(homePageIndex: value),
        );
        showSuccessToast(t.common.settingSaved);
      },
    );
  }
}
