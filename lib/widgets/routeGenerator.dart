import 'package:G4A4/config.dart';
import 'package:G4A4/main.dart';
import 'package:G4A4/pages/frized_splash_screen.dart';
import 'package:G4A4/pages/loading_service.dart';
import 'package:G4A4/services/auth_service.dart';
import 'package:G4A4/services/dataStore_service.dart';
import 'package:G4A4/services/notification_server_Services.dart';
import 'package:G4A4/widgets/helpers.dart';
import 'package:G4A4/widgets/myApp.dart';
import 'package:flutter/material.dart';
import 'package:G4A4/pages/splash_screen.dart';
import 'package:G4A4/pages/home.dart';
import 'package:G4A4/pages/login.dart';
import 'package:G4A4/pages/internetError.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';

class RouteGenerator {
  // Create a static map to cache page instances
  static final Map<String, Widget> _cachedPages = {};

  // Helper method to get or create a cached page
  static Widget _getCachedPage(String routeName, Widget Function() builder) {
    if (!_cachedPages.containsKey(routeName)) {
      _cachedPages[routeName] = builder();
    }
    return _cachedPages[routeName]!;
  }

  // Method to clear specific cached pages (e.g., when logging out)
  static void clearCachedPages({List<String>? except}) {
    if (except != null) {
      _cachedPages.removeWhere((key, _) => !except.contains(key));
    } else {
      _cachedPages.clear();
    }
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // قبل از ساخت صفحه، لودینگ show کنید
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.show(Globals.navigatorKey.currentContext!);
    });
    switch (settings.name) {
      case '/splash':
        // Splash screen should always be fresh, not cached
        return MaterialPageRoute(
          builder: (_) {
            FlutterNativeSplash.remove();
            return const SplashScreen(
              typeOfSplashScreen: LOGO_MOTION_TYPE,
              splashTimeout: LOGO_MOTION_TIME,
              exitInEnd: true,
              returnRoutePath: '/sphome',
            );
          },
          settings: settings,
        );

      case '/login':
        // Login page should also be fresh each time
        return MaterialPageRoute(
          builder: (context) {
            // Clear cached pages when logging in (except splash)
            clearCachedPages(except: ['/splash']);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              AuthService().clearAccessToken();
              Get.find<NotificationServerServices>().ClearFCMToken();
            });

            return LoginRouter();
          },
          settings: settings,
        );

      case '/gestHome':
        // Use cached page for guest home
        return MaterialPageRoute(
          builder: (context) {
            final args = settings.arguments as Map<String, dynamic>?;

            return _getCachedPage(
                '/gestHome',
                () => HomePage(
                      isFirebaseNOTAccessible:
                          args?['isFirebaseNOTAccessible'] ?? false,
                      initialUrl: args?['initialUrl'] ?? URL,
                    ));
          },
          settings: settings,
          maintainState: true, // Important: maintain state when navigating away
        );

      case '/home':
        return MaterialPageRoute(
          builder: (context) {
            // Use AutomaticKeepAliveClientMixin in HomePage
            return FutureBuilder<bool>(
              future: checkLoginStatus(),
              builder: (context, tokenSnapshot) {
                if (tokenSnapshot.hasData) {
                  if (tokenSnapshot.data!) {
                    final args = settings.arguments as Map<String, dynamic>?;
                    final initialUrl = args?['initialUrl'] as String? ?? URL;

                    AuthService().saveAccessToken(
                        Get.find<AppController>().getAuthToken());
                    Get.find<AppController>()
                        .updateIsFirebaseAuthNOTAccessible(false);
                    Get.find<AppController>().updateIniUrl(URL);

                    // Cache the HomePage instance
                    return _getCachedPage(
                        '/home',
                        () => HomePage(
                              isFirebaseNOTAccessible:
                                  args?['isFirebaseNOTAccessible'] ?? false,
                              token: args?['token'] ??
                                  Get.find<AppController>().getAuthToken(),
                              initialUrl: initialUrl,
                            ));
                  }

                  if (!tokenSnapshot.data!) {
                    final args = settings.arguments as Map<String, dynamic>?;
                    return FutureBuilder<bool>(
                      future: checkGestStatus(),
                      builder: (context, gestSnapshot) {
                        if (gestSnapshot.hasData) {
                          if (gestSnapshot.data!) {
                            Get.find<AppController>()
                                .updateIsFirebaseAuthNOTAccessible(false);
                            Get.find<AppController>().updateIniUrl(URL);

                            // Cache the HomePage instance for guest
                            return _getCachedPage(
                                '/home_guest', () => const HomePage());
                          }

                          if (!gestSnapshot.data!) {
                            if ((args?['initialUrl'] as String?) != null &&
                                (args?['initialUrl'] as String?)!.isNotEmpty) {
                              try {
                                AuthService().saveAccessGest();

                                // Cache the HomePage instance for this specific URL
                                final cacheKey = '/home_${args?['initialUrl']}';
                                return _getCachedPage(
                                    cacheKey,
                                    () => HomePage(
                                          isFirebaseNOTAccessible: args?[
                                                  'isFirebaseNOTAccessible'] ??
                                              false,
                                          initialUrl:
                                              args?['initialUrl'] ?? URL,
                                        ));
                              } catch (e) {
                                print('Guest login error: $e');
                                showCustomSnackBar(context, 'guestLoginError');
                              }
                            }

                            AuthService().clearAccessToken();
                            Get.find<NotificationServerServices>()
                                .ClearFCMToken();
                            return const LoginRouter();
                          }
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          LoadingService.show(
                              context); // جایگزین child: buildLoadingScreen()
                        });
                        return const SizedBox.shrink();
                      },
                    );
                  }
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  LoadingService.show(
                      context); // جایگزین child: buildLoadingScreen()
                });
                return const SizedBox.shrink();
              },
            );
          },
          settings: settings,
          maintainState: true, // Important: maintain state when navigating away
        );
      // case '/browser':
      //   return MaterialPageRoute(
      //     builder: (_) => Browser(),
      //     settings: settings,
      //   );
      case '/error':
        return MaterialPageRoute(
          builder: (_) => const ErrorPage(),
          settings: settings,
        );

      case '/sphome':
      case '/':
        return MaterialPageRoute(
          builder: (_) => const MyApp(),
          settings: settings,
        );
      case '/friza':
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: RepaintBoundary(
              child: IgnorePointer(
                child: const SplashScreenFrize(
                  splashTimeFrized: 0.9,
                  type: LOGO_MOTION_TYPE,
                ),
              ),
            ),
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
              body:
                  Center(child: Text('No route defined for ${settings.name}'))),
          settings: settings,
        );
    }
  }
}
