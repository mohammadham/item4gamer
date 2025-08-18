import 'dart:async';
import 'package:Item4Gamer/browser/models/webview_model.dart';
import 'package:Item4Gamer/browser/models/window_model.dart';
import 'package:Item4Gamer/browser/webview_tab.dart';
import 'package:Item4Gamer/main.dart';
import 'package:Item4Gamer/pages/loading_service.dart';
import 'package:Item4Gamer/services/dataStore_service.dart';
import 'package:Item4Gamer/services/notification_server_Services.dart';
import 'package:Item4Gamer/widgets/appWrapper.dart';
import 'package:Item4Gamer/widgets/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:Item4Gamer/pages/login.dart';
import 'package:Item4Gamer/config.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

// Import Pinput and SmartAuth packages
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

/// SMS retriever implementation that uses the SMS User Consent API.
/// This is based on the example at:
/// https://github.com/Tkko/Flutter_PinPut/blob/master/example/lib/demo/user_consent_api_example.dart
class SmsRetrieverImpl implements SmsRetriever {
  const SmsRetrieverImpl(this.smartAuth);
  final SmartAuth smartAuth;

  @override
  Future<void> dispose() {
    smartAuth.removeSmsRetrieverApiListener();
    return smartAuth.removeUserConsentApiListener();
  }

  @override
  Future<String?> getSmsCode() async {
    final res = await smartAuth.getSmsWithUserConsentApi();
    if (res.hasData) {
      return res.requireData.code!;
    }
    return null;
  }

  @override
  bool get listenForMultipleSms => false;
}

class LoginConfirmationPage extends StatefulWidget {
  final String phoneNumber;

  const LoginConfirmationPage({
    super.key,
    required this.phoneNumber,
  });

  @override
  _LoginConfirmationPageState createState() => _LoginConfirmationPageState();
}

class _LoginConfirmationPageState extends State<LoginConfirmationPage> {
  late DateTime _startDate;
  int _isTryTwo = 0;
  bool _resend = false;
  final _service = AuthService();
  bool _isLoading = false;
  String _message = '';
  int _numcounters = 120;
  int _remainingTime = 120;
  late Timer _timer;
  int _backButtonCount = 0;
  Timer? _backButtonTimer;

  // Remove the individual OTP TextField controllers and focus nodes,
  // and instead create a single controller for Pinput.
  final TextEditingController _pinController = TextEditingController();

  // Instance for SMS retrieval (using the SMS User Consent API)
  late final SmsRetrieverImpl smsRetrieverImpl;

  @override
  void initState() {
    super.initState();
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
    _startDate = DateTime.now();
    _startTimer();
    // Initialize the SMS retriever implementation with SmartAuth.
    smsRetrieverImpl = SmsRetrieverImpl(SmartAuth.instance);
  }

