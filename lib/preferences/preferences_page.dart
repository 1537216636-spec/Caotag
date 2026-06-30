import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/preferences/user_preferences_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<UserPreferences>();
    final locationModel = context.read<LocationModel>();
    final registry = context.read<AccessoryRegistry>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: const Icon(Icons.location_on),
            title: const Text('允许位置访问'),
            subtitle: const Text('开启后，地图会显示您的当前位置'),
            value: prefs.locationAccessWanted ?? false,
            onChanged: (val) async {
              await prefs.setLocationPreference(val);
              if (val) {
                locationModel.requestLocationUpdates();
              } else {
                locationModel.cancelLocationUpdates();
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('小歪在哪里'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '小歪在哪里',
                applicationVersion: '曹工谨制1.0.0',
                children: const [
                  Text('利用 Apple Find My 网络追踪您的设备。'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清除所有数据'),
            subtitle: const Text('删除所有配件及设置'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认清除'),
                  content: const Text('此操作不可撤销，确定要删除所有数据吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('清除'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                // 清除所有配件
                final accessories = registry.accessories.toList();
                for (var a in accessories) {
                  registry.removeAccessory(a);
                }
                // 清除用户偏好
                await prefs.clearAll();
                // 重新加载配件（清空后保存）
                await registry.loadAccessories();
                // 提示成功
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有数据已清除')),
                );
                // 返回首页
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}