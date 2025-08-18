import 'dart:convert';
import 'dart:io';
// import 'dart:ui_web';
import 'package:G4A4/browser/models/window_model.dart';
import 'package:G4A4/main.dart';
import 'package:G4A4/pages/frized_splash_screen.dart';
import 'package:G4A4/pages/internetError.dart';
import 'package:G4A4/pages/loading_service.dart';
import 'package:G4A4/services/auth_service.dart';
import 'package:G4A4/services/dataStore_service.dart';
import 'package:G4A4/browser/webview_tab.dart';
import 'package:G4A4/browser/models/webview_model.dart';
import 'package:G4A4/widgets/appWrapper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import 'package:G4A4/widgets/helpers.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  final String? token;
  final String? initialUrl;
  final bool? isFirebaseNOTAccessible;
  const HomePage({
    super.key,
    this.token,
    this.initialUrl,
    this.isFirebaseNOTAccessible,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String get token => widget.token ?? Get.find<AppController>().getAuthToken();
  bool get isFirebaseNOTAccessible =>
      widget.isFirebaseNOTAccessible ??
      Get.find<AppController>().getIsFirebaseAuthNOTAccessible();
  int currentIndex = 0;
  bool _isLoading = true;
  bool _showSplashOverlay = true;

  Future initializeAuthHeaders() async {
    try {
      final headers = await AuthService().getAccessLoginData();
      Get.find<AppController>().updateLoginResponseHeaders(jsonDecode(headers));
    } catch (e) {
      print('Error initializing auth headers: $e');
    }
  }

  Future _setupFirebaseMessaging() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.notification.request();
        if (result.isDenied) {
          print('Notification permission denied on Android');
        }
      }
    }
    if (Platform.isIOS) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('Notification permission denied on iOS');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _showSplashOverlay = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _showSplashOverlay = false;
              });
            }
          });
        }
      });
      if (FireBase && FireBaseMessages) {
        _setupFirebaseMessaging();
      }
    });
  }

  void linkAction(String link, WebViewModel webviewModel) async {
    if (mounted) {
      // // تنظیم آدرس به صفحه اصلی

      if (BaseWebViewTab != null) {
        // بارگذاری صفحه اصلی
        BaseWebViewTab!.webViewModel.webViewController
            ?.loadUrl(urlRequest: URLRequest(url: WebUri(link)));
      } else {
        // ایجاد WebViewTab جدید
        webviewModel.url = WebUri(link);
        BaseWebViewTab =
            WebViewTab(webViewModel: webviewModel, key: webViewTabKey);
      }

      Get.find<AppController>().updateIsBrowserVisible(true);

      Future.delayed(Duration(seconds: 1)).then(
        (value) async {
          // await BaseWebViewTab!.webViewModel.webViewController?.reload();
          final uri = await BaseWebViewTab!.webViewModel.webViewController
              ?.getOriginalUrl();
          if (uri.toString() != link) {
            BaseWebViewTab!.webViewModel.webViewController
                ?.loadUrl(urlRequest: URLRequest(url: WebUri(link)));
          } else if (link.isNotEmpty) {
            if (link.contains('/my-account') ||
                link.contains('/checkout/pay-out') ||
                link.contains('/profile')) {
              if (await AuthService().getIsGest() ||
                  !await AuthService().getIsLogin()) {
                await BaseWebViewTab!.webViewModel.webViewController
                    ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
                await BaseWebViewTab!.webViewModel.webViewController
                    ?.clearHistory();
                Globals.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            } else {
              await BaseWebViewTab!.webViewModel.webViewController
                  ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
            }
          } else {
            await BaseWebViewTab!.webViewModel.webViewController
                ?.clearHistory();
            await BaseWebViewTab!.webViewModel.webViewController
                ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
          }
        },
      ).whenComplete(() {
        Future.delayed(Duration(microseconds: 2500)).then((value) async {
          Get.find<AppController>().updateIsBrowserVisibleReturn(true);
        });
      });
    }
  }

  Container browser(String? link) {
    // final windowModel = Provider.of<WindowModel>(context, listen: false);
    final webviewModel = Provider.of<WebViewModel>(context, listen: true);
    // windowModel.restoreHiddenTabs();
    final url = link != null && link != ''
        ? link
        : widget.initialUrl ?? Get.find<AppController>().getIniUrl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      linkAction(url, webviewModel);
    });

    return Container();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      String initialUrl =
          widget.initialUrl ?? Get.find<AppController>().getIniUrl();
      String deepLink = Get.find<AppController>().getDeepLinksLink();
      bool useDeepLink = Get.find<AppController>().getDeepLinks();
      String link = useDeepLink
          ? deepLink
          : (isFirebaseNOTAccessible ? LOGIN_URL : initialUrl);

      return ErrorHandler(
        child: Stack(
          children: [
            Scaffold(
              // body: SafeArea(
              //   child: Browser(),
              // ),
              body: Stack(
                children: [
                  browser(link),
                ],
              ),
            ),
            if (_isLoading || _showSplashOverlay)
              // AnimatedOpacity(
              //   opacity: _showSplashOverlay ? 1.0 : 1.0,
              //   duration: const Duration(milliseconds: 500),
              //   child: buildLoadingScreen(),
              // ),
              AnimatedOpacity(
                opacity: _showSplashOverlay ? 1.0 : 1.0,
                duration: const Duration(milliseconds: 500),
                child: Builder(
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
                // onEnd: () {
                //   LoadingService.hide(); // وقتی animation تمام شد، hide
                // },
              ),
          ],
        ),
      );
    });
  }
}

class ErrorHandler extends StatelessWidget {
  final Widget child;

  const ErrorHandler({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }

  @override
  StatelessElement createElement() {
    return _ErrorHandlerElement(this);
  }
}

class _ErrorHandlerElement extends StatelessElement {
  _ErrorHandlerElement(ErrorHandler widget) : super(widget);

  @override
  void performRebuild() {
    try {
      super.performRebuild();
    } catch (e, stack) {
      print('Error in build: $e\n$stack');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(this.findRenderObject()!.attached
                  ? this.findAncestorStateOfType<NavigatorState>()!.context
                  : Globals.navigatorKey.currentContext!)
              .push(MaterialPageRoute(
            builder: (context) => const ErrorPage(returnAction: true),
          ));
        }
      });
    }
  }
}
