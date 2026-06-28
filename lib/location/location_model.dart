import 'package:openhaystack_mobile/utils/coordinate.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocode;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:openhaystack_mobile/utils/coordinate.dart';   // 坐标转换工具

class LocationModel extends ChangeNotifier {
  LatLng? here;
  geocode.Placemark? herePlace;
  StreamSubscription<LocationData>? locationStream;
  final Location _location = Location.instance;
  bool initialLocationSet = false;

  Future<bool> requestLocationAccess() async {
    var serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print('Could not enable location service.');
        return false;
      }
    }
    var permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
    }
    if (permissionGranted == PermissionStatus.granted) {
      return true;
    } else if (permissionGranted == PermissionStatus.grantedLimited) {
      return false;
    } else {
      return false;
    }
  }

  Future<void> requestLocationUpdates() async {
    var permissionGranted = await requestLocationAccess();
    if (!permissionGranted) {
      // 权限未授予，设置标志并通知界面（例如显示“无法获取位置”）
      initialLocationSet = true;
      _removeCurrentLocation();
      notifyListeners();
      return;
    }

    // 先尝试获取一次当前位置（带超时），但主要依靠流更新
    try {
      final locationData = await _location.getLocation().timeout(const Duration(seconds: 5));
      _updateLocation(locationData);
    } catch (e) {
      print('初始位置获取超时或失败，等待自动更新: $e');
    }

    // 监听位置变化（如果尚未监听）
    locationStream ??= _location.onLocationChanged.listen(_updateLocation);
  }

  void _updateLocation(LocationData locationData) {
    if (locationData.latitude != null && locationData.longitude != null) {
      // 坐标转换：WGS84 -> GCJ02
      final gcj = CoordinateConverter.wgs84ToGcj02(
          locationData.longitude!, locationData.latitude!);
      here = LatLng(gcj[1], gcj[0]);
      initialLocationSet = true;
      getAddress(here!)
          .then((value) {
        herePlace = value;
        notifyListeners();
      });
    } else {
      print('Received invalid location data: $locationData');
    }
    notifyListeners();
  }

  void cancelLocationUpdates() {
    if (locationStream != null) {
      locationStream?.cancel();
      locationStream = null;
    }
    _removeCurrentLocation();
    notifyListeners();
  }

  void _removeCurrentLocation() {
    here = null;
    herePlace = null;
  }

  static Future<geocode.Placemark?> getAddress(LatLng? location) async {
    if (location == null) return null;
    // 传入的坐标是 GCJ-02，需要逆转为 WGS-84 再获取地址
    final wgs = CoordinateConverter.gcj02ToWgs84(
        location.longitude, location.latitude);
    double lat = wgs[1];
    double lng = wgs[0];
    try {
      List<geocode.Placemark> placemarks =
      await geocode.placemarkFromCoordinates(lat, lng);
      return placemarks.first;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}