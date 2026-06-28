import 'package:openhaystack_mobile/utils/coordinate.dart';
import 'package:openhaystack_mobile/findMy/reports_fetcher.dart';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:openhaystack_mobile/findMy/find_my_controller.dart';

const accessoryStorageKey = 'ACCESSORIES';

class AccessoryRegistry extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _findMyController = FindMyController();
  List<Accessory> _accessories = [];
  bool loading = false;
  bool initialLoadFinished = false;

  List<String> _globalKeys = [];
  static const _globalKeysKey = 'GLOBAL_KEYS';

  AccessoryRegistry() : super();

  UnmodifiableListView<Accessory> get accessories =>
      UnmodifiableListView(_accessories);

  Future<void> loadAccessories() async {
    loading = true;
    String? serialized = await _storage.read(key: accessoryStorageKey);
    if (serialized != null) {
      try {
        var decoded = json.decode(serialized);
        if (decoded is List) {
          List<Accessory> loadedAccessories = [];
          for (var val in decoded) {
            if (val is Map<String, dynamic>) {
              loadedAccessories.add(Accessory.fromJson(val));
            }
          }
          _accessories = loadedAccessories;
        } else {
          _accessories = [];
        }
      } catch (e) {
        print("Error decoding accessories: $e");
        _accessories = [];
      }
    } else {
      _accessories = [];
    }

    // 自动转换旧坐标，确保所有位置为 GCJ-02
    for (var a in _accessories) {
      if (a.locationHistory.isNotEmpty) {
        a.locationHistory = a.locationHistory.map((pair) {
          final gcj = CoordinateConverter.wgs84ToGcj02(pair.a.longitude, pair.a.latitude);
          return Pair(LatLng(gcj[1], gcj[0]), pair.b);
        }).toList();
      }
      if (a.lastLocation != null) {
        final gcj = CoordinateConverter.wgs84ToGcj02(
            a.lastLocation!.longitude, a.lastLocation!.latitude);
        a.setLastLocationGCJ(LatLng(gcj[1], gcj[0]), a.datePublished ?? DateTime.now());
      }
    }
    await _storeAccessories(); // 保存转换后的数据

    _globalKeys = [];
    loading = false;
    notifyListeners();
  }

  Future<void> _loadGlobalKeys() async { _globalKeys = []; }
  Future<void> _storeGlobalKeys() async { }
  Future<void> addGlobalKeys(List<String> newKeys) async { }

  Future<void> loadLocationReports() async {
    final List<Accessory> currentAccessories = accessories;

    final Set<String> allKeysSet = {};
    for (var accessory in currentAccessories) {
      if (accessory.queryKeys.isNotEmpty) {
        allKeysSet.addAll(accessory.queryKeys);
      } else if (accessory.hashedPublicKey.isNotEmpty) {
        allKeysSet.add(accessory.hashedPublicKey);
      }
    }
    final List<String> allKeys = allKeysSet.toList();
    if (allKeys.isEmpty) {
      print("没有有效密钥");
      return;
    }

    print('🔑 Number of keys sent: ${allKeys.length}');

    try {
      List<dynamic> reports = await ReportsFetcher.fetchLocationReports(allKeys);
      print("Total reports received: ${reports.length}");

      for (var a in currentAccessories) {
        a.locationHistory.clear();
        a.lastLocation = null;
      }

      for (var r in reports) {
        final map = r as Map<String, dynamic>;
        final reportId = map['id'] as String?;
        if (reportId == null) continue;

        Accessory? matched;
        for (var a in currentAccessories) {
          if (a.hashedPublicKey == reportId ||
              a.additionalKeys.contains(reportId)) {
            matched = a;
            break;
          }
        }

        if (matched != null) {
          final wgsLat = (map['latitude'] as num).toDouble();
          final wgsLon = (map['longitude'] as num).toDouble();
          final wgsPoint = LatLng(wgsLat, wgsLon);
          final time = DateTime.fromMillisecondsSinceEpoch(
              ((map['timestamp'] as num).toInt()) * 1000);

          matched.addLocationPoint(wgsPoint, time);
        }
      }

      for (var a in currentAccessories) {
        a.locationHistory.sort((a, b) => b.b.compareTo(a.b));
        if (a.locationHistory.isNotEmpty) {
          final latest = a.locationHistory.first;
          a.setLastLocationGCJ(latest.a, latest.b);
        }
      }
    } catch (e) {
      print("Error loading reports: $e");
    }

    await _storeAccessories();
    initialLoadFinished = true;
    notifyListeners();
  }

  Future<void> _storeAccessories() async {
    final jsonList = _accessories.map((a) => a.toJson()).toList();
    await _storage.write(
        key: accessoryStorageKey, value: json.encode(jsonList));
  }

  void addAccessory(Accessory accessory) {
    _accessories.add(accessory);
    _storeAccessories();
    notifyListeners();
  }

  void removeAccessory(Accessory accessory) {
    _accessories.remove(accessory);
    _storeAccessories();
    notifyListeners();
  }

  void editAccessory(Accessory oldAccessory, Accessory newAccessory) {
    oldAccessory.update(newAccessory);
    _storeAccessories();
    notifyListeners();
  }
}