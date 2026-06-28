import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/accessory/accessory_color_selector.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon_selector.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/item_management/accessory_name_input.dart';

class AccessoryDetail extends StatefulWidget {
  Accessory accessory;
  AccessoryDetail({Key? key, required this.accessory}) : super(key: key);

  @override
  _AccessoryDetailState createState() => _AccessoryDetailState();
}

class _AccessoryDetailState extends State<AccessoryDetail> {
  late Accessory newAccessory;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _macController;

  @override
  void initState() {
    newAccessory = widget.accessory.clone();
    _macController = TextEditingController(text: newAccessory.macAddress);
    super.initState();
  }

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.accessory.name)),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: AccessoryIcon(
                        size: 100,
                        icon: newAccessory.icon,
                        color: newAccessory.color,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 200, 200, 200),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () async {
                              String? selectedIcon = await AccessoryIconSelector.showIconSelection(
                                  context, newAccessory.rawIcon, newAccessory.color);
                              if (selectedIcon != null) {
                                setState(() {
                                  newAccessory.setIcon(selectedIcon);
                                });
                                Color? selectedColor = await AccessoryColorSelector.showColorSelection(
                                    context, newAccessory.color);
                                if (selectedColor != null) {
                                  setState(() {
                                    newAccessory.color = selectedColor;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.edit),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AccessoryNameInput(
                initialValue: newAccessory.name,
                onChanged: (value) {
                  setState(() {
                    newAccessory.name = value;
                  });
                },
              ),
              // MAC 地址输入
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextFormField(
                  controller: _macController,
                  decoration: const InputDecoration(
                    labelText: '蓝牙 MAC 地址 (格式: AA:BB:CC:DD:EE:FF)',
                    hintText: '留空则不启用信号导航',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    newAccessory.macAddress = value.trim();
                  },
                ),
              ),
              SwitchListTile(
                value: newAccessory.isActive,
                title: const Text('已激活'),
                onChanged: (checked) {
                  setState(() {
                    newAccessory.isActive = checked;
                  });
                },
              ),
              SwitchListTile(
                value: newAccessory.isDeployed,
                title: const Text('已部署'),
                onChanged: (checked) {
                  setState(() {
                    newAccessory.isDeployed = checked;
                  });
                },
              ),
              ListTile(
                title: OutlinedButton(
                  child: const Text('保存'),
                  onPressed: _formKey.currentState == null || !_formKey.currentState!.validate()
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      var accessoryRegistry = Provider.of<AccessoryRegistry>(context, listen: false);
                      accessoryRegistry.editAccessory(widget.accessory, newAccessory);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('更改已保存！')),
                      );
                    }
                  },
                ),
              ),
              ListTile(
                title: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                        return Theme.of(context).colorScheme.error;
                      },
                    ),
                  ),
                  child: const Text('删除配件', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    var accessoryRegistry = Provider.of<AccessoryRegistry>(context, listen: false);
                    accessoryRegistry.removeAccessory(widget.accessory);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}