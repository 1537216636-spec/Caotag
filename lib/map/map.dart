import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/navigation/ble_navigator.dart';

class AccessoryMap extends StatefulWidget {
  final MapController? mapController;
  const AccessoryMap({Key? key, this.mapController}) : super(key: key);

  @override
  _AccessoryMapState createState() => _AccessoryMapState();
}

class _AccessoryMapState extends State<AccessoryMap> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
  }

  /// 供外部调用：将地图视角移动到第一个配件的位置
  void focusOnFirstAccessory() {
    final registry = context.read<AccessoryRegistry>();
    if (registry.accessories.isEmpty) return;
    final first = registry.accessories.first;
    if (first.lastLocation != null) {
      _mapController.move(first.lastLocation!, 15); // 15 是合适的缩放级别
    }
  }

  void _showAccessoryPopup(BuildContext context, Accessory accessory) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            AccessoryIcon(icon: accessory.icon, color: accessory.color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                accessory.name,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (accessory.datePublished != null)
              Text(
                '最后更新: ${accessory.datePublished!.toString().substring(0, 16)}',
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPopupButton(
                  icon: Icons.directions,
                  label: '导航',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (accessory.lastLocation != null) {
                      final lat = accessory.lastLocation!.latitude;
                      final lon = accessory.lastLocation!.longitude;
                      final url =
                          'https://uri.amap.com/marker?position=$lon,$lat&name=${Uri.encodeComponent(accessory.name)}';
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _buildPopupButton(
                  icon: Icons.bluetooth_searching,
                  label: '搜索',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (accessory.macAddress.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BleNavigator(
                            targetMac: accessory.macAddress,
                            deviceName: accessory.name,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('该配件未设置蓝牙MAC地址')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessoryRegistry = context.watch<AccessoryRegistry>();
    final locationModel = context.watch<LocationModel>();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: locationModel.here ?? const LatLng(49.874739, 8.656280),
        zoom: 13.0,
        maxZoom: 18.0,
        interactiveFlags: InteractiveFlag.pinchZoom |
        InteractiveFlag.drag |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.flingAnimation |
        InteractiveFlag.pinchMove,
      ),
      children: [
        TileLayer(
          backgroundColor: const Color(0xFFF5F5F5),
          urlTemplate:
          'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
          subdomains: ['1', '2', '3', '4'],
          maxZoom: 18,
          minZoom: 3,
          keepBuffer: 4,
        ),
        MarkerLayer(
          markers: [
            ...accessoryRegistry.accessories
                .where((a) => a.lastLocation != null)
                .map((a) => Marker(
              rotate: true,
              width: 50,
              height: 50,
              point: a.lastLocation!,
              child: GestureDetector(
                onTap: () => _showAccessoryPopup(context, a),
                child: AccessoryIcon(icon: a.icon, color: a.color),
              ),
            ))
                .toList(),
          ],
        ),
        MarkerLayer(
          markers: [
            if (locationModel.here != null)
              Marker(
                width: 25,
                height: 25,
                point: locationModel.here!,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}