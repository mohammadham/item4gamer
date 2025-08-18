import 'package:Item4Gamer/browser/models/webview_model.dart';
import 'package:Item4Gamer/browser/webview_tab.dart';
import 'package:Item4Gamer/pages/loading_service.dart';
import 'package:Item4Gamer/services/UrlListManager.dart';
import 'package:Item4Gamer/services/dataStore_service.dart';
import 'package:Item4Gamer/widgets/appWrapper.dart';
import 'package:Item4Gamer/widgets/helpers.dart';
import 'package:Item4Gamer/widgets/myApp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:Item4Gamer/config.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import 'home.dart';
import 'package:Item4Gamer/main.dart';

class ErrorPage extends StatefulWidget {
  final String? returnPath;
  final bool?
      returnAction; // if is true return path is path of moudle and if is false return path is path of web page // default is true

  final String? errorCode;
  const ErrorPage(
      {this.returnPath, this.returnAction, this.errorCode, super.key});
  @override
  _ErrorPageState createState() => _ErrorPageState();
}

class _ErrorPageState extends State<ErrorPage> {
  bool _isRetrying = false;
  String get errorCode => widget.errorCode ?? '35';
  int _retryCount = 0; // شمارنده تلاش مجدد
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.hide(); // جایگزین child: buildLoadingScreen()
    });
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: RepaintBoundary(
          child: Container(
            width: screenWidth * 0.8, // 80% of screen width
            constraints: const BoxConstraints(
              maxWidth: 300, // Maximum width 300px
            ),
            margin: EdgeInsets.only(top: screenHeight * 0.2), // ~20% from top
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64 + screenWidth * 0.3, // 30% of screen width
                  height: 64 + screenWidth * 0.3,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  // child: const Icon(
                  //   Icons.wifi_off,
                  //   size: 64,
                  //   color: Colors.grey,
                  // ),
                  child: Image.asset(
                    INTERNET_ERROR_ICON,
                    width: 40 + screenWidth * 0.3,
                    height: 40 + screenWidth * 0.3,
                    cacheWidth:
                        (40 + screenWidth * 0.3).toInt() * 2, // Add caching
                    cacheHeight: (40 + screenWidth * 0.3).toInt() * 2,
                  ),
                ),
                const SizedBox(height: 24),
                // Text(
                //   'No Internet Connection',
                //   style: TextStyle(
                //     fontSize: 24 * MediaQuery.textScaleFactorOf(context),
                //     fontWeight: FontWeight.bold,
                //     color: Colors.black,
                //   ),
                // ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    '${AppLocalizations.of(context)!.checkInternet} ($errorCode)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontFamily: 'YekanBakh',
                      height: 1.55, // 21.7px line height
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isRetrying
                      ? null
                      : () async {
                          if (!mounted) return;

                          setState(() {
                            _isRetrying = true;
                          });
                          try {
                            bool isConnected = await ConnectivityService()
                                .checkInternetConnectionV();
                            if (!mounted)
                              return; // Check again after async operation
                            if (isConnected) {
                              _handleSuccessfulConnection();
                            } else {
                              showCustomSnackBar(context, 'checkInternet');
                              setState(() {
                                _isRetrying = false;
                              });
                            }
                          } catch (e) {
                            print('Error retrying connection: $e');
                            if (mounted) {
                              setState(() {
                                _isRetrying = false;
                              });
                              showCustomSnackBar(context, 'connectionError');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0071DF),
                    minimumSize: Size(
                      screenWidth * 0.4, // 40% of screen width
                      48, // Fixed height
                    ),
                    maximumSize: const Size(200, 48), // Max width 200px
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isRetrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          AppLocalizations.of(context)!.tryAgain,
                          style: const TextStyle(
                            fontSize: 14,
                            // 14 * MediaQuery.textScaleFactorOf(context),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'YekanBakh',
                            color: Colors.white,
                            height: 1.55, // 21.7px line height
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSuccessfulConnection() {
    try {
      // جلوگیری از لوپ: اگر چند بار تلاش شده و هنوز خطا داریم، به صفحه اصلی برو
      // (مثلاً با یک شمارنده یا flag ساده)
      if (_retryCount > 3) {
        _navigateToHome();
        return;
      }
      _retryCount++;
      // اگر امکان بازگشت به صفحه قبلی وجود دارد
      if (Globals.navigatorKey.currentState!.canPop()) {
        Globals.navigatorKey.currentState!.pop(context);
        return;
      }
    } catch (e) {
      print('Error popping navigator: $e');
    }

    final return_path = widget.returnPath ?? '';
    final return_action = widget.returnAction ?? true;

    // اگر مسیر بازگشت مشخص شده و نوع بازگشت به مسیر برنامه است
    if (return_path.isNotEmpty && return_action) {
      Globals.navigatorKey.currentState?.pushReplacementNamed(return_path);
      return;
    }

    // اگر مسیر بازگشت مشخص شده و نوع بازگشت به صفحه وب است
    if (return_path.isNotEmpty && !return_action) {
      _navigateToWebView(return_path);
      return;
    }

    // اگر نوع بازگشت به صفحه وب است اما مسیر مشخص نشده
    if (!return_action) {
      final lastVisitedUrl = Get.find<AppController>().getLastVisitedUrl();
      _navigateToWebView(lastVisitedUrl);
      return;
    }

    // در غیر این صورت به صفحه اصلی برنامه برگرد
    _navigateToHome();
  }

  void _navigateToWebView(String url) async {
    if (url.isEmpty || url.contains('about:blank')) {
      url = URL; // یا هر صفحه پیش‌فرض معتبر
    }

    // استفاده از WebViewTab به جای CustomWebView
    if (BaseWebViewTab != null) {
      // بازنشانی وضعیت WebViewTab
      if (BaseWebViewTab!.webViewKey.currentState != null) {
        BaseWebViewTab!.webViewKey.currentState!.resetState(showLoading: true);
      }

      if (BaseWebViewTab!.webViewModel.webViewController != null) {
        WebUri? tUrl =
            await BaseWebViewTab!.webViewModel.webViewController?.getUrl();
        if (tUrl.toString().isNotEmpty &&
            tUrl.toString() == url &&
            !url.contains('about:blank')) {
          await BaseWebViewTab!.webViewModel.webViewController!.reload();
        } else if (await BaseWebViewTab!.webViewModel.webViewController
                ?.canGoBack() ??
            false) {
          // await BaseWebViewTab!.webViewModel.webViewController?.goBack();
          final copyBackForwardList = await BaseWebViewTab!
              .webViewModel.webViewController
              ?.getCopyBackForwardList();
          if (copyBackForwardList != null) {
            int _index = copyBackForwardList.currentIndex ?? 0;
            int currentIndex = _index;
            WebUri? backUrl = null;
            while (_index >= 0) {
              backUrl = copyBackForwardList.list?.elementAt(_index).url;
              if (backUrl.isBlank != true) {
                if (!backUrl.toString().contains('about:blank') &&
                    UrlListManager.getUrlType(backUrl.toString()) !=
                        'PAYMENT') {
                  // await BaseWebViewTab!.webViewModel.webViewController?.goTo(
                  //     historyItem: copyBackForwardList.list!
                  //         .elementAt(copyBackForwardList.currentIndex!));
                  break;
                }
              }
              _index--;
            }
            _index = _index - currentIndex;
            await BaseWebViewTab!.webViewModel.webViewController
                ?.goBackOrForward(steps: _index);
          } else {
            await BaseWebViewTab!.webViewModel.webViewController
                ?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
          }
        } else {
          if (tUrl.toString().isNotEmpty &&
              tUrl.toString() != url &&
              url.isNotEmpty) {
            await BaseWebViewTab!.webViewModel.webViewController
                ?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
          } else {
            await BaseWebViewTab!.webViewModel.webViewController
                ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
          }
        }
        // فعال‌سازی نمایش مرورگر
        Get.find<AppController>().updateIsBrowserVisible(true);
        Future.delayed(Duration(milliseconds: 100), () {
          Get.find<AppController>().updateIsBrowserVisibleReturn(true);
        });
        // بستن صفحه خطا
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }
      // به‌روزرسانی URL
      WebViewModel webViewModel =
          Provider.of<WebViewModel>(context, listen: false);
      webViewModel.url = WebUri(url);

      if (BaseWebViewTab!.webViewModel.webViewController != null) {
        // Verificar nuevamente que la URL sea válida
        final webUri = WebUri(url);
        if (webUri.toString().isNotEmpty) {
          BaseWebViewTab!.webViewModel.webViewController!
              .loadUrl(urlRequest: URLRequest(url: webUri));
        } else {
          print("URL inválida: $url");
          // Cargar URL predeterminada como fallback
          BaseWebViewTab!.webViewModel.webViewController!
              .loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
        }
      }

      // فعال‌سازی نمایش مرورگر
      Get.find<AppController>().updateIsBrowserVisible(true);
      Future.delayed(Duration(milliseconds: 100), () {
        Get.find<AppController>().updateIsBrowserVisibleReturn(true);
      });

      // بستن صفحه خطا
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      // ایجاد یک WebViewTab جدید اگر وجود ندارد
      try {
        WebViewModel webViewModel =
            Provider.of<WebViewModel>(context, listen: false);
        webViewModel.url = WebUri(url.isNotEmpty ? url : URL);
        // جلوگیری از لوپ: اگر url باز هم about:blank شد، به صفحه اصلی برو
        if (webViewModel.url.toString().contains('about:blank')) {
          _navigateToHome();
          return;
        }

        BaseWebViewTab =
            WebViewTab(webViewModel: webViewModel, key: webViewTabKey);

        // Activar la visualización del navegador
        Get.find<AppController>().updateIsBrowserVisible(true);
        Future.delayed(Duration(milliseconds: 100), () {
          Get.find<AppController>().updateIsBrowserVisibleReturn(true);
        });

        // Cerrar la página de error
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        print("Error al crear WebViewTab: $e");
        // Manejar el error, tal vez redirigir a la página de inicio
        _navigateToHome();
      }
    }
  }

  void _navigateToHome() {
    // بازگشت به صفحه اصلی برنامه
    Globals.navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (context) => const MyApp()),
    );
  }
}
