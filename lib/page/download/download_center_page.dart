import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:zephyr/page/donwload_task/view/download_task.dart';

/// The same Downloads center when it is not pinned in main navigation.
@RoutePage()
class DownloadCenterPage extends StatelessWidget {
  const DownloadCenterPage({super.key});

  @override
  Widget build(BuildContext context) => const DownloadTaskPage();
}
