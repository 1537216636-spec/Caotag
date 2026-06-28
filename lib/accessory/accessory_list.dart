import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openhaystack_mobile/accessory/accessory_list_item.dart';
import 'package:openhaystack_mobile/accessory/accessory_list_item_placeholder.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/accessory/no_accessories.dart';
import 'package:openhaystack_mobile/history/accessory_track_page.dart';
import 'package:openhaystack_mobile/navigation/ble_navigator.dart';
import 'package:openhaystack_mobile/location/location_model.dart';

class AccessoryList extends StatefulWidget {
  final AsyncCallback loadLocationUpdates;
  final void Function(LatLng point)? centerOnPoint;

  const AccessoryList({
    Key? key,
    required this.loadLocationUpdates,
    this.centerOnPoint,
  }) : super(key: key);

  @override
  _AccessoryListState createState() => _AccessoryListState();
}

class _AccessoryListState extends State<AccessoryList> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessoryRegistry, LocationModel>(
      builder: (context, accessoryRegistry, locationModel, child) {
        var accessories = accessoryRegistry.accessories.toList();

        if (accessoryRegistry.loading) {
          return LayoutBuilder(
            builder: (context, constraints) {
              var nrOfEntries = min(max((constraints.maxHeight / 64).floor(), 1), 6);
              List<Widget> placeholderList = [];
              for (int i = 0; i < nrOfEntries; i++) {
                placeholderList.add(const AccessoryListItemPlaceholder());
              }
              return Scrollbar(child: ListView(children: placeholderList));
            },
          );
        }

        if (accessories.isEmpty) {
          return const NoAccessoriesPlaceholder();
        }

        return SlidableAutoCloseBehavior(
          child: RefreshIndicator(
            onRefresh: widget.loadLocationUpdates,
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: accessories.map((accessory) {
                  Widget? trailing;
                  if (locationModel.here != null && accessory.lastLocation != null) {
                    const Distance distance = Distance();
                    final double km = distance.as(LengthUnit.Kilometer, locationModel.here!, accessory.lastLocation!);
                    trailing = Text('${km.toStringAsFixed(1)} km');
                  }

                  return Slidable(
                    endActionPane: ActionPane(
                      motion: const BehindMotion(),
                      extentRatio: 0.65,   // 确保三个按钮完整显示
                      children: [
                        if (accessory.isDeployed && accessory.lastLocation != null)
                          _buildSlidableAction(
                            icon: Icons.directions,
                            label: '导航',
                            gradient: const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF0060DF)]),
                            onTap: (ctx) async {
                              final lat = accessory.lastLocation!.latitude;
                              final lon = accessory.lastLocation!.longitude;
                              final url = 'https://uri.amap.com/marker?position=$lon,$lat&name=${Uri.encodeComponent(accessory.name)}';
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              } else {
                                await MapsLauncher.launchCoordinates(lat, lon, accessory.name);
                              }
                              Slidable.of(ctx)?.close();
                            },
                          ),
                        if (accessory.isDeployed)
                          _buildSlidableAction(
                            icon: Icons.route,
                            label: '轨迹',
                            gradient: const LinearGradient(colors: [Color(0xFFFF9500), Color(0xFFE68600)]),
                            onTap: (ctx) {
                              Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (context) => AccessoryTrackPage(accessory: accessory),
                                ),
                              );
                              Slidable.of(ctx)?.close();
                            },
                          ),
                        if (accessory.isDeployed && accessory.macAddress.isNotEmpty)
                          _buildSlidableAction(
                            icon: Icons.bluetooth_searching,
                            label: '搜索',
                            gradient: const LinearGradient(colors: [Color(0xFF30D158), Color(0xFF28B04B)]),
                            onTap: (ctx) {
                              Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (context) => BleNavigator(
                                    targetMac: accessory.macAddress,
                                    deviceName: accessory.name,
                                  ),
                                ),
                              );
                              Slidable.of(ctx)?.close();
                            },
                          ),
                        if (!accessory.isDeployed)
                          _buildSlidableAction(
                            icon: Icons.upload_file,
                            label: '部署',
                            gradient: const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF5856D6)]),
                            onTap: (ctx) {
                              var registry = Provider.of<AccessoryRegistry>(ctx, listen: false);
                              var newAccessory = accessory.clone();
                              newAccessory.isDeployed = true;
                              registry.editAccessory(accessory, newAccessory);
                              Slidable.of(ctx)?.close();
                            },
                          ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) {
                        return AccessoryListItem(
                          accessory: accessory,
                          distance: trailing,
                          herePlace: locationModel.herePlace,
                          onTap: () {
                            if (accessory.lastLocation != null) {
                              widget.centerOnPoint?.call(accessory.lastLocation!);
                            }
                          },
                          onLongPress: Slidable.of(context)?.openEndActionPane,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlidableAction({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required void Function(BuildContext) onTap,
  }) {
    return GestureDetector(
      onTap: () => onTap(context),
      child: Container(
        width: 68,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.last.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}