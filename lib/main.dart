import 'dart:async';
import 'dart:io';

import 'package:G4A4/browser/webview_tab.dart';
import 'package:G4A4/model/notification_state.dart';
import 'package:G4A4/pages/loading_service.dart';
import 'package:G4A4/services/dataStore_service.dart';
import 'package:G4A4/services/deep_link_service.dart';
import 'package:G4A4/services/notification_server_Services.dart';
import 'package:G4A4/widgets/appWrapper.dart';
import 'package:firebase_notifications_handler/firebase_notifications_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:G4A4/firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:context_menus/context_menus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager_plus/window_manager_plus.dart';
import 'package:path/path.dart' as p;

import 'widgets/helpers.dart';
import 'config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:G4A4/pages/splash_screen.dart';
import 'browser/models/browser_model.dart';
import 'browser/models/webview_model.dart';
import 'browser/models/window_model.dart';
import 'browser/util.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
late List<UserScript> userScripts;
// ignore: non_constant_identifier_names
late final String WEB_ARCHIVE_DIR;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_1;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_2;
// ignore: non_constant_identifier_names
late final double TAB_VIEWER_BOTTOM_OFFSET_3;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_1 = 0.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_2 = 10.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_OFFSET_3 = 20.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_SCALE_TOP_OFFSET = 250.0;
// ignore: constant_identifier_names
const double TAB_VIEWER_TOP_SCALE_BOTTOM_OFFSET = 230.0;

WebViewEnvironment? webViewEnvironment;
Database? db;

int windowId = 0;
String? windowModelId;
WebViewTab? BaseWebViewTab = null;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(
      widgetsBinding: WidgetsFlutterBinding.ensureInitialized());
// مقداردهی اولیه ناتیفیکیشن‌ها
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher');
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  // منطق پروژه مرورگر
  if (Util.isDesktop()) {
    windowId = args.isNotEmpty ? int.tryParse(args[0]) ?? 0 : 0;
    windowModelId = args.length > 1 ? args[1] : null;
    await WindowManagerPlus.ensureInitialized(windowId);
  }

  final appDocumentsDir = await getApplicationDocumentsDirectory();

  if (Util.isDesktop()) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  db = await databaseFactory.openDatabase(
    p.join(appDocumentsDir.path, "databases", "myDb.db"),
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (Database db, int version) async {
        await db.execute(
            'CREATE TABLE browser (id INTEGER PRIMARY KEY, json TEXT)');
        await db
            .execute('CREATE TABLE windows (id TEXT PRIMARY KEY, json TEXT)');
      },
    ),
  );

  if (Util.isDesktop()) {
    WindowOptions windowOptions = WindowOptions(
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle:
          Util.isWindows() ? TitleBarStyle.normal : TitleBarStyle.hidden,
      minimumSize: const Size(1280, 720),
      size: const Size(1280, 720),
    );
    WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
      if (!Util.isWindows()) {
        await WindowManagerPlus.current.setAsFrameless();
        await WindowManagerPlus.current.setHasShadow(true);
      }
      await WindowManagerPlus.current.show();
      await WindowManagerPlus.current.focus();
    });
  }

  WEB_ARCHIVE_DIR = (await getApplicationSupportDirectory()).path;
  TAB_VIEWER_BOTTOM_OFFSET_1 = 150.0;
  TAB_VIEWER_BOTTOM_OFFSET_2 = 160.0;
  TAB_VIEWER_BOTTOM_OFFSET_3 = 170.0;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    assert(
        availableVersion != null, 'Failed to find WebView2 Runtime or Edge.');
    webViewEnvironment = await WebViewEnvironment.create(
      settings:
          WebViewEnvironmentSettings(userDataFolder: 'flutter_browser_app'),
    );
  }

  if (Util.isMobile()) {
    await FlutterDownloader.initialize(debug: kDebugMode);
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
    // await Permission.accessNotificationPolicy.request();
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  // منطق پروژه G4A4
  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: SYSTEM_NAVIGATION_BAR_COLOR,
      systemNavigationBarIconBrightness: SYSTEM_NAVIGATION_BAR_ICON_BRIGHTNESS,
    ));
  }
  // Set up method channel for deep links
  // const platform = MethodChannel('com.example.g4a4/deeplink');
  // platform.setMethodCallHandler((call) async {
  //   if (call.method == 'handleDeepLink') {
  //     final String link = call.arguments;
  //     print("Received deep link from platform channel: $link");
  //     DeepLinkService().handleDeepLink(link);
  //   }
  // });
  runApp(const SplashApp());
}

class SplashApp extends StatefulWidget {
  const SplashApp({super.key});

  @override
  State<SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<SplashApp> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => BrowserModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => WebViewModel(),
        ),
        ChangeNotifierProxyProvider<WebViewModel, WindowModel>(
          update: (context, webViewModel, windowModel) {
            windowModel!.setCurrentWebViewModel(webViewModel);
            return windowModel;
          },
          create: (BuildContext context) => WindowModel(id: null),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          visualDensity: VisualDensity.adaptivePlatformDensity,
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Colors.blue,
            cursorColor: Colors.blue,
            selectionHandleColor: Colors.blue,
          ),
        ),
        home: Scaffold(
          body: SplashScreen(
            typeOfSplashScreen: LOGO_MOTION_TYPE,
            splashTimeout: LOGO_MOTION_TIME,
            exitInEnd: true,
            returnRoutePath: '/sphome',
          ),
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          // Locale('en'), // English
          Locale('fa'), // Farsi
        ],
        routes: {'/sphome': (context) => AppWrapper()},
      ),
    );
  }
}
