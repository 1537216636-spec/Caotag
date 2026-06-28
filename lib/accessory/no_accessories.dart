import 'package:flutter/material.dart';
import 'package:openhaystack_mobile/item_management/new_item_action.dart';

class NoAccessoriesPlaceholder extends StatelessWidget {
  const NoAccessoriesPlaceholder({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('暂无配件', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('下拉刷新获取位置报告，或点击 + 添加配件'),
        ],
      ),
    );
  }
}