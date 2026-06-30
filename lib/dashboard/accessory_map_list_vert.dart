import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:openhaystack_mobile/accessory/accessory_list.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/map/map.dart';

class AccessoryMapListVertical extends StatefulWidget {
  final AsyncCallback loadLocationUpdates;
  const AccessoryMapListVertical({Key? key, required this.loadLocationUpdates})
      : super(key: key);

  @override
  AccessoryMapListVerticalState createState() =>
      AccessoryMapListVerticalState();   // 公开 State 类名
}

class AccessoryMapListVerticalState extends State<AccessoryMapListVertical>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  AnimationController? _zoomOutController;
  AnimationController? _panController;
  AnimationController? _zoomInController;

  double _panelFraction = 0.33;
  static const double _minPanelFraction = 0.05;
  static const double _maxPanelFraction = 0.33;

  double? _dragStartPanelFraction;
  double? _dragStartY;

  static const double _maxTargetZoom = 17.0;

  // ---------- 地图飞行动画 ----------
  void _flyTo(LatLng point) {
    final currentCenter = _mapController.center;
    final currentZoom = _mapController.zoom;
    if (currentCenter == null) {
      _mapController.move(point, 14);
      return;
    }

    _stopAllAnimations();

    final targetZoom = currentZoom < _maxTargetZoom ? _maxTargetZoom : currentZoom;

    const double earthRadius = 6371000;
    final dLat = (point.latitude - currentCenter.latitude) * math.pi / 180;
    final dLon = (point.longitude - currentCenter.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(currentCenter.latitude * math.pi / 180) *
            math.cos(point.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadius * c;

    double midZoom;
    if (distance > 500000) {
      midZoom = 8.0;
    } else if (distance > 100000) {
      midZoom = 10.0;
    } else if (distance > 10000) {
      midZoom = 12.0;
    } else {
      midZoom = currentZoom;
    }

    int panDuration;
    if (distance > 500000) {
      panDuration = 1500;
    } else if (distance > 100000) {
      panDuration = 1200;
    } else if (distance > 10000) {
      panDuration = 900;
    } else {
      panDuration = 500;
    }

    if (currentZoom > midZoom) {
      _zoomOutController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      _zoomOutController!.addListener(() {
        final t = _zoomOutController!.value;
        final zoom = currentZoom + (midZoom - currentZoom) * Curves.easeInOut.transform(t);
        _mapController.move(currentCenter, zoom);
      });
      _zoomOutController!.forward().then((_) {
        _zoomOutController?.dispose();
        _zoomOutController = null;
        _startPanAnimation(currentCenter, point, midZoom, targetZoom, panDuration);
      });
    } else {
      _startPanAnimation(currentCenter, point, currentZoom, targetZoom, panDuration);
    }
  }

  void _startPanAnimation(LatLng from, LatLng to, double currentZoom, double targetZoom, int duration) {
    _panController = AnimationController(
      duration: Duration(milliseconds: duration),
      vsync: this,
    );
    _panController!.addListener(() {
      final t = Curves.easeOut.transform(_panController!.value);
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lng = from.longitude + (to.longitude - from.longitude) * t;
      _mapController.move(LatLng(lat, lng), currentZoom);
    });
    _panController!.forward().then((_) {
      _panController?.dispose();
      _panController = null;
      _startZoomInAnimation(to, currentZoom, targetZoom);
    });
  }

  void _startZoomInAnimation(LatLng target, double fromZoom, double toZoom) {
    _zoomInController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _zoomInController!.addListener(() {
      final t = Curves.easeOut.transform(_zoomInController!.value);
      final zoom = fromZoom + (toZoom - fromZoom) * t;
      _mapController.move(target, zoom);
    });
    _zoomInController!.forward().then((_) {
      _zoomInController?.dispose();
      _zoomInController = null;
    });
  }

  void _stopAllAnimations() {
    _zoomOutController?.stop(); _zoomOutController?.dispose(); _zoomOutController = null;
    _panController?.stop(); _panController?.dispose(); _panController = null;
    _zoomInController?.stop(); _zoomInController?.dispose(); _zoomInController = null;
  }

  // ---------- 新增：自动聚焦第一个配件 ----------
  void focusOnFirstAccessory() {
    final registry = context.read<AccessoryRegistry>();
    if (registry.accessories.isEmpty) return;
    final first = registry.accessories.first;
    if (first.lastLocation != null) {
      _mapController.move(first.lastLocation!, 15);
    }
  }

  // ---------- 面板拖拽 ----------
  void _onPointerDown(PointerDownEvent event) {
    _dragStartPanelFraction = _panelFraction;
    _dragStartY = event.position.dy;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragStartPanelFraction == null || _dragStartY == null) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final totalDeltaY = event.position.dy - _dragStartY!;
    final fractionChange = -totalDeltaY / screenHeight;
    final newFraction = (_dragStartPanelFraction! + fractionChange)
        .clamp(_minPanelFraction, _maxPanelFraction);
    setState(() {
      _panelFraction = newFraction;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_panelFraction > 0.2) {
      _panelFraction = _maxPanelFraction;
    } else {
      _panelFraction = _minPanelFraction;
    }
    setState(() {});
    _dragStartPanelFraction = null;
    _dragStartY = null;
  }

  @override
  void dispose() {
    _stopAllAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessoryRegistry, LocationModel>(
      builder: (context, accessoryRegistry, locationModel, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        final panelHeight = screenHeight * _panelFraction;

        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: screenHeight * _minPanelFraction,
              child: AccessoryMap(mapController: _mapController),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: panelHeight,
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A).withOpacity(0.85),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 10, bottom: 6),
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            if (_panelFraction > 0.15)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('我的配件',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text('${accessoryRegistry.accessories.length} 个设备',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                                  ],
                                ),
                              )
                            else
                              const SizedBox(height: 4),
                            if (_panelFraction > 0.2)
                              Expanded(
                                child: AccessoryList(
                                  loadLocationUpdates: widget.loadLocationUpdates,
                                  centerOnPoint: _flyTo,
                                ),
                              )
                            else
                              const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}