  @override
  void dispose() {
    _pinController.dispose();
    // Dispose the SMS retriever (no need to await here)
    smsRetrieverImpl.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _sendTokenAfterLogin(String authToken) async {
    try {
      final token =
          Get.find<NotificationServerServices>().getMessagesToken() ?? '';
      if (token.isNotEmpty) {
        // final result = await compute(_sendTokenNotification, {
        //   'token': token,
        //   'authToken': authToken,
        //   // Don't include any service references or non-serializable objects
        // });
        final result = await Get.find<NotificationServerServices>()
            .SendActiveTokenNotification(token, authToken);

        Get.find<NotificationServerServices>()
            .UpdateMessagesTokenServerSet(result);
      } else {
        print('fail in send FCM token to server');
      }
    } catch (e) {
      print("Failed to send token notification: $e");
      return;
    }
  }

  Future<bool> _sendTokenNotification(Map<String, String> data) async {
    bool result = await Get.find<NotificationServerServices>()
        .SendActiveTokenNotification(
      data['token']!,
      data['authToken']!,
    );
    // Get.find<NotificationServerServices>().UpdateMessagesTokenServerSet(result);
    return result;
  }

  void _startTimer() {
    // Timer callback updates remaining time every second.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(_startDate).inSeconds;
      final remaining = _numcounters - elapsed;
      if (remaining > 0) {
        // Update only the remaining time.
        setState(() {
          _remainingTime = remaining;
        });
      } else {
        // When time is up, update flags and cancel the timer.
        _timer.cancel();
        if (mounted) {
          setState(() {
            _remainingTime = 0;
            // _isTryTwo +=1 ;
            _resend = true;
          });
        }
      }
    });
  }

  // A getter to format the remaining time.
  String get formattedTime {
    final minutes = (_remainingTime / 60).floor();
    final seconds = _remainingTime % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _login() async {
    final String verificationCode = _pinController.text.trim();

    if (verificationCode.length != 5) {
      showCustomSnackBar(context, 'enterCompleteCode');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    bool isSuccess = false;
    if (!LOGIN_WITH_API) {
      try {
        final ftoken = await _service.fVerifyOtp(verificationCode);
        final response = await _service.oneClickLogin(
          phoneNumber: widget.phoneNumber,
          countryCode: '+98',
          ftoken: ftoken ?? '',
          otp: verificationCode,
        );
        setState(() {
          _message = 'Login successful: ${response['data']['access_token']}';
        });
        isSuccess = response['success'];
        if (isSuccess == true) {
          await AuthService().saveAccessToken(response['data']['access_token']);
          Get.find<AppController>().updateLoginResponseCookiesSet(false);
          AuthService().updateIsLoginResponseCookiesSet(false);
          // Initialize FCM immediately after login
          if (FireBase && FireBaseMessages) {
            try {
              await _sendTokenAfterLogin(response['data']['access_token']);
            } catch (e) {
              print("FCM setup after login failed: $e");
            }
          }
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          showCustomSnackBar(context, 'incorrectCode');
          if (mounted) {
            setState(() {
              _isTryTwo += 1;
            });
          }
        }
      } catch (e) {
        setState(() {
          _message = 'Failed to login: $e';
        });
        showCustomSnackBar(context, 'incorrectCode');
        if (mounted) {
          setState(() {
            _isTryTwo += 1;
          });
        }
      }
    } else {
      try {
        final responseData = await AuthService().sendOtpForOneClickLogin(
            phoneNumber: widget.phoneNumber, otp: verificationCode);
        final response = responseData['body'];
        Get.find<AppController>()
            .updateLoginResponseHeaders(responseData['headers']);
        await AuthService().saveAccessTokenData(responseData['headers']);
        setState(() {
          _message = 'Login successful: ${response['data']['access_token']}';
        });
        isSuccess = response['success'];
        await AuthService().saveAccessToken(response['data']['access_token']);
        if (isSuccess == true) {
          await AuthService().saveAccessToken(response['data']['access_token']);
          Get.find<AppController>()
              .updateAuthToken(response['data']['access_token']);
          Get.find<AppController>().updateLoginResponseCookiesSet(false);
          AuthService().updateIsLoginResponseCookiesSet(false);
          // Initialize FCM immediately after login
          if (FireBase && FireBaseMessages) {
            try {
              await _sendTokenAfterLogin(response['data']['access_token']);
            } catch (e) {
              print("FCM setup after login failed: $e");
            }
          }
          if (mounted) {
            // // اطمینان از تنظیم کوکی‌ها قبل از نمایش مرورگر
            // if (BaseWebViewTab != null &&
            //     BaseWebViewTab!.webViewKey.currentState != null) {
            //   // تنظیم کوکی‌ها
            //   await BaseWebViewTab!.webViewKey.currentState!.setCookies();
            //
            //   // بازنشانی وضعیت بدون نمایش صفحه بارگذاری
            //   BaseWebViewTab!.webViewKey.currentState!
            //       .resetState(showLoading: false);
            //
            //   // بارگذاری مجدد صفحه برای اعمال کوکی‌ها
            //   await BaseWebViewTab!.webViewModel.webViewController?.reload();
            //   // نمایش مرورگر
            //   Get.find<AppController>().updateIsBrowserVisible(true);
            //
            //   // تأخیر کوتاه برای اطمینان از اعمال تغییرات
            //   await Future.delayed(Duration(milliseconds: 500));
            //
            //   // بازگشت به صفحه اصلی
            //   Navigator.pushReplacementNamed(context, '/home');
            // }
            WebViewModel webviewModel =
                Provider.of<WebViewModel>(context, listen: false);

            // پاکسازی کامل تاریخچه و آدرس‌های قبلی
            Get.find<AppController>().lastVisitedUrl('');

            // تنظیم آدرس به صفحه اصلی
            webviewModel.url = WebUri(URL);

            if (BaseWebViewTab != null) {
              if (BaseWebViewTab!.webViewKey.currentState != null) {
                // پاکسازی کوکی‌ها و تاریخچه
                await CookieManager.instance().deleteAllCookies();
                BaseWebViewTab!.webViewModel.webViewController?.clearHistory();

                // بازنشانی کامل وضعیت
                BaseWebViewTab!.webViewKey.currentState!
                    .resetState(showLoading: true);
              }

              // بارگذاری صفحه اصلی
              BaseWebViewTab!.webViewModel.webViewController
                  ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
            } else {
              // ایجاد WebViewTab جدید
              BaseWebViewTab =
                  WebViewTab(webViewModel: webviewModel, key: webViewTabKey);
            }

            Get.find<AppController>().updateIsBrowserVisible(true);
            Future.delayed(Duration(seconds: 1)).then(
              (value) async {
                await BaseWebViewTab!.webViewModel.webViewController
                    ?.reload()
                    .then(
                  (value) {
                    Future.delayed(Duration(seconds: 1)).then((value) async {
                      Get.find<AppController>()
                          .updateIsBrowserVisibleReturn(true);
                    });
                  },
                );
              },
            );

            // Navigate back to home and add a new tab
            // try {
            //   // Check if '/home' exists in the navigation stack
            //   bool homeRouteExists = false;
            //   Globals.navigatorKey.currentState?.popUntil((route) {
            //     if (route.settings.name == '/home') {
            //       homeRouteExists = true;
            //       return true;
            //     }
            //     return false;
            //   });

            //   if (homeRouteExists) {
            //     // If '/home' exists, add a new tab
            //     // Navigator.popUntil(context, ModalRoute.withName('/home'));
            //     final windowModel =
            //         Provider.of<WindowModel>(context, listen: false);
            //     windowModel.addTab(WebViewTab(
            //       key: GlobalKey(),
            //       webViewModel:
            //           WebViewModel(url: WebUri(URL + '?utm_source=app')),
            //     ));
            //   } else {
            //     final windowModel =
            //         Provider.of<WindowModel>(context, listen: false);
            //     windowModel.closeAllTabs();
            //     windowModel.addTab(WebViewTab(
            //       key: GlobalKey(),
            //       webViewModel: WebViewModel(url: WebUri(URL)),
            //     ));
            //     // If '/home' doesn’t exist, navigate to '/gestHome'
            //     Globals.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            //       '/home',
            //       (route) => false,
            //       arguments: {
            //         'token': response['data']['access_token'],
            //         'initialUrl': URL,
            //       },
            //     );
            //   }
            // } catch (e) {
            //   Navigator.pushNamedAndRemoveUntil(
            //     context,
            //     '/home',
            //     (route) => false,
            //     arguments: {
            //       'token': response['data']['access_token'],
            //       'initialUrl': URL,
            //     },
            //   );
            // }
          }
        } else {
          showCustomSnackBar(context, 'incorrectCode');
          if (mounted) {
            setState(() {
              _isTryTwo += 1;
            });
          }
        }
      } catch (e) {
        setState(() {
          _message = 'Failed to login: $e';
        });
        showCustomSnackBar(context, 'incorrectCode');
        if (mounted) {
          setState(() {
            _isTryTwo += 1;
          });
        }
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _reSend() async {
    setState(() {
      _isLoading = true;
    });
    var isSuccess = await AuthService().resendOtp(widget.phoneNumber);
    try {
      // print(isSuccess);
      if (isSuccess.isNotEmpty && isSuccess['code'] == "1") {
        if (mounted) {
          setState(() {
            _numcounters = _numcounters + 60;
            _startDate = DateTime.now();
            _resend = false;
          });
          _startTimer();
        }
      } else {
        showCustomSnackBar(context, 'resendError');
      }
    } catch (e) {
      showCustomSnackBar(context, 'resendError');
    }
    setState(() {
      _isLoading = false;
      _isTryTwo += 1;
    });
  }

  Future<void> _return() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Future<bool> _handleBackButton() async {
    return _confirmExit();
  }

  bool _confirmExit() {
    if (_backButtonCount == 0) {
      _backButtonCount++;
      _backButtonTimer?.cancel();
      _backButtonTimer =
          Timer(const Duration(seconds: 2), () => _backButtonCount = 0);
      showCustomSnackBar(context, 'backButtonWarning');
      return false;
    }
    _backButtonTimer?.cancel();
    _backButtonCount = 0;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.phoneNumber;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final fieldWidth = (screenWidth - 80) / 5;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.hide(); // جایگزین child: buildLoadingScreen()
    });
    return WillPopScope(
      onWillPop: _handleBackButton,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // SizedBox(height: screenHeight * 0.05),
                        Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: screenWidth * 0.9,
                              height: isKeyboardOpen
                                  ? contentViewAfterKeyboardOpen(context) * 0.48
                                  : screenHeight * 0.55,
                              alignment: Alignment.center,
                              child: Image.asset(
                                LOGO,
                                width:
                                    ((screenWidth * 0.30 > screenHeight * 0.4)
                                        ? screenHeight * 0.1
                                        : screenWidth * 0.30),
                                height:
                                    ((screenWidth * 0.30 > screenHeight * 0.4)
                                        ? screenHeight * 0.1
                                        : screenWidth * 0.30),
                              ),
                            ),
                            if (_isTryTwo > 1)
                              Positioned(
                                left: 0,
                                top: 0,
                                child: TextButton(
                                  onPressed: _return,
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .editPhoneNumber,
                                    style: const TextStyle(
                                      fontFamily: 'YekanBakh',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.55,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Text Section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppLocalizations.of(context)!
                                  .enterVerificationCode,
                              style: TextStyle(
                                fontFamily: 'YekanBakh',
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AppLocalizations.of(context)!
                                  .verificationCodeSent(number),
                              style: TextStyle(
                                fontFamily: 'YekanBakh',
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // OTP Input using Pinput with SMS autofill support.
                        Pinput(
                          controller: _pinController,
                          length: 5,
                          smsRetriever:
                              smsRetrieverImpl, // integrates SMS User Consent API (Android) and autofill (iOS)
                          onCompleted: (pin) {
                            // Optionally, trigger login automatically when input is complete.
                            _login();
                          },
                          // You can customize the themes as needed.
                          defaultPinTheme: PinTheme(
                            width: fieldWidth,
                            height: fieldWidth,
                            textStyle: TextStyle(
                                fontSize: 20,
                                color: const Color.fromRGBO(30, 60, 87, 1),
                                fontWeight: FontWeight.w600),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color:
                                      const Color.fromRGBO(234, 239, 243, 1)),
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFFF5F5F5),
                            ),
                          ),
                        ),

                        SizedBox(height: !_resend ? 20 : 15),

                        // Timer or Resend button
                        // if (!isKeyboardOpen)
                        SizedBox(
                          child: Center(
                            child: !_resend
                                ? Text(
                                    AppLocalizations.of(context)!
                                        .resendCode(formattedTime),
                                    style: TextStyle(
                                      fontFamily: 'YekanBakh',
                                      fontSize: screenWidth * 0.035,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  )
                                : TextButton(
                                    child: Text(
                                      AppLocalizations.of(context)!
                                          .resendCodeTo(widget.phoneNumber),
                                      style: TextStyle(
                                        fontFamily: 'YekanBakh',
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[300],
                                      ),
                                    ),
                                    onPressed: !_isLoading ? _reSend : null,
                                  ),
                          ),
                        ),
                        if (!isKeyboardOpen) const SizedBox(height: 15),

                        // Submit Button
                        if (!isKeyboardOpen)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0071DF),
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.02,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.confirm,
                                style: TextStyle(
                                  fontFamily: 'YekanBakh',
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
