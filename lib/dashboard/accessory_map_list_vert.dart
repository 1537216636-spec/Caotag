import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:openhaystack_mobile/accessory/accessory_list.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/map/map.dart';

class AccessoryMapListVertical extends StatefulWidget {
  final AsyncCallback loadLocationUpdates;

  const AccessoryMapListVertical({
    Key? key,
    required this.loadLocationUpdates,
  }) : super(key: key);

  @override
  State<AccessoryMapListVertical> createState() =>
      _AccessoryMapListVerticalState();
}

class _AccessoryMapListVerticalState extends State<AccessoryMapListVertical> {
  final MapController _mapController = MapController();

  void _centerPoint(LatLng point) {
    final currentZoom = _mapController.zoom;
    if (currentZoom < 15) {
      _mapController.move(point, 15);
    } else {
      _mapController.move(point, currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessoryRegistry, LocationModel>(
      builder: (BuildContext context, AccessoryRegistry accessoryRegistry,
          LocationModel locationModel, Widget? child) {
        return Stack(
          children: [
            Positioned.fill(
              child: AccessoryMap(mapController: _mapController),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.35,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '我的配件',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${accessoryRegistry.accessories.length} 个设备',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: AccessoryList(
                            loadLocationUpdates: widget.loadLocationUpdates,
                            centerOnPoint: _centerPoint,
                          ),
                        ),
                      ],
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