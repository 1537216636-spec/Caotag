import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

class BleNavigator extends StatefulWidget {
  final String targetMac;
  final String deviceName;
  const BleNavigator({Key? key, required this.targetMac, required this.deviceName}) : super(key: key);

  @override
  State<BleNavigator> createState() => _BleNavigatorState();
}

class _BleNavigatorState extends State<BleNavigator> with TickerProviderStateMixin {
  StreamSubscription? _scanSubscription;
  StreamSubscription? _magnetometerSubscription;
  StreamSubscription? _connectionStateSub;

  int? _rssi;
  double _distance = 0.0;
  bool _isDeviceFound = false;

  double _currentHeading = 0.0;
  double? _targetHeading;
  final Map<double, int> _headingRssiMap = {};

  static const int _txPower = -59;
  static const double _nFactor = 2.0;

  BluetoothDevice? _targetDevice;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isClosing = false;
  Timer? _closeTimer;
  Timer? _reconnectTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startMagnetometer();
    _startScanning();
  }

  void _startMagnetometer() {
    _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
      double heading = atan2(event.y, event.x) * 180 / pi;
      if (heading < 0) heading += 360;
      setState(() => _currentHeading = heading);
    });
  }

  Future<void> _startScanning() async {
    if (await FlutterBluePlus.isAvailable == false) {
      setState(() => _isDeviceFound = false);
      return;
    }
    await FlutterBluePlus.stopScan();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.remoteId.str.toUpperCase() == widget.targetMac.toUpperCase()) {
          setState(() {
            _isDeviceFound = true;
            _rssi = r.rssi;
            _distance = _calculateDistance(r.rssi);
            _headingRssiMap[_currentHeading] = r.rssi;
            int maxRssi = -999;
            double bestHeading = 0;
            _headingRssiMap.forEach((h, rssi) {
              if (rssi > maxRssi) {
                maxRssi = rssi;
                bestHeading = h;
              }
            });
            _targetHeading = bestHeading;
            _targetDevice = r.device;
          });
        }
      }
    });
    await FlutterBluePlus.startScan(androidScanMode: AndroidScanMode.lowLatency);
  }

  Future<void> _connect() async {
    if (_isConnecting || _isConnected || _isClosing) return;
    if (_targetDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未扫描到设备，无法连接')),
      );
      return;
    }
    setState(() => _isConnecting = true);
    await FlutterBluePlus.stopScan();

    _connectionStateSub = _targetDevice!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
      } else if (state == BluetoothConnectionState.disconnected) {
        setState(() => _isConnected = false);
        if (!_isClosing) {
          _scheduleReconnect();
        } else {
          _isClosing = false;
          _closeTimer?.cancel();
          _startScanning();
        }
      }
    });

    try {
      await _targetDevice!.connect(autoConnect: false);
    } catch (e) {
      print("连接失败: $e");
      setState(() => _isConnecting = false);
      _startScanning();
    }
  }

  void _startCloseProcess() {
    if (!_isConnected || _isClosing) return;
    setState(() => _isClosing = true);
    _closeTimer = Timer(const Duration(seconds: 10), () {
      _performDisconnect();
    });
  }

  Future<void> _performDisconnect() async {
    _closeTimer?.cancel();
    _reconnectTimer?.cancel();
    _connectionStateSub?.cancel();

    if (_targetDevice != null) {
      try {
        await _targetDevice!.disconnect();
      } catch (e) {
        print("断开失败: $e");
      }
    }

    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _isClosing = false;
    });
    _startScanning();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_isConnected && !_isClosing) {
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (!_isConnected && !_isClosing) {
          _connect();
        }
      });
    }
  }

  double _calculateDistance(int rssi) {
    if (rssi == null) return 0;
    double ratio = (_txPower - rssi) / (10 * _nFactor);
    return pow(10, ratio).toDouble();
  }

  String _getProximityHint() {
    if (_rssi == null) return '未检测到信号';
    if (_rssi! > -50) return '非常近 (< 1米)';
    if (_rssi! > -70) return '很近 (1-3米)';
    if (_rssi! > -80) return '中等距离 (3-10米)';
    return '较远 (> 10米)';
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_isConnected) _performDisconnect();
    _pulseController.dispose();
    _scanSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double delta = 0;
    if (_targetHeading != null) {
      delta = (_targetHeading! - _currentHeading) % 360;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
    }

    final bool showPlayButton = !_isConnected && !_isClosing && !_isConnecting;
    final bool showConnectingButton = _isConnecting;
    final bool showStopButton = _isConnected && !_isClosing;
    final bool showClosingButton = _isClosing;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.deviceName + ' 导航'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary.withOpacity(0.85), theme.colorScheme.primary.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Expanded(
            flex: 4,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(320, 320),
                    painter: CompassPainter(
                      heading: _currentHeading,
                      targetDelta: delta,
                      rssi: _rssi,
                      isFound: _isDeviceFound,
                      pulseValue: _pulseAnimation.value,
                      theme: theme,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.75),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDataItem('信号强度', '${_rssi ?? '--'} dBm', Icons.signal_cellular_alt_rounded),
                    _buildDataItem('估计距离', '${_distance.toStringAsFixed(1)} m', Icons.straighten_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isDeviceFound) ...[
                  Chip(
                    avatar: Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
                    label: Text(_getProximityHint(), style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRoundButton(
                        icon: Icons.refresh_rounded,
                        label: '重新扫描',
                        onPressed: () {
                          _headingRssiMap.clear();
                          setState(() => _targetHeading = null);
                          _startScanning();
                        },
                        color: theme.colorScheme.secondaryContainer,
                        foreground: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 16),
                      if (showPlayButton)
                        _buildRoundButton(
                          icon: Icons.volume_up_rounded,
                          label: '播放',
                          onPressed: _connect,
                          color: Colors.green.shade400,
                          foreground: Colors.white,
                        ),
                      if (showConnectingButton)
                        _buildRoundButton(
                          icon: Icons.bluetooth_searching,
                          label: '连接中…',
                          onPressed: null,
                          color: Colors.orange.shade300,
                          foreground: Colors.white,
                        ),
                      if (showStopButton)
                        _buildRoundButton(
                          icon: Icons.volume_off_rounded,
                          label: '停止播放',
                          onPressed: _startCloseProcess,
                          color: Colors.redAccent,
                          foreground: Colors.white,
                        ),
                      if (showClosingButton)
                        _buildRoundButton(
                          icon: Icons.hourglass_empty_rounded,
                          label: '关闭中...',
                          onPressed: null,
                          color: Colors.grey.shade400,
                          foreground: Colors.white,
                        ),
                    ],
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('正在搜索设备...', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.3)),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    required Color color,
    required Color foreground,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;
  final double targetDelta;
  final int? rssi;
  final bool isFound;
  final double pulseValue;
  final ThemeData theme;

  CompassPainter({
    required this.heading,
    required this.targetDelta,
    required this.rssi,
    required this.isFound,
    required this.pulseValue,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 24;

    // 背景渐变
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.colorScheme.primary.withOpacity(0.15),
          theme.colorScheme.surface.withOpacity(0.6),
          theme.colorScheme.surface,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 外圈
    final outerRingPaint = Paint()
      ..color = theme.colorScheme.onSurface.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, outerRingPaint);
    canvas.drawCircle(center, radius - 2, outerRingPaint..strokeWidth = 0.5);

    // 刻度
    for (int i = 0; i < 360; i += 5) {
      final rad = (i - 90) * pi / 180;
      final isPrimary = i % 90 == 0;
      final isSecondary = i % 30 == 0;
      final outerX = center.dx + (radius - 6) * cos(rad);
      final outerY = center.dy + (radius - 6) * sin(rad);
      double innerLen = isPrimary ? 16 : (isSecondary ? 12 : 8);
      final innerX = center.dx + (radius - innerLen) * cos(rad);
      final innerY = center.dy + (radius - innerLen) * sin(rad);
      final tickPaint = Paint()
        ..color = isPrimary
            ? theme.colorScheme.onSurface.withOpacity(0.6)
            : theme.colorScheme.onSurface.withOpacity(0.25)
        ..strokeWidth = isPrimary ? 1.5 : 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tickPaint);
    }

    // 方向字母
    for (int i = 0; i < 4; i++) {
      double rad = (i * 90 - 90) * pi / 180;
      double textX = center.dx + (radius - 36) * cos(rad);
      double textY = center.dy + (radius - 36) * sin(rad);
      final tp = TextPainter(
        text: TextSpan(
          text: ['N', 'E', 'S', 'W'][i],
          style: TextStyle(
            color: i == 0 ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(textX - tp.width / 2, textY - tp.height / 2));
    }

    // 大箭头（长度70）
    final arrowPaint = Paint()
      ..shader = SweepGradient(
        colors: [theme.colorScheme.primary.withOpacity(0.9), theme.colorScheme.primary.withOpacity(0.4)],
        startAngle: 0,
        endAngle: pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    final arrowRad = (targetDelta - 90) * pi / 180;
    final arrowLength = 70.0;
    Path arrowPath = Path()
      ..moveTo(center.dx + arrowLength * cos(arrowRad), center.dy + arrowLength * sin(arrowRad))
      ..lineTo(center.dx + 18 * cos(arrowRad + 2.5), center.dy + 18 * sin(arrowRad + 2.5))
      ..lineTo(center.dx + 18 * cos(arrowRad - 2.5), center.dy + 18 * sin(arrowRad - 2.5))
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
    canvas.drawPath(arrowPath, Paint()..color = Colors.white.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 小箭头（长度22）
    final smallArrowPaint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    final smallArrowLength = 22.0;
    Path smallPath = Path()
      ..moveTo(center.dx + smallArrowLength * cos(arrowRad), center.dy + smallArrowLength * sin(arrowRad))
      ..lineTo(center.dx + 8 * cos(arrowRad + 2.2), center.dy + 8 * sin(arrowRad + 2.2))
      ..lineTo(center.dx + 8 * cos(arrowRad - 2.2), center.dy + 8 * sin(arrowRad - 2.2))
      ..close();
    canvas.drawPath(smallPath, smallArrowPaint);

    // 脉冲圆点
    final pulseRadius = 6.0 + (pulseValue - 1.0) * 4;
    final pulsePaint = Paint()
      ..color = (isFound ? Colors.greenAccent : Colors.grey).withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pulseRadius, pulsePaint);
    canvas.drawCircle(center, pulseRadius + 3, pulsePaint..color = pulsePaint.color.withOpacity(0.3));

    // 信号数值（背景圆 + 数字）
    if (isFound && rssi != null) {
      const double bgRadius = 38;
      final bgPaint = Paint()
        ..color = theme.colorScheme.surface.withOpacity(0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, bgRadius, bgPaint);
      canvas.drawCircle(center, bgRadius, Paint()..color = theme.colorScheme.primary.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1.5);

      final rssiText = '$rssi';
      final rssiPainter = TextPainter(
        text: TextSpan(
          text: rssiText,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      rssiPainter.paint(canvas, Offset(center.dx - rssiPainter.width / 2, center.dy - rssiPainter.height / 2 - 6));

      final unitPainter = TextPainter(
        text: TextSpan(
          text: 'dBm',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      unitPainter.paint(canvas, Offset(center.dx - unitPainter.width / 2, center.dy + rssiPainter.height / 2));
    } else {
      final noSignalPainter = TextPainter(
        text: TextSpan(
          text: '--',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 24),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      noSignalPainter.paint(canvas, Offset(center.dx - noSignalPainter.width / 2, center.dy - noSignalPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) => true;
}