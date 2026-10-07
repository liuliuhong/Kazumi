import 'package:flutter/material.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/platform/tv_service.dart';
import 'package:kazumi/services/update/tv_updater.dart';

class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  bool _autoUpdate = GStorage.getSetting(SettingsKeys.autoUpdate);
  bool _pluginUpdate =
      GStorage.getSetting(SettingsKeys.checkPluginUpdateOnStartup);

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('更新设置'),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('启动时检查更新'),
              tiles: [
                SettingsTile.switchTile(
                  leading: Icons.update_rounded,
                  title: Text(TvService.isTelevision ? '启动时检查 TV 更新' : '应用更新'),
                  initialValue: _autoUpdate,
                  onToggle: (value) {
                    setState(() => _autoUpdate = value ?? !_autoUpdate);
                    GStorage.putSetting(SettingsKeys.autoUpdate, _autoUpdate);
                  },
                ),
                if (TvService.isTelevision)
                  SettingsTile(
                    leading: Icons.system_update_rounded,
                    title: const Text('检查 TV 更新'),
                    description: const Text('更新来源：liuliuhong/Kazumi · 社区 TV 正式版'),
                    onPressed: (_) => TvUpdater.instance.check(automatic: false),
                  ),
                SettingsTile.switchTile(
                  leading: Icons.extension_rounded,
                  title: const Text('规则更新'),
                  initialValue: _pluginUpdate,
                  onToggle: (value) {
                    setState(() => _pluginUpdate = value ?? !_pluginUpdate);
                    GStorage.putSetting(
                      SettingsKeys.checkPluginUpdateOnStartup,
                      _pluginUpdate,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
}
