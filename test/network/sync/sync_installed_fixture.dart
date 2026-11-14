import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

/// Seed actual installed packages; config rows alone do not imply installation.
Future<void> installSyncPlugins(Iterable<String> sources) async {
  await LocalPluginInstallationState.instance.reload();
  objectbox.pluginInfoBox.removeAll();
  objectbox.pluginInfoBox.putMany([
    for (final source in sources)
      PluginInfo(
        uuid: source,
        version: 'fixture',
        originScript: 'fixture-script',
        insertedAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
        isEnabled: false,
        isDeleted: false,
        lastLoadSuccess: false,
        debug: false,
      ),
  ]);
}
