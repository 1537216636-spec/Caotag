import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:openhaystack_mobile/accessory/accessory_model.dart';

class AccessoryTrackPage extends StatefulWidget {
  final Accessory accessory;
  const AccessoryTrackPage({Key? key, required this.accessory}) : super(key: key);

  @override
  State<AccessoryTrackPage> createState() => _AccessoryTrackPageState();
}

class _AccessoryTrackPageState extends State<AccessoryTrackPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Pair<LatLng, DateTime>> _filteredHistory = [];
  LatLngBounds? _bounds;
  final MapController _mapController = MapController();
  bool _showMarkers = true;
  bool _showArrows = true;

  @override
  void initState() {
    super.initState();
    final history = widget.accessory.locationHistory;
    if (history.isNotEmpty) {
      history.sort((a, b) => a.b.compareTo(b.b));
      _startDate = history.first.b;
      _endDate = history.last.b;
    }
    _applyFilter();
  }

  void _applyFilter() {
    if (_startDate == null) {
      _filteredHistory = [];
      setState(() {});
      return;
    }
    final start = _startDate!;
    final end = _endDate ?? DateTime.now().add(const Duration(days: 1));
    _filteredHistory = widget.accessory.locationHistory
        .where((e) => !e.b.isBefore(start) && e.b.isBefore(end))
        .toList();
    _filteredHistory.sort((a, b) => a.b.compareTo(b.b));
    if (_filteredHistory.isNotEmpty) {
      _bounds = LatLngBounds.fromPoints(_filteredHistory.map((e) => e.a).toList());
    } else {
      _bounds = null;
    }
    setState(() {});
  }

  Future<void> _pickDateRange() async {
    DateTime? selectedStart = _startDate;
    DateTime? selectedEnd = _endDate;

    final picked = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (ctx) => _DateRangePickerDialog(
        initialStart: selectedStart,
        initialEnd: selectedEnd,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked['start'];
        _endDate = picked['end'];
      });
      _applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = widget.accessory.locationHistory;

    if (history.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.accessory.name} 轨迹')),
        body: const Center(child: Text('暂无轨迹数据')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.accessory.name} 轨迹'),
        actions: [
          IconButton(
            icon: Icon(_showMarkers ? Icons.place : Icons.place_outlined),
            onPressed: () => setState(() => _showMarkers = !_showMarkers),
            tooltip: '标记点',
          ),
          IconButton(
            icon: Icon(_showArrows ? Icons.arrow_forward : Icons.arrow_forward_outlined),
            onPressed: () => setState(() => _showArrows = !_showArrows),
            tooltip: '方向箭头',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.date_range, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _startDate != null
                          ? (_endDate != null
                          ? '${DateFormat('MM/dd').format(_startDate!)}  -  ${DateFormat('MM/dd').format(_endDate!)}'
                          : '${DateFormat('MM/dd').format(_startDate!)}  -  至今')
                          : '选择时间区间',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _filteredHistory.isNotEmpty
                    ? _filteredHistory.first.a
                    : const LatLng(0, 0),
                initialZoom: 14,
                onMapReady: () {
                  if (_bounds != null) {
                    _mapController.fitCamera(CameraFit.bounds(
                      bounds: _bounds!,
                      padding: const EdgeInsets.all(50),
                    ));
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                  subdomains: ['1', '2', '3', '4'],
                  backgroundColor: const Color(0xFFF5F5F5),
                  maxZoom: 18,
                  minZoom: 3,
                  keepBuffer: 4,
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _filteredHistory.map((e) => e.a).toList(),
                      strokeWidth: 2.0,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ],
                ),
                if (_showArrows && _filteredHistory.length >= 2)
                  MarkerLayer(
                    markers: _buildArrowMarkers(theme),
                  ),
                if (_showMarkers)
                  MarkerLayer(
                    markers: _filteredHistory.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final e = entry.value;
                      final isLatest = idx == _filteredHistory.length - 1;
                      return Marker(
                        point: e.a,
                        width: isLatest ? 36 : 28,
                        height: isLatest ? 36 : 28,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showDetailPopup(e),
                          child: Center(
                            child: Icon(
                              Icons.circle,
                              size: isLatest ? 18 : 10,
                              color: isLatest
                                  ? Colors.blueAccent
                                  : theme.colorScheme.error.withOpacity(0.8),
                              shadows: isLatest
                                  ? [const Shadow(blurRadius: 8, color: Colors.blue)]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildArrowMarkers(ThemeData theme) {
    final markers = <Marker>[];
    for (int i = 0; i < _filteredHistory.length - 1; i++) {
      final p1 = _filteredHistory[i].a;
      final p2 = _filteredHistory[i + 1].a;
      final mid = LatLng(
        (p1.latitude + p2.latitude) / 2,
        (p1.longitude + p2.longitude) / 2,
      );
      final bearing = _calculateBearing(p1, p2);
      markers.add(
        Marker(
          point: mid,
          width: 24,
          height: 24,
          child: Transform.rotate(
            angle: bearing,
            child: CustomPaint(
              size: const Size(24, 24),
              painter: ArrowPainter(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * math.pi / 180;
    final startLon = start.longitude * math.pi / 180;
    final endLat = end.latitude * math.pi / 180;
    final endLon = end.longitude * math.pi / 180;
    final dLon = endLon - startLon;
    final y = math.sin(dLon) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLon);
    return math.atan2(y, x);
  }

  void _showDetailPopup(Pair<LatLng, DateTime> entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('位置详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('纬度：${entry.a.latitude.toStringAsFixed(6)}'),
            Text('经度：${entry.a.longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            Text('时间：${DateFormat('yyyy-MM-dd HH:mm').format(entry.b)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}

// 自定义箭头绘制器（尖端朝上）
class ArrowPainter extends CustomPainter {
  final Color color;
  ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(size.width / 2, 0);                   // 尖端（上方）
    path.lineTo(size.width * 0.15, size.height * 0.7); // 左下
    path.lineTo(size.width / 2, size.height * 0.45);   // 底部中心（向内凹陷一点）
    path.lineTo(size.width * 0.85, size.height * 0.7); // 右下
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===================== 自定义日期区间选择器 =====================
class _DateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  const _DateRangePickerDialog({Key? key, this.initialStart, this.initialEnd}) : super(key: key);

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  DateTime? _selectedStart;
  DateTime? _selectedEnd;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _selectedStart = widget.initialStart;
    _selectedEnd = widget.initialEnd;
    _displayMonth = DateTime(
      (_selectedStart ?? _selectedEnd ?? DateTime.now()).year,
      (_selectedStart ?? _selectedEnd ?? DateTime.now()).month,
    );
  }

  void _onDateTapped(DateTime date) {
    setState(() {
      if (_selectedStart == null) {
        _selectedStart = date;
      } else if (_selectedEnd == null) {
        if (date.isAtSameMomentAs(_selectedStart!)) {
          _selectedStart = null;
        } else if (date.isAfter(_selectedStart!)) {
          _selectedEnd = date;
        } else {
          _selectedStart = date;
        }
      } else {
        _selectedStart = date;
        _selectedEnd = null;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStart = null;
      _selectedEnd = null;
    });
  }

  void _applySelection() {
    Navigator.of(context).pop({
      'start': _selectedStart,
      'end': _selectedEnd,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('选择时间区间'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
                    });
                  },
                ),
                Text(
                  DateFormat('yyyy年MM月').format(_displayMonth),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: ['一', '二', '三', '四', '五', '六', '日']
                  .map((e) => Expanded(
                child: Center(
                  child: Text(e,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 13)),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            _buildCalendarGrid(theme),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _clearSelection,
                  child: const Text('清除'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applySelection,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    final firstDayOfMonth = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    final leadingBlanks = firstWeekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<Widget> rowWidgets = [];
    for (int r = 0; r < rows; r++) {
      final List<Widget> dayWidgets = [];
      for (int c = 0; c < 7; c++) {
        final cellIndex = r * 7 + c;
        if (cellIndex < leadingBlanks || cellIndex >= leadingBlanks + daysInMonth) {
          dayWidgets.add(const Expanded(child: SizedBox()));
        } else {
          final day = cellIndex - leadingBlanks + 1;
          final date = DateTime(_displayMonth.year, _displayMonth.month, day);
          final isToday = date == today;
          final isStart = _selectedStart != null && date == _selectedStart;
          final isEnd = _selectedEnd != null && date == _selectedEnd;
          final isInRange = _selectedStart != null &&
              _selectedEnd != null &&
              date.isAfter(_selectedStart!) &&
              date.isBefore(_selectedEnd!);

          Color? bgColor;
          if (isStart || isEnd) {
            bgColor = theme.colorScheme.primary;
          } else if (isInRange) {
            bgColor = theme.colorScheme.primary.withOpacity(0.2);
          }

          dayWidgets.add(
            Expanded(
              child: GestureDetector(
                onTap: () => _onDateTapped(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isStart || isEnd
                          ? Colors.white
                          : (isToday ? theme.colorScheme.primary : null),
                      fontWeight: (isToday || isStart || isEnd) ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
      rowWidgets.add(Row(children: dayWidgets));
    }

    return Column(children: rowWidgets);
  }
}