import 'package:flutter/material.dart';

class AccessoryIconModel {
  static const List<Map<String, dynamic>> icons = [
    // 设备
    {'icon': Icons.phone_android, 'name': 'phone_android', 'category': '设备'},
    {'icon': Icons.laptop, 'name': 'laptop', 'category': '设备'},
    {'icon': Icons.watch, 'name': 'watch', 'category': '设备'},
    {'icon': Icons.headphones, 'name': 'headphones', 'category': '设备'},
    {'icon': Icons.tablet, 'name': 'tablet', 'category': '设备'},
    {'icon': Icons.speaker, 'name': 'speaker', 'category': '设备'},
    {'icon': Icons.camera_alt, 'name': 'camera_alt', 'category': '设备'},
    // 出行
    {'icon': Icons.directions_car, 'name': 'directions_car', 'category': '出行'},
    {'icon': Icons.motorcycle, 'name': 'motorcycle', 'category': '出行'},
    {'icon': Icons.directions_bike, 'name': 'directions_bike', 'category': '出行'},
    {'icon': Icons.flight, 'name': 'flight', 'category': '出行'},
    {'icon': Icons.directions_bus, 'name': 'directions_bus', 'category': '出行'},
    {'icon': Icons.train, 'name': 'train', 'category': '出行'},
    // 物品
    {'icon': Icons.work, 'name': 'work', 'category': '物品'},
    {'icon': Icons.shopping_bag, 'name': 'shopping_bag', 'category': '物品'},
    {'icon': Icons.key, 'name': 'key', 'category': '物品'},
    {'icon': Icons.wallet, 'name': 'wallet', 'category': '物品'},
    {'icon': Icons.backpack, 'name': 'backpack', 'category': '物品'},
    {'icon': Icons.luggage, 'name': 'luggage', 'category': '物品'},
    {'icon': Icons.umbrella, 'name': 'umbrella', 'category': '物品'},
    // 宠物/人
    {'icon': Icons.pets, 'name': 'pets', 'category': '宠物'},
    {'icon': Icons.person, 'name': 'person', 'category': '宠物'},
    {'icon': Icons.child_care, 'name': 'child_care', 'category': '宠物'},
    // 默认
    {'icon': Icons.push_pin, 'name': 'push_pin', 'category': '默认'},
  ];

  static IconData? mapIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) return null;
    if (iconName.startsWith('http') || iconName.startsWith('file') || iconName.startsWith('/') || iconName.startsWith('assets/')) {
      return null; // 自定义图片，不是 Material icon
    }
    for (var iconMap in icons) {
      if (iconMap['name'] == iconName || iconMap['icon'].toString() == iconName) {
        return iconMap['icon'] as IconData;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> getIconsByCategory() {
    final categories = <String, List<Map<String, dynamic>>>{};
    for (var icon in icons) {
      final cat = icon['category'] as String;
      if (!categories.containsKey(cat)) {
        categories[cat] = [];
      }
      categories[cat]!.add(icon);
    }
    // 添加“自定义”类别
    categories['自定义'] = [
      {'icon': Icons.add_a_photo, 'name': 'custom', 'category': '自定义'}
    ];
    return categories.entries.map((e) => {'category': e.key, 'icons': e.value}).toList();
  }
}