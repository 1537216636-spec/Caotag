import 'dart:io';
import 'package:flutter/material.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon_model.dart';

class AccessoryIcon extends StatelessWidget {
  final String icon;
  final Color color;
  final double size;

  const AccessoryIcon({
    Key? key,
    required this.icon,
    this.color = Colors.blue,
    this.size = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 如果是网络图片
    if (icon.startsWith('http') || icon.startsWith('https')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          image: DecorationImage(
            image: NetworkImage(icon),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {},
          ),
        ),
      );
    }
    // 如果是本地文件（相册选中的图片）
    if (icon.startsWith('/') || icon.startsWith('file')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          image: DecorationImage(
            image: FileImage(File(icon)),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {},
          ),
        ),
      );
    }
    // 如果是 assets 图片
    if (icon.startsWith('assets/')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          image: DecorationImage(
            image: AssetImage(icon),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    // Material icon
    final iconData = AccessoryIconModel.mapIcon(icon) ?? Icons.push_pin;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
      ),
      child: Icon(
        iconData,
        size: size * 0.6,
        color: color,
      ),
    );
  }
}