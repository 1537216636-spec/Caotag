import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:openhaystack_mobile/dashboard/dashboard_desktop.dart';
import 'package:openhaystack_mobile/dashboard/dashboard_mobile.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/item_management/item_file_import.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/preferences/user_preferences_model.dart';
import 'package:openhaystack_mobile/splashscreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AccessoryRegistry()),
        ChangeNotifierProvider(create: (ctx) => UserPreferences()),
        ChangeNotifierProvider(create: (ctx) => LocationModel()),
      ],
      child: MaterialApp(
        title: '草寻',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFF161B22),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: const Color(0xFF161B22),
            headerBackgroundColor: const Color(0xFF1E88E5),
            headerForegroundColor: Colors.white,
            dayStyle: const TextStyle(color: Colors.white),
            todayBorder: const BorderSide(color: Colors.blueAccent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        home: const AppLayout(),
      ),
    );
  }
}

class AppLayout extends StatefulWidget {
  const AppLayout({Key? key}) : super(key: key);
  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  StreamSubscription? _intentDataStreamSubscription;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    // 闪屏至少显示 2.5 秒
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });

    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen(handleFileSharingIntent, onError: (err) => print("getMediaStream error: $err"));
    ReceiveSharingIntent.instance.getInitialMedia().then(handleFileSharingIntent);

    var accessoryRegistry = Provider.of<AccessoryRegistry>(context, listen: false);
    accessoryRegistry.loadAccessories();
  }

  Future<void> handleFileSharingIntent(List<SharedMediaFile> files) async {
    for (var file in files) {
      if (file.type == SharedMediaType.file) {
        String path = Platform.isIOS
            ? Uri.decodeComponent(file.path.replaceFirst('file://', ''))
            : file.path;
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemFileImport(filePath: path)));
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Splashscreen(
        onFinish: () {
          if (mounted) setState(() => _showSplash = false);
        },
      );
    }

    bool isInitialized = context.watch<UserPreferences>().initialized;
    bool isLoading = context.watch<AccessoryRegistry>().loading;
    if (!isInitialized || isLoading) {
      return const Splashscreen();
    }

    // 数据就绪后，延迟一小段时间确保地图组件完成构建
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 100)),
      builder: (context, snapshot) {
        Size screenSize = MediaQuery.of(context).size;
        if (screenSize.width < 800) return const DashboardMobile();
        else return const DashboardDesktop();
      },
    );
  }
}