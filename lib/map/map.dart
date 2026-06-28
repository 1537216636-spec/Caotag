import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/location/location_model.dart';

class AccessoryMap extends StatefulWidget {
  final MapController? mapController;

  const AccessoryMap({
    Key? key,
    this.mapController,
  }) : super(key: key);

  @override
  _AccessoryMapState createState() => _AccessoryMapState();
}

class _AccessoryMapState extends State<AccessoryMap> {
  late MapController _mapController;
  void Function()? cancelLocationUpdates;
  void Function()? cancelAccessoryUpdates;
  bool accessoryInitialized = false;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();

    var accessoryRegistry =
    Provider.of<AccessoryRegistry>(context, listen: false);
    var locationModel = Provider.of<LocationModel>(context, listen: false);

    fitToContent(accessoryRegistry.accessories, locationModel.here);

    void listener() {
      cancelLocationUpdates?.call();
      fitToContent(accessoryRegistry.accessories, locationModel.here);
    }

    locationModel.addListener(listener);
    cancelLocationUpdates = () => locationModel.removeListener(listener);
  }

  @override
  void dispose() {
    super.dispose();
    cancelLocationUpdates?.call();
    cancelAccessoryUpdates?.call();
  }

  void fitToContent(List<Accessory> accessories, LatLng? hereLocation) async {
    await Future.delayed(const Duration(milliseconds: 500));

    List<LatLng> points = [];
    if (hereLocation != null) {
      _mapController.move(hereLocation, _mapController.zoom);
      points = [hereLocation];
    }

    List<LatLng> accessoryPoints = accessories
        .where((accessory) => accessory.lastLocation != null)
        .map((accessory) => accessory.lastLocation!)
        .toList();

    final allPoints = [...points, ...accessoryPoints];
    if (allPoints.isEmpty) return;

    _mapController.fitBounds(
      LatLngBounds.fromPoints(allPoints),
      options: const FitBoundsOptions(
        padding: EdgeInsets.all(25),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessoryRegistry, LocationModel>(
      builder: (BuildContext context, AccessoryRegistry accessoryRegistry,
          LocationModel locationModel, Widget? child) {
        var accessories = accessoryRegistry.accessories;
        if (!accessoryInitialized && accessoryRegistry.initialLoadFinished) {
          fitToContent(accessories, locationModel.here);
          accessoryInitialized = true;
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: locationModel.here ?? LatLng(49.874739, 8.656280),
            zoom: 13.0,
            interactiveFlags: InteractiveFlag.pinchZoom |
            InteractiveFlag.drag |
            InteractiveFlag.doubleTapZoom |
            InteractiveFlag.flingAnimation |
            InteractiveFlag.pinchMove,
          ),
          children: [
            TileLayer(
              backgroundColor: Theme.of(context).colorScheme.surface,
              urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
              subdomains: ['1', '2', '3', '4'],
            ),
            MarkerLayer(
              markers: [
                ...accessories
                    .where((accessory) => accessory.lastLocation != null)
                    .map((accessory) => Marker(
                  rotate: true,
                  width: 50,
                  height: 50,
                  point: accessory.lastLocation!,
                  child: AccessoryIcon(
                      icon: accessory.icon,
                      color: accessory.color),
                ))
                    .toList(),
              ],
            ),
            MarkerLayer(
              markers: [
                if (locationModel.here != null)
                  Marker(
                    width: 25.0,
                    height: 25.0,
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
                              color: Colors.blueAccent,   // 这里改为蓝色，不再是 indicatorColor
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
      },
    );
  }
}