import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon_model.dart';
import 'package:openhaystack_mobile/findMy/find_my_controller.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/utils/coordinate.dart';

class Pair<T1, T2> {
  final T1 a;
  final T2 b;
  Pair(this.a, this.b);
}

const defaultIcon = 'push_pin';

class Accessory {
  String id;
  String hashedPublicKey;
  bool usesDerivation;

  String? symmetricKey;
  double? lastDerivationTimestamp;
  int? updateInterval;
  String? oldestRelevantSymmetricKey;

  String name;
  String _icon;      // 字符串（Material 图标名、路径或 URL）
  Color color;

  bool isActive;
  bool isDeployed;

  DateTime? datePublished;
  LatLng? _lastLocation;

  List<Pair<LatLng, DateTime>> locationHistory = [];
  Future<Placemark?> place = Future.value(null);

  List<String> additionalKeys;
  List<String> queryKeys;
  String macAddress;

  Accessory({
    required this.id,
    required this.name,
    required this.hashedPublicKey,
    required this.datePublished,
    this.isActive = false,
    this.isDeployed = false,
    LatLng? lastLocation,
    String icon = 'push_pin',
    this.color = Colors.grey,
    this.usesDerivation = false,
    this.symmetricKey,
    this.lastDerivationTimestamp,
    this.updateInterval,
    this.oldestRelevantSymmetricKey,
    this.additionalKeys = const [],
    this.queryKeys = const [],
    this.macAddress = '',
  })  : _icon = icon,
        _lastLocation = lastLocation {
    _init();
  }

  void _init() {
    if (_lastLocation != null) {
      final gcj = CoordinateConverter.wgs84ToGcj02(
          _lastLocation!.longitude, _lastLocation!.latitude);
      _lastLocation = LatLng(gcj[1], gcj[0]);
    }
    if (_lastLocation != null) {
      place = LocationModel.getAddress(_lastLocation!);
    }
  }

  Accessory clone() {
    return Accessory(
      datePublished: datePublished,
      id: id,
      name: name,
      hashedPublicKey: hashedPublicKey,
      color: color,
      icon: _icon,
      isActive: isActive,
      isDeployed: isDeployed,
      lastLocation: lastLocation,
      usesDerivation: usesDerivation,
      symmetricKey: symmetricKey,
      lastDerivationTimestamp: lastDerivationTimestamp,
      updateInterval: updateInterval,
      oldestRelevantSymmetricKey: oldestRelevantSymmetricKey,
      additionalKeys: List<String>.from(additionalKeys),
      queryKeys: List<String>.from(queryKeys),
      macAddress: macAddress,
    );
  }

  void update(Accessory newAccessory) {
    datePublished = newAccessory.datePublished;
    id = newAccessory.id;
    name = newAccessory.name;
    hashedPublicKey = newAccessory.hashedPublicKey;
    color = newAccessory.color;
    _icon = newAccessory._icon;
    isActive = newAccessory.isActive;
    isDeployed = newAccessory.isDeployed;
    lastLocation = newAccessory.lastLocation;
    additionalKeys = List<String>.from(newAccessory.additionalKeys);
    queryKeys = List<String>.from(newAccessory.queryKeys);
    macAddress = newAccessory.macAddress;
  }

  LatLng? get lastLocation => _lastLocation;

  set lastLocation(LatLng? newLocation) {
    if (newLocation != null) {
      final gcj = CoordinateConverter.wgs84ToGcj02(
          newLocation.longitude, newLocation.latitude);
      _lastLocation = LatLng(gcj[1], gcj[0]);
    } else {
      _lastLocation = null;
    }
    if (_lastLocation != null) {
      place = LocationModel.getAddress(_lastLocation!);
    }
  }

  void addLocationPoint(LatLng wgsPoint, DateTime time) {
    final gcj = CoordinateConverter.wgs84ToGcj02(
        wgsPoint.longitude, wgsPoint.latitude);
    locationHistory.add(Pair(LatLng(gcj[1], gcj[0]), time));
  }

  /// 直接设置已转换的 GCJ-02 坐标，避免二次转换
  void setLastLocationGCJ(LatLng gcjPoint, DateTime time) {
    _lastLocation = gcjPoint;
    datePublished = time;
    if (_lastLocation != null) {
      place = LocationModel.getAddress(_lastLocation!);
    }
  }

  String get icon => _icon;
  String get rawIcon => _icon;

  setIcon(String icon) {
    _icon = icon;
  }

  Accessory.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        name = json['name'] ?? '',
        hashedPublicKey = json['hashedPublicKey'] ?? '',
        datePublished = json['datePublished'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['datePublished'])
            : null,
        _lastLocation = json['latitude'] != null && json['longitude'] != null
            ? LatLng(json['latitude'].toDouble(), json['longitude'].toDouble())
            : null,
        isActive = json['isActive'] ?? false,
        isDeployed = json['isDeployed'] ?? false,
        _icon = json['icon'] ?? 'push_pin',
        color = json['color'] != null
            ? Color(int.parse(json['color'], radix: 16))
            : Colors.grey,
        usesDerivation = json['usesDerivation'] ?? false,
        symmetricKey = json['symmetricKey'],
        lastDerivationTimestamp = json['lastDerivationTimestamp']?.toDouble(),
        updateInterval = json['updateInterval'],
        oldestRelevantSymmetricKey = json['oldestRelevantSymmetricKey'],
        additionalKeys = (json['additionalKeys'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        queryKeys = (json['queryKeys'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        macAddress = json['macAddress'] ?? '' {
    if (_lastLocation != null) {
      place = LocationModel.getAddress(_lastLocation!);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hashedPublicKey': hashedPublicKey,
    'datePublished': datePublished?.millisecondsSinceEpoch,
    'latitude': _lastLocation?.latitude,
    'longitude': _lastLocation?.longitude,
    'isActive': isActive,
    'isDeployed': isDeployed,
    'icon': _icon,
    'color': color.value.toRadixString(16).padLeft(8, '0'),
    'usesDerivation': usesDerivation,
    'symmetricKey': symmetricKey,
    'lastDerivationTimestamp': lastDerivationTimestamp,
    'updateInterval': updateInterval,
    'oldestRelevantSymmetricKey': oldestRelevantSymmetricKey,
    'additionalKeys': additionalKeys,
    'queryKeys': queryKeys,
    'macAddress': macAddress,
  };

  Future<String> getPrivateKey() async {
    try {
      var keyPair = await FindMyController.getKeyPair(hashedPublicKey);
      return keyPair?.getBase64PrivateKey() ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<String> getAdvertisementKey() async {
    try {
      var keyPair = await FindMyController.getKeyPair(hashedPublicKey);
      return keyPair?.getBase64AdvertisementKey() ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<String> getHashedAdvertisementKey() async {
    try {
      var keyPair = await FindMyController.getKeyPair(hashedPublicKey);
      return keyPair?.getHashedAdvertisementKey() ?? '';
    } catch (e) {
      return '';
    }
  }
}