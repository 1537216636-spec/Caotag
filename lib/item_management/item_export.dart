import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:openhaystack_mobile/accessory/accessory_dto.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';

class ItemExportMenu extends StatelessWidget {
  Accessory accessory;
  ItemExportMenu({Key? key, required this.accessory}) : super(key: key);

  void showKeyExportSheet(BuildContext context, Accessory accessory) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              ListTile(
                trailing: IconButton(
                  onPressed: () => _showKeyExplanationAlert(context),
                  icon: const Icon(Icons.info),
                ),
              ),
              ListTile(
                title: const Text('导出全部配件 (JSON)'),
                onTap: () async {
                  var accessories = Provider.of<AccessoryRegistry>(context, listen: false).accessories;
                  await _exportAccessoriesAsJSON(accessories);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('导出当前配件 (JSON)'),
                onTap: () async {
                  await _exportAccessoriesAsJSON([accessory]);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('导出哈希广告密钥 (Base64)'),
                onTap: () async {
                  var key = await accessory.getHashedAdvertisementKey();
                  Share.share(key);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('导出广告密钥 (Base64)'),
                onTap: () async {
                  var key = await accessory.getAdvertisementKey();
                  Share.share(key);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('导出私钥 (Base64)'),
                onTap: () async {
                  var key = await accessory.getPrivateKey();
                  Share.share(key);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAccessoriesAsJSON(List<Accessory> accessories) async {
    Directory tempDir = await getTemporaryDirectory();
    String path = tempDir.path;
    List<AccessoryDTO> exportAccessories = [];
    for (var acc in accessories) {
      String privateKey = await acc.getPrivateKey();
      exportAccessories.add(AccessoryDTO(
        id: int.tryParse(acc.id) ?? 0,
        colorComponents: [
          acc.color.red / 255,
          acc.color.green / 255,
          acc.color.blue / 255,
          acc.color.opacity,
        ],
        name: acc.name,
        lastDerivationTimestamp: acc.lastDerivationTimestamp,
        symmetricKey: acc.symmetricKey,
        updateInterval: acc.updateInterval,
        privateKey: privateKey,
        icon: acc.rawIcon,
        isDeployed: acc.isDeployed,
        colorSpaceName: 'kCGColorSpaceSRGB',
        usesDerivation: acc.usesDerivation,
        oldestRelevantSymmetricKey: acc.oldestRelevantSymmetricKey,
        isActive: acc.isActive,
      ));
    }
    const filename = 'accessories.json';
    File file = File('$path/$filename');
    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    String encodedAccessories = encoder.convert(exportAccessories);
    await file.writeAsString(encodedAccessories);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  Future<void> _showKeyExplanationAlert(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('密钥说明'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('私钥：', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('用于解密位置报告的密钥，请妥善保管。'),
                Text('广告密钥：', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('通过蓝牙广播的短公钥。'),
                Text('哈希广告密钥：', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('用于从服务器获取位置报告。'),
                Text('配件文件：', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('包含该配件的所有信息。'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('关闭'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showKeyExportSheet(context, accessory),
      icon: const Icon(Icons.open_in_new),
    );
  }
}