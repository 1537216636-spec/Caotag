import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({Key? key}) : super(key: key);

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      final code = barcode.rawValue!;
      // 扫描到内容，停止扫描并弹出对话框
      controller.stop();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('扫描结果'),
          content: SelectableText(code),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // 可选择继续扫描
                controller.start();
              },
              child: const Text('继续扫描'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // 返回上一页
              },
              child: const Text('完成'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描二维码')),
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