import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/dashboard/accessory_map_list_vert.dart';
import 'package:openhaystack_mobile/item_management/item_management.dart';
import 'package:openhaystack_mobile/item_management/new_item_action.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/preferences/preferences_page.dart';
import 'package:openhaystack_mobile/preferences/user_preferences_model.dart';

class DashboardMobile extends StatefulWidget {
  const DashboardMobile({Key? key}) : super(key: key);

  @override
  _DashboardMobileState createState() => _DashboardMobileState();
}

class _DashboardMobileState extends State<DashboardMobile> {
  final GlobalKey<AccessoryMapListVerticalState> _mapListKey =
  GlobalKey<AccessoryMapListVerticalState>();

  late final List<Map<String, dynamic>> _tabs = [
    {
      'title': '我的配件',
      'body': (ctx) => AccessoryMapListVertical(
        key: _mapListKey,
        loadLocationUpdates: loadLocationUpdates,
      ),
      'icon': Icons.place,
      'label': '地图',
    },
    {
      'title': '配件管理',
      'body': (ctx) => const KeyManagement(),
      'icon': Icons.style,
      'label': '管理',
      'actionButton': (ctx) => const NewKeyAction(),
    },
  ];

  bool _hasFocused = false;

  @override
  void initState() {
    super.initState();
    var userPreferences = Provider.of<UserPreferences>(context, listen: false);
    var locationModel = Provider.of<LocationModel>(context, listen: false);
    var locationPreferenceKnown = userPreferences.locationPreferenceKnown ?? false;
    var locationAccessWanted = userPreferences.locationAccessWanted ?? false;
    if (!locationPreferenceKnown || locationAccessWanted) {
      locationModel.requestLocationUpdates();
    }
    loadLocationUpdates();
  }

  Future<void> loadLocationUpdates() async {
    var accessoryRegistry = Provider.of<AccessoryRegistry>(context, listen: false);
    try {
      await accessoryRegistry.loadLocationReports();
      // 数据加载完成后，自动聚焦到第一个配件
      if (mounted && !_hasFocused) {
        _mapListKey.currentState?.focusOnFirstAccessory();
        _hasFocused = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text(
              '无法获取位置报告，请稍后重试',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        );
      }
    }
  }

  int _selectedIndex = 0;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的配件'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreferencesPage()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _tabs[_selectedIndex]['body'](context),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            items: _tabs.map((tab) => BottomNavigationBarItem(
              icon: Icon(tab['icon']),
              label: tab['label'],
            )).toList(),
            currentIndex: _selectedIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      floatingActionButton: _tabs[_selectedIndex]['actionButton']?.call(context),
    );
  }
}