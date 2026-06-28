import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/accessory/accessory_dto.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/findMy/find_my_controller.dart';
import 'package:openhaystack_mobile/item_management/loading_spinner.dart';

class ItemFileImport extends StatefulWidget {
  final String filePath;
  const ItemFileImport({Key? key, required this.filePath}) : super(key: key);

  @override
  _ItemFileImportState createState() => _ItemFileImportState();
}

class _ItemFileImportState extends State<ItemFileImport> {
  List<AccessoryDTO>? accessories;
  List<bool>? selected;
  List<bool>? expanded;
  bool hasError = false;
  String? errorText;

  // 保存原始 JSON，用于提取 additionalKeys 等
  List<Map<String, dynamic>>? _rawJsons;

  @override
  void initState() {
    super.initState();
    _initStateAsync(widget.filePath);
  }

  void _initStateAsync(String filePath) async {
    final isValidPath = await _validateFilePath(filePath);
    if (!isValidPath) {
      setState(() {
        hasError = true;
        errorText = 'Invalid file path.';
      });
      return;
    }

    try {
      File file = File(filePath);
      String encodedContent = await file.readAsString();
      dynamic decoded = jsonDecode(encodedContent);

      // 如果是字符串数组，当作全局密钥导入
      if (decoded is List && decoded.isNotEmpty && decoded.first is String) {
        final keys = decoded.cast<String>();
        await Provider.of<AccessoryRegistry>(context, listen: false).addGlobalKeys(keys);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('成功导入全局密钥')),
        );
        Navigator.pop(context);
        return;
      }

      // 否则作为配件导入
      _rawJsons = (decoded as List).map((e) => Map<String, dynamic>.from(e)).toList();
      var accessoryDTOs = _rawJsons!.map((json) => AccessoryDTO.fromJson(json)).toList();

      setState(() {
        accessories = accessoryDTOs;
        selected = accessoryDTOs.map((_) => true).toList();
        expanded = accessoryDTOs.map((_) => false).toList();
      });
    } catch (e) {
      setState(() {
        hasError = true;
        errorText = 'Could not parse JSON file.';
      });
    }
  }

  Future<bool> _validateFilePath(String filePath) async {
    if (filePath.isEmpty) return false;
    File file = File(filePath);
    return await file.exists();
  }

  Future<void> _importSelectedAccessories() async {
    if (accessories == null || _rawJsons == null) return;
    var registry = Provider.of<AccessoryRegistry>(context, listen: false);

    for (var i = 0; i < accessories!.length; i++) {
      if (selected?[i] ?? false) {
        await _importAccessory(registry, accessories![i], _rawJsons![i]);
      }
    }

    int nrOfImports = selected?.where((e) => e).length ?? 0;
    if (nrOfImports > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 $nrOfImports 个配件')),
      );
    }
  }

  Future<void> _importAccessory(
      AccessoryRegistry registry, AccessoryDTO accessoryDTO, Map<String, dynamic> rawJson) async {
    // 颜色
    Color color = Colors.grey;
    if (accessoryDTO.colorSpaceName == 'kCGColorSpaceSRGB' &&
        accessoryDTO.colorComponents.length == 4) {
      var colors = accessoryDTO.colorComponents;
      int red = (colors[0] * 255).round();
      int green = (colors[1] * 255).round();
      int blue = (colors[2] * 255).round();
      double opacity = colors[3];
      color = Color.fromRGBO(red, green, blue, opacity);
    }

    // 图标
    String icon = 'mappin';
    if (AccessoryIconModel.icons.contains(accessoryDTO.icon)) {
      icon = accessoryDTO.icon;
    }

    // 导入主私钥
    var keyPair = await FindMyController.importKeyPair(accessoryDTO.privateKey);

    // ---- 密钥提取 ----
    // 查询密钥：直接使用 additionalKeys（与前端发送一致）
    final List<String> queryKeys = [];
    if (rawJson['additionalKeys'] != null) {
      for (var key in rawJson['additionalKeys']) {
        if (key is String) {
          queryKeys.add(key);
        }
      }
    }

    // 匹配报告的密钥（hashedPublicKey 列表）
    final Set<String> hashedKeySet = {};
    if (keyPair.hashedPublicKey.isNotEmpty) {
      hashedKeySet.add(keyPair.hashedPublicKey);
    }
    if (rawJson['keysMap'] != null) {
      final keysMap = Map<String, dynamic>.from(rawJson['keysMap']);
      for (var value in keysMap.values) {
        if (value is String) {
          hashedKeySet.add(value);
        }
      }
    }
    final List<String> hashedKeys = hashedKeySet.toList();

    // 名称处理
    String accessoryName = accessoryDTO.name;
    if (accessoryName.isEmpty) {
      accessoryName = rawJson['id_short']?.toString() ?? accessoryDTO.id.toString();
    }

    // MAC 地址
    String macAddress = rawJson['macAddress']?.toString() ?? '';

    Accessory newAccessory = Accessory(
      datePublished: DateTime.now(),
      hashedPublicKey: keyPair.hashedPublicKey,
      id: accessoryDTO.id.toString(),
      name: accessoryName,
      color: color,
      icon: icon,
      isActive: accessoryDTO.isActive,
      isDeployed: accessoryDTO.isDeployed,
      lastLocation: null,
      lastDerivationTimestamp: accessoryDTO.lastDerivationTimestamp,
      symmetricKey: accessoryDTO.symmetricKey,
      updateInterval: accessoryDTO.updateInterval,
      usesDerivation: accessoryDTO.usesDerivation,
      oldestRelevantSymmetricKey: accessoryDTO.oldestRelevantSymmetricKey,
      additionalKeys: hashedKeys,   // 用于匹配报告 id
      queryKeys: queryKeys,         // 用于查询
      macAddress: macAddress,       // 新增
    );

    registry.addAccessory(newAccessory);
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return _buildScaffold(Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(errorText ?? 'An unknown error occured.'),
      ));
    }
    if (accessories == null) {
      return _buildScaffold(const LoadingSpinner());
    }
    return _buildScaffold(
      SingleChildScrollView(
        child: ExpansionPanelList(
          expansionCallback: (int index, bool isExpanded) {
            setState(() => expanded?[index] = !isExpanded);
          },
          children: accessories!.asMap().entries.map((entry) {
            int idx = entry.key;
            AccessoryDTO accessory = entry.value;
            return ExpansionPanel(
              headerBuilder: (_, __) => ListTile(
                leading: Checkbox(
                  value: selected?[idx] ?? false,
                  onChanged: (v) => setState(() => selected?[idx] = v ?? false),
                ),
                title: Text(accessory.name),
              ),
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProperty('ID', accessory.id.toString()),
                    _buildProperty('Name', accessory.name),
                    _buildProperty('Active', accessory.isActive.toString()),
                    _buildProperty('Deployed', accessory.isDeployed.toString()),
                  ],
                ),
              ),
              isExpanded: expanded?[idx] ?? false,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProperty(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          text: '$key: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
          children: [TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.normal))],
        ),
      ),
    );
  }

  Widget _buildScaffold(Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入配件'),
        actions: [
          TextButton(
            onPressed: () {
              if (accessories != null) {
                _importSelectedAccessories();
                Navigator.pop(context);
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}