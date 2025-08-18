import 'package:Item4Gamer/config.dart';
import 'package:Item4Gamer/model/notification_state.dart';
import 'package:Item4Gamer/pages/home.dart';
import 'package:Item4Gamer/pages/internetError.dart';
import 'package:Item4Gamer/pages/loading_service.dart';
import 'package:Item4Gamer/pages/login.dart';
import 'package:Item4Gamer/services/auth_service.dart';
import 'package:Item4Gamer/services/connectivity_service.dart';
import 'package:Item4Gamer/services/dataStore_service.dart';
import 'package:Item4Gamer/services/notification_server_Services.dart';
import 'package:Item4Gamer/widgets/helpers.dart';
import 'package:Item4Gamer/widgets/routeGenerator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoadingComplete = false;
  bool _showSplashOverlay = true;

  String token = '';
  String? _deepLink;

  @override
  void initState() {
    super.initState();
    _startSplashScreen();
  }

  Future<void> _startSplashScreen() async {
    // // Show splash for 3 seconds
    if (mounted) {
      setState(() {
        _showSplashOverlay = true;
      });
    }
    // Initialize core functionality after splash
    Future.microtask(() {
      _setupDeepLinkHandling();
    });

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        // statusBarColor: STATUS_BAR_COLOR,
        systemNavigationBarColor: SYSTEM_NAVIGATION_BAR_COLOR,
        // statusBarIconBrightness: STATUS_BAR_ICON_BRIGHTNESS,
        systemNavigationBarIconBrightness:
            SYSTEM_NAVIGATION_BAR_ICON_BRIGHTNESS,
      ),
    );
    if (mounted) {
      setState(() {
        _isLoadingComplete = true;
        // _showSplashOverlay = false;
      });
    }
  }

  Future<void> _setupDeepLinkHandling() async {
    await deepLinkService.initialize();
    // Only start listening for deep links after splash screen
    Future.delayed(Duration(seconds: 3), () {
      deepLinkService.deepLinkStream.listen(
        (String link) {
          if (mounted) {
            setState(() {
              _deepLink = link;
            });
            _handleDeepLink(link);
          }
        },
        onError: (error) {
          debugPrint('Deep link stream error: $error');
        },
      );
    });
  }

  void _handleDeepLink(String link) async {
    if (!mounted) return;

    try {
      Get.find<AppController>().updateDeepLinks(true);

      // Debug print
      print('Deep link received: $link');
      print('Auth token: ${Get.find<AppController>().getAuthToken()}');
      bool isGest = (Get.find<AppController>().getAuthToken() == '' ||
              (await AuthService().getAccessToken()) == '') ||
          await AuthService().getIsGest();
      if (isGest) {
        if (!await AuthService().getIsGest()) {
          await AuthService().saveAccessGest();
        }
      }
      if (link == 'login') {
        if (Get.find<AppController>().getAuthToken().isNotEmpty) {
          Globals.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
        Globals.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } else if (link.isNotEmpty) {
        // Debug the arguments
        final args = {
          'isFirebaseNOTAccessible': false,
          'initialUrl': link,
          'token': Get.find<AppController>().getAuthToken(),
        };
        print('Passing arguments to home: $args');
        Get.find<AppController>().updateDeepLinksLink(link);
        // Get.find<AppController>().updateIniUrl(link);
        Globals.navigatorKey.currentState
            ?.pushReplacementNamed('/home', arguments: args);
      }
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  @override
  void dispose() {
    // _deepLinkService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationState()),
      ],
      child: MaterialApp(
        title: TITLE,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
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
        onGenerateRoute: RouteGenerator.generateRoute,
        builder: (context, child) {
          // Add global performance optimizations
          return ScrollConfiguration(
            behavior: ScrollBehavior().copyWith(
              physics: const ClampingScrollPhysics(),
              overscroll: false,
            ),
            child: Directionality(
              textDirection: Localizations.localeOf(context).languageCode == 'fa' ? TextDirection.rtl:TextDirection.ltr,
              child: _buildMainContent(context), // ساختار بدون Stack حفظ شده
            ),
          );
        },
        initialRoute: '/splash',
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    // نمایش لودینگ اگر کامل نشده
    if (!_isLoadingComplete || _showSplashOverlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LoadingService.show(context); // جایگزین buildLoadingScreen
      });
    }
    return FutureBuilder<bool>(
      future: ConnectivityService().checkInternetConnectionV(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // وقتی آماده شد، hide کنید
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // LoadingService.hide();
            if (_showSplashOverlay && mounted) {
              setState(() => _showSplashOverlay = false);
            }
          });

          if (!snapshot.data!) return const ErrorPage();
          if (isWebViewWithoutLogin) return HomePage();

    return FutureBuilder<bool>(
    future: checkLoginStatus(),
    builder: (context, loginSnapshot) {
    if (loginSnapshot.connectionState == ConnectionState.done) {
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   LoadingService.hide();
      // });

      if (!loginSnapshot.hasData) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          LoadingService.show(context); // اگر هنوز data ندارد، show
        });
        return const SizedBox
            .shrink(); // placeholder خالی به جای buildLoadingScreen
      }

      if (loginSnapshot.data!) {
        AuthService()
            .saveAccessToken(Get.find<AppController>().getAuthToken());
        Get.find<AppController>()
            .updateIsFirebaseAuthNOTAccessible(false);
        Get.find<AppController>().updateIniUrl(URL);
        return HomePage();
      }

      if (apiSystemProblem) return const ErrorPage();

      return FutureBuilder<bool>(
        future: checkGestStatus(),
        builder: (context, gestSnapshot) {
          if (!gestSnapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              LoadingService.show(context);
            });
            return const SizedBox.shrink(); // placeholder
          }

          if (gestSnapshot.data!) {
            Get.find<AppController>()
                .updateIsFirebaseAuthNOTAccessible(false);
            Get.find<AppController>().updateIniUrl(URL);
            return const HomePage();
          }

          AuthService().clearAccessToken();
          if ((FireBaseAuth && !isFirebaseAccessible) ||
              !LOGIN_WITH_API) {
            Get.find<AppController>().updateIsFirebaseAuthNOTAccessible(
                FireBaseAuth && !isFirebaseAccessible);
            Get.find<AppController>().updateIniUrl(LOGIN_URL);
            return HomePage();
          }

          Get.find<NotificationServerServices>().ClearFCMToken();
          return const LoginRouter();
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.show(context);
    });
    return const SizedBox.shrink(); // placeholder در حین waiting
            },
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          LoadingService.show(context);
        });
        return const SizedBox.shrink(); // placeholder
      },
    );
  }
}
