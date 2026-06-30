import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openhaystack_mobile/item_management/item_file_import.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({Key? key}) : super(key: key);

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  MobileScannerController controller = MobileScannerController();
  bool _hasHandledScan = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasHandledScan) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!;
    _hasHandledScan = true;

    // 如果是网址，尝试从该网址下载 JSON
    if (code.startsWith('http://') || code.startsWith('https://')) {
      try {
        final response = await http.get(Uri.parse(code));
        if (response.statusCode == 200) {
          final downloaded = response.body;
          final decoded = jsonDecode(downloaded);
          if (decoded is List && decoded.isNotEmpty) {
            _importJsonList(decoded);
            return;
          } else if (decoded is Map) {
            _importJsonList([decoded]);
            return;
          }
        }
      } catch (_) {}
    }

    // 尝试当作 JSON 文本解析
    try {
      final decoded = jsonDecode(code);
      if (decoded is List && decoded.isNotEmpty) {
        _importJsonList(decoded);
        return;
      } else if (decoded is Map) {
        _importJsonList([decoded]);
        return;
      }
    } catch (_) {}

    // 都不是，显示普通文本对话框
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫描结果'),
        content: SelectableText(code),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _hasHandledScan = false;
            },
            child: const Text('重新扫描'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  void _importJsonList(List<dynamic> accessoriesJson) {
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/scan_import.json');
    tempFile.writeAsStringSync(jsonEncode(accessoriesJson));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ItemFileImport(filePath: tempFile.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描二维码导入')),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => controller.toggleTorch(),
                icon: const Icon(Icons.flashlight_on),
                label: const Text('闪光灯'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}