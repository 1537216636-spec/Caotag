import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:openhaystack_mobile/item_management/item_creation.dart';
import 'package:openhaystack_mobile/item_management/item_file_import.dart';
import 'package:openhaystack_mobile/item_management/qr_scan_page.dart';  // 新增

class NewKeyAction extends StatelessWidget {
  final bool mini;
  const NewKeyAction({Key? key, this.mini = false}) : super(key: key);

  void showCreationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('从 JSON 文件导入'),
                leading: const Icon(Icons.description),
                onTap: () async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    allowMultiple: false,
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                    dialogTitle: '选择配件配置文件',
                  );
                  if (result != null && result.paths.isNotEmpty) {
                    String? filePath = result.paths[0];
                    if (filePath != null) {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (context) => ItemFileImport(filePath: filePath),
                      ));
                    }
                  }
                },
              ),
              ListTile(
                title: const Text('创建新配件'),
                leading: const Icon(Icons.add_box),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AccessoryGeneration()),
                  );
                },
              ),
              ListTile(
                title: const Text('扫描二维码'),
                leading: const Icon(Icons.qr_code_scanner),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScanPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: mini,
      onPressed: () => showCreationSheet(context),
      tooltip: '创建',
      child: const Icon(Icons.add),
    );
  }
}