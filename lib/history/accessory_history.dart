import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:openhaystack_mobile/history/days_selection_slider.dart';
import 'package:openhaystack_mobile/history/location_popup.dart';

class AccessoryHistory extends StatefulWidget {
  Accessory accessory;

  AccessoryHistory({
    Key? key,
    required this.accessory,
  }) : super(key: key);

  @override
  _AccessoryHistoryState createState() => _AccessoryHistoryState();
}

class _AccessoryHistoryState extends State<AccessoryHistory> {
  final MapController _mapController = MapController();

  bool showPopup = false;
  Pair<LatLng, DateTime>? popupEntry;

  double numberOfDays = 7;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      var historicLocations = widget.accessory.locationHistory
          .map((entry) => entry.a)
          .toList();
      if (historicLocations.isNotEmpty) {
        var bounds = LatLngBounds.fromPoints(historicLocations);
        _mapController.fitBounds(bounds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var now = DateTime.now();
    List<Pair<LatLng, DateTime>> locationHistory =
    widget.accessory.locationHistory
        .where(
          (element) => element.b.isAfter(
        now.subtract(Duration(days: numberOfDays.round())),
      ),
    )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accessory.name),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Flexible(
              flex: 3,
              fit: FlexFit.tight,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: LatLng(49.874739, 8.656280),
                  zoom: 13.0,
                  interactiveFlags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.flingAnimation |
                  InteractiveFlag.pinchMove,
                  onTap: (_, __) {
                    setState(() {
                      showPopup = false;
                      popupEntry = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                    subdomains: ['1', '2', '3', '4'],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: locationHistory
                            .map((entry) => entry.a)
                            .toList(),
                        strokeWidth: 4,
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: locationHistory
                        .map((entry) => Marker(
                      point: entry.a,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            showPopup = true;
                            popupEntry = entry;
                          });
                        },
                        child: Icon(
                          Icons.circle,
                          size: 15,
                          color: entry == popupEntry
                              ? Colors.red
                              : Theme.of(context).indicatorColor,
                        ),
                      ),
                    ))
                        .toList(),
                  ),
                  MarkerLayer(
                    markers: [
                      if (showPopup)
                        Marker(
                          point: popupEntry!.a,
                          child: LocationPopup(
                            location: popupEntry!.a,
                            time: popupEntry!.b,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 1,
              fit: FlexFit.tight,
              child: DaysSelectionSlider(
                numberOfDays: numberOfDays,
                onChanged: (double newValue) {
                  setState(() {
                    numberOfDays = newValue;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}