import 'dart:async';
import 'dart:io';

import 'package:Item4Gamer/browser/models/webview_model.dart';
import 'package:Item4Gamer/browser/models/window_model.dart';
import 'package:Item4Gamer/browser/util.dart';
import 'package:Item4Gamer/browser/webview_tab.dart';
import 'package:Item4Gamer/config.dart';
import 'package:Item4Gamer/firebase_options.dart';
import 'package:Item4Gamer/main.dart';
import 'package:Item4Gamer/model/notification_state.dart';
import 'package:Item4Gamer/pages/loading_service.dart';
import 'package:Item4Gamer/services/auth_service.dart';
import 'package:Item4Gamer/services/dataStore_service.dart';
import 'package:Item4Gamer/services/deep_link_service.dart';
import 'package:Item4Gamer/services/notification_server_Services.dart';
import 'package:Item4Gamer/widgets/helpers.dart';
import 'package:Item4Gamer/widgets/routeGenerator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_notifications_handler/firebase_notifications_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:window_manager_plus/window_manager_plus.dart';
import 'package:flutter/scheduler.dart' as scheduler;

final GlobalKey<WebViewTabState> webViewTabKey = GlobalKey<WebViewTabState>();

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});
  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> with WindowListener {
  bool _isInitialized = false;
  // https://github.com/pichillilorenzo/window_manager_plus/issues/5
  late final AppLifecycleListener? _appLifecycleListener;
  StreamSubscription? _deepLinkSubscription;
  @override
  void initState() {
    _initializeApp();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.show(context); // جایگزین child: buildLoadingScreen()
    });
    if (Util.isWindows() || Util.isMacOS()) {
      scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
        final wm = WindowManagerPlus?.current;
        if (wm != null) {
          wm.addListener(this);

          wm.addListener(this);

          // https://github.com/pichillilorenzo/window_manager_plus/issues/5
          if (wm.id > 0 && Platform.isMacOS) {
            _appLifecycleListener = AppLifecycleListener(
              onStateChange: _handleStateChange,
            );
          }
        }
      });
    }
    // Listen for deep links
    // _deepLinkSubscription =
    //     DeepLinkService().deepLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(String link) async {
    print("AppWrapper received deep link: $link");
    await ensureWebViewInitialized();
    if (link == 'login') {
      // Handle login deep link
      Get.find<AppController>().updateIsBrowserVisible(false);
      Globals.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } else if (link.isNotEmpty) {
      // Handle content deep link
      Get.find<AppController>().updateIsBrowserVisible(true);

      // Make sure BaseWebViewTab is ready
      if (BaseWebViewTab == null ||
          BaseWebViewTab!.webViewModel.webViewController == null) {
        // Create or initialize WebViewTab if needed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {}); // Trigger rebuild to create WebViewTab
        });
      } else {
        BaseWebViewTab!.webViewModel.webViewController
            ?.loadUrl(urlRequest: URLRequest(url: WebUri(link)));
      }
    }
  }

  Future<void> ensureWebViewInitialized() async {
    if (BaseWebViewTab == null ||
        BaseWebViewTab!.webViewModel.webViewController == null) {
      WebViewModel webviewmodel =
          Provider.of<WebViewModel>(context, listen: false);
      webviewmodel.url = WebUri(URL);
      BaseWebViewTab =
          WebViewTab(webViewModel: webviewmodel, key: webViewTabKey);
      await Future.delayed(
          Duration(milliseconds: 100)); // تأخیر کوچک برای اطمینان
    }
  }

  void _handleStateChange(AppLifecycleState state) {
    // https://github.com/pichillilorenzo/window_manager_plus/issues/5
    if (WindowManagerPlus.current.id > 0 &&
        Platform.isMacOS &&
        state == AppLifecycleState.hidden) {
      scheduler.SchedulerBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
  }

  // Initialize all app dependencies here
  Future<void> _initializeApp() async {
    // Initialize essential services first

    // Add performance optimizations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reduce frame latency
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
      WebViewModel webviewmodel =
          Provider.of<WebViewModel>(context, listen: false);
      webviewmodel.url = WebUri(URL);

      BaseWebViewTab = WebViewTab(webViewModel: webviewmodel, key: GlobalKey());
    });

    // Enable hardware acceleration
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        // statusBarColor: STATUS_BAR_COLOR,
        systemNavigationBarColor: SYSTEM_NAVIGATION_BAR_COLOR,
        // statusBarIconBrightness: STATUS_BAR_ICON_BRIGHTNESS,
        systemNavigationBarIconBrightness:
            SYSTEM_NAVIGATION_BAR_ICON_BRIGHTNESS,
        // systemNavigationBarContrastEnforced: false,
      ));
    }

    PaintingBinding.instance.imageCache.maximumSize = 100; // Limit cache size
    // Initialize remaining GetX controllers
    Get.lazyPut(() => AppController(), fenix: true);
    Get.lazyPut(() => NotificationServerServices(), fenix: true);
    Get.lazyPut(() => NotificationState(), fenix: true);

    await Future.wait([
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      // Initialize Firebase only if needed for the splash screen
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .then((_) async {
        await requestNotificationPermission();
      }),

      // Initialize Firebase notification channels
      FirebaseNotificationsHandler.createAndroidNotificationChannels([
        AndroidNotificationChannel(
          'default',
          'Default Notifications',
          description: 'Item4Gamer Notifications',
          importance: Importance.high,
          playSound: true,
        ),
      ]),

      // Request permissions
    ]).then((_) {
      // Mark initialization as complete
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    WindowManagerPlus.current.removeListener(this);
    _appLifecycleListener?.dispose();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  void onWindowFocus([int? windowId]) {
    setState(() {});
    if (!Util.isWindows()) {
      WindowManagerPlus.current.setMovable(false);
    }
  }

  @override
  void onWindowBlur([int? windowId]) {
    if (!Util.isWindows()) {
      WindowManagerPlus.current.setMovable(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // return Util.isMobile()
    // ? materialApp
    // : ContextMenuOverlay(
    //     child: materialApp,
    //   );
    // Show loading indicator until initialization is complete
    if (!_isInitialized) {
      return MaterialApp(
        theme: ThemeData(
          visualDensity: VisualDensity.adaptivePlatformDensity,
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Colors.blue,
            cursorColor: Colors.blue,
            selectionHandleColor: Colors.blue,
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            // برای دسترسی به context
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                LoadingService.show(
                    context); // جایگزین child: buildLoadingScreen()
              });
              return const SizedBox
                  .shrink(); // placeholder، چون overlay جدا است
            },
          ),
        ),
      );
    }
    return FirebaseNotificationsHandler(
        localNotificationsConfiguration: LocalNotificationsConfiguration(
          androidConfig: AndroidNotificationsConfig(
            channelIdGetter: (message) =>
                'high_importance_channel', // Static channel ID for consistency
            channelNameGetter: (message) =>
                'High Importance Notifications', // Static channel name
            channelDescriptionGetter: (message) =>
                'Item4Gamer Notifications', // Static description
            importanceGetter: (message) =>
                Importance.high, // High importance for pop-ups
            priorityGetter: (message) =>
                Priority.high, // High priority for urgency
            imageUrlGetter: (message) =>
                message.data['imageUrl'] ??
                message.notification?.android
                    ?.imageUrl, // Dynamic image URL from message data
            // soundGetter: (message) =>
            //     message.data['sound'] ??
            //     'default_sound', // Dynamic sound with fallback
            colorGetter: (message) =>
                Colors.blue, // Static color for notification
            playSoundGetter: (message) => true, // Always play sound
            enableLightsGetter: (message) => true, // Always enable lights
            enableVibrationGetter: (message) => true, // Always enable vibration
            appIconGetter: (message) =>
                '@mipmap/ic_launcher', // Default app icon
          ),
          iosConfig: IosNotificationsConfig(
            soundGetter: (message) =>
                message.data['sound'] ??
                'default_sound', // Dynamic sound with fallback
            subtitleGetter: (message) =>
                message.data['subtitle'], // Dynamic subtitle from message data
            imageUrlGetter: (message) =>
                message.data['imageUrl'], // Dynamic image URL from message data
            badgeNumberGetter: (message) => Get.find<NotificationState>()
                .unreadCount, // Dynamic badge number
            presentSoundGetter: (message) => true, // Always present sound
            presentAlertGetter: (message) => true, // Always present alert
            presentBadgeGetter: (message) => true, // Always present badge
            presentBannerGetter: (message) => true, // Always present banner
            presentListGetter: (message) =>
                true, // Always present in notification list
          ),
          notificationIdGetter: (message) =>
              int.tryParse(message.messageId ?? '0') ??
              0, // Unique ID per message
        ),
        requestPermissionsOnInitialize: true,
        shouldHandleNotification: (msg) {
          // You can add logic to filter notifications if needed
          return true;
        },
        onOpenNotificationArrive: (info) {
          print("Foreground message received: ${info.payload}");
          print("App state: ${info.appState}");
          Get.find<NotificationState>().incrementUnread();
        },
        onTap: (info) {
          print("Notification tapped: ${info.payload}");
          // Improve navigation logic
          final payload = info.payload;
          if (payload != null && payload.isNotEmpty) {
            String route = '/home';
            String? url;

            if (payload.containsKey('route')) {
              route = payload['route'];
            }

            if (payload.containsKey('url')) {
              url = payload['url'];
              // Store the URL for WebView to use
              Get.find<AppController>()
                  .updateDeepLinksLink(url ?? 'item4gamer.com');
              Get.find<AppController>().updateDeepLinks(true);
            }

            // Use a short delay to ensure app is ready
            Future.delayed(const Duration(milliseconds: 100), () {
              try {
                Get.toNamed(route);
                Get.find<NotificationState>().markAsRead();
              } catch (e) {
                print("Navigation error: $e");
              }
            });
          }
        },
        onFcmTokenInitialize: (token) async {
          if (token != null && token.isNotEmpty) {
            print("FCM token initialized: ${token}");
            Get.find<NotificationServerServices>().updateMessagesToken(token);
            Get.find<NotificationServerServices>()
                .UpdateLastTimeMessagesToken(DateTime.now());
            Get.find<NotificationServerServices>().saveAccessToken(token);
            if (await Get.find<NotificationServerServices>()
                .getMessagesTokenServerSet()) {
              return;
            }
            try {
              // Send token to server if user is logged in
              if (await checkLoginStatus()) {
                String authToken = Get.find<AppController>().getAuthToken();
                if (authToken.isEmpty) {
                  authToken = await AuthService().getAccessToken() ?? '';
                }
                if (authToken.isNotEmpty) {
                  final result = await Get.find<NotificationServerServices>()
                      .SendActiveTokenNotification(token, authToken);
                  Get.find<NotificationServerServices>()
                      .UpdateMessagesTokenServerSet(result);
                  await Get.find<NotificationServerServices>()
                      .saveAccessToken(token);
                }
              }
            } catch (e) {
              print("Failed to send FCM token to server: $e");
            }
          }
        },
        onFcmTokenUpdate: (token) async {
          if (token != null && token.isNotEmpty) {
            print("FCM token updated: ${token}");
            Get.find<NotificationServerServices>().updateMessagesToken(token);
            Get.find<NotificationServerServices>()
                .UpdateLastTimeMessagesToken(DateTime.now());
            Get.find<NotificationServerServices>().saveAccessToken(token);
            Get.find<NotificationServerServices>()
                .UpdateMessagesTokenServerSet(false);
            // Send token to server if user is logged in
            try {
              if (await checkLoginStatus()) {
                String authToken = Get.find<AppController>().getAuthToken();
                if (authToken.isEmpty) {
                  authToken = await AuthService().getAccessToken() ?? '';
                }
                if (authToken.isNotEmpty) {
                  final result = await Get.find<NotificationServerServices>()
                      .SendActiveTokenNotification(token, authToken);
                  Get.find<NotificationServerServices>()
                      .UpdateMessagesTokenServerSet(result);
                  await Get.find<NotificationServerServices>()
                      .saveAccessToken(token);
                }
              }
            } catch (e) {
              print("Failed to send FCM token to server: $e");
            }
          }
        },
        handleInitialMessage: true,
        permissionGetter: (firebaseMessages) {
          return FirebaseMessaging.instance.requestPermission(
            alert: true,
            announcement: true,
            badge: true,
            carPlay: false,
            criticalAlert: true,
            provisional: true,
            sound: true,
          );
        },
        child: Obx(() {
          return FutureBuilder<bool>(
              future: Get.find<AppController>().getIsBrowserVisible(),
              builder: (context, isBrowserVisible) {
                if (isBrowserVisible.hasData && isBrowserVisible.data!) {
                  return getBaseWebViewTab();
                  // return WebViewTab(
                  //     webViewModel:
                  //         Provider.of<WebViewModel>(context, listen: false),
                  //     key: GlobalKey());
                  // return const Browser();
                } else {
                  return MaterialApp(
                    navigatorKey: Globals.navigatorKey,
                    scaffoldMessengerKey: Globals.scaffoldMessengerKey,
                    title: TITLE,
                    debugShowCheckedModeBanner: false,
                    onGenerateRoute: RouteGenerator.generateRoute,
                    theme: ThemeData(
                      visualDensity: VisualDensity.adaptivePlatformDensity,
                      textSelectionTheme: const TextSelectionThemeData(
                        selectionColor: Colors.blue,
                        cursorColor: Colors.blue,
                        selectionHandleColor: Colors.blue,
                      ),
                    ),
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [
                      Locale('en'), // English
                      Locale('fa'), // Farsi
                    ],
                    initialRoute: '/',
                    navigatorObservers: [
                      HeroController(),
                    ],
                  );
                }
              });
        }));
  }

  WebViewTab getBaseWebViewTab() {
    // Return the base WebViewTab instance if it exists
    if (BaseWebViewTab != null) {
      // Si el controlador de WebView existe pero necesita ser restablecido
      if (BaseWebViewTab!.webViewKey.currentState != null) {
        // Si el WebViewController es nulo, necesitamos recargar la página
        if (BaseWebViewTab!.webViewModel.webViewController == null) {
          WebViewModel webviewmodel =
              Provider.of<WebViewModel>(context, listen: false);
          // Asegurarse de que la URL no sea nula
          webviewmodel.url = WebUri(URL);
          BaseWebViewTab!.webViewModel = webviewmodel;
        } else {
          // Si el controlador existe, solo recargar la URL actual
          final currentUrl = BaseWebViewTab!.webViewModel.url;
          if (currentUrl != null && currentUrl.toString().isNotEmpty) {
            BaseWebViewTab!.webViewModel.webViewController?.reload();
          } else {
            // Si la URL actual no es válida, cargar la URL predeterminada
            BaseWebViewTab!.webViewModel.webViewController
                ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
          }
        }
      }
      return BaseWebViewTab!;
    }

    // Create a new WebViewTab if none exists
    WebViewModel webviewmodel =
        Provider.of<WebViewModel>(context, listen: false);
    try {
      if (mounted) {
        webviewmodel.url = WebUri(URL);
        webviewmodel.needsToCompleteInitialLoad = true;
      }
      Provider.of<WebViewModel>(context).updateWithValue(webviewmodel);
    } catch (e) {
      Provider.of<WebViewModel>(context)
          .updateWithValue(WebViewModel(url: WebUri(URL)));
      webviewmodel = Provider.of<WebViewModel>(context, listen: false);
    }
    BaseWebViewTab = WebViewTab(webViewModel: webviewmodel, key: webViewTabKey);
    // BaseWebViewTab!.webViewKey.currentState?.resetState(showLoading: true);
    print('New WebViewTab created');
    return BaseWebViewTab!;
  }
}
