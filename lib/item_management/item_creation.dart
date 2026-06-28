import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/findMy/find_my_controller.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon_selector.dart';
import 'package:openhaystack_mobile/accessory/accessory_color_selector.dart';

class AccessoryGeneration extends StatefulWidget {
  const AccessoryGeneration({Key? key}) : super(key: key);

  @override
  State<AccessoryGeneration> createState() => _AccessoryGenerationState();
}

class _AccessoryGenerationState extends State<AccessoryGeneration> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _hashedPublicKey = '';
  String _privateKey = '';
  bool _isDeployed = false;
  bool _isActive = true;
  String _icon = 'mappin';
  Color _color = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建新配件')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: '配件名称',
                hintText: '输入名称...',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入名称' : null,
              onChanged: (v) => _name = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Hashed Public Key（可选）',
                hintText: '若留空，将用私钥自动计算',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _hashedPublicKey = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '私钥 (Private Key)',
                hintText: '用于解密位置报告',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? '请输入私钥' : null,
              onChanged: (v) => _privateKey = v,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('图标与颜色', style: TextStyle(fontSize: 16)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final icon = await AccessoryIconSelector.showIconSelection(context, _icon, _color);
                    if (icon != null) {
                      setState(() => _icon = icon);
                      final color = await AccessoryColorSelector.showColorSelection(context, _color);
                      if (color != null) setState(() => _color = color);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('选择'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('已部署'),
              value: _isDeployed,
              onChanged: (v) => setState(() => _isDeployed = v),
            ),
            SwitchListTile(
              title: const Text('已激活（显示在地图）'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('保存配件'),
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                _formKey.currentState!.save();

                final registry = context.read<AccessoryRegistry>();
                String hashed = _hashedPublicKey.trim();
                if (_privateKey.isNotEmpty) {
                  try {
                    final kp = await FindMyController.importKeyPair(_privateKey);
                    if (hashed.isEmpty) hashed = kp.hashedPublicKey;
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('私钥无效，请检查')),
                    );
                    return;
                  }
                }
                if (hashed.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请提供 Hashed Public Key 或有效的私钥')),
                  );
                  return;
                }

                final accessory = Accessory(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _name.trim(),
                  hashedPublicKey: hashed,
                  datePublished: null,
                  icon: _icon,
                  color: _color,
                  isActive: _isActive,
                  isDeployed: _isDeployed,
                  usesDerivation: false,
                  additionalKeys: [],
                  queryKeys: [],
                );

                registry.addAccessory(accessory);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('配件创建成功')),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}