import 'dart:async';
import 'dart:math';

import 'package:Item4Gamer/browser/models/webview_model.dart';
import 'package:Item4Gamer/browser/models/window_model.dart';
import 'package:Item4Gamer/browser/webview_tab.dart';
import 'package:Item4Gamer/main.dart';
import 'package:Item4Gamer/pages/loading_service.dart';
import 'package:Item4Gamer/services/dataStore_service.dart';
import 'package:Item4Gamer/widgets/appWrapper.dart';
import 'package:Item4Gamer/widgets/helpers.dart';
import 'package:flutter/material.dart';
import 'package:Item4Gamer/config.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'login_confirmation.dart';
import 'email_login.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class LoginRouter extends StatelessWidget {
  const LoginRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LOGIN_TYPE == "email" ? const EmailLoginPage() : const LoginPage(),
    );
  }

  static Route<dynamic> route() {
    return MaterialPageRoute(
      builder: (_) => const LoginRouter(),
      settings: const RouteSettings(name: '/login'),
    );
  }
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _service = AuthService();
  bool _isFocused = false;
  bool _isLoading = false;
  bool _isSending = false;
  int _backButtonCount = 0;
  Timer? _backButtonTimer;
  // bool isTyping = false;

  Future<void> _login() async {
    if (_isLoading) return;

    setState(() {
      // _isLoading = true;
      _isSending = true;
    });

    try {
      final phoneNumber = _phoneController.text;
      if (phoneNumber.length < 10) {
        // throw Exception('لطفا شماره تلفن معتبر وارد کنید');
        showCustomSnackBar(context, 'enterValidPhone');
        return;
      }
      var isSuccess;
      if (!LOGIN_WITH_API) {
        isSuccess = await _service.sendOtp(phoneNumber);
        print('Send OTP with firebase result: $isSuccess'); // Debug log
      } else {
        isSuccess = await _service.sendOtpForLogin(phoneNumber);
        print('Send OTP with digit result: $isSuccess'); // Debug log
        if (isSuccess['code'] == 1) {
          isSuccess = true;
        } else {
          isSuccess = true;
        }
      }
      if (isSuccess && mounted) {
        setState(() {
          _isLoading = true;
          _isSending = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginConfirmationPage(
              phoneNumber: phoneNumber,
            ),
          ),
        );
      } else if (mounted) {
        showCustomSnackBar(context, 'otpSendError');
      }
    } catch (e) {
      print('Login error login ckeck: $e'); // Debug log
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(e.toString())),
        // );
        showCustomSnackBar(context, 'connectionError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSending = false;
        });
      }
    }
  }

  Future<void> _skip() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().saveAccessGest();

      if (mounted) {
        // final windowModel = Provider.of<WindowModel>(context, listen: false);
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
            // await BaseWebViewTab!.webViewModel.webViewController?.reload();
            final uri = await BaseWebViewTab!.webViewModel.webViewController
                ?.getOriginalUrl();
            if (uri != null) {
              if (uri.path.contains('/my-account') ||
                  uri.path.contains('/checkout') ||
                  uri.path.contains('/profile')) {
                await BaseWebViewTab!.webViewModel.webViewController
                    ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
                await BaseWebViewTab!.webViewModel.webViewController
                    ?.clearHistory();
              } else {
                await BaseWebViewTab!.webViewModel.webViewController?.reload();
              }
            } else {
              await BaseWebViewTab!.webViewModel.webViewController
                  ?.clearHistory();
              await BaseWebViewTab!.webViewModel.webViewController
                  ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
            }
          },
        ).whenComplete(() {
          for (int i = 0; i < 3; i++) {
            bool? loadingDone = false;
            Future.delayed(Duration(microseconds: 3000)).then((value) async {
              loadingDone = await BaseWebViewTab!.webViewModel.webViewController
                  ?.isLoading();
              if (loadingDone == false) {
                final uri = await BaseWebViewTab!.webViewModel.webViewController
                    ?.getUrl();
                if (uri != null) {
                  if (uri.path.contains('/my-account') ||
                      uri.path.contains('/checkout') ||
                      uri.path.contains('/profile')) {
                    await BaseWebViewTab!.webViewModel.webViewController
                        ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
                    loadingDone = true;
                  } else {
                    Get.find<AppController>()
                        .updateIsBrowserVisibleReturn(true);
                  }
                }
              }
            });
            if (loadingDone == false) return;
          }
        });
      }
    } catch (e) {
      print('Guest login error: $e');
      if (mounted) {
        showCustomSnackBar(context, 'guestLoginError');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.hide(); // جایگزین child: buildLoadingScreen()
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
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
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final contentHeight = isKeyboardOpen
        ? (screenHeight - MediaQuery.of(context).viewInsets.bottom)
        : screenHeight;

    // Button height as defined in ElevatedButton
    // final buttonHeight = screenHeight * 0.1;

    // // Calculate sum of approximate heights of other widgets
    // double sumHeights;
    // if (isKeyboardOpen) {
    //   sumHeights = (contentHeight * 0.04) + // First SizedBox
    //       48 + // Approx height of TextButton
    //       (contentHeight * 0.50) + // AnimatedContainer
    //       (screenHeight * 0.015) + // Third SizedBox
    //       21.7 + // Text height (14 * 1.55)
    //       15 + // SizedBox after Text
    //       (screenHeight * 0.06) + // TextField container height
    //       (screenHeight * 0.02); // SizedBox after TextField
    // } else {
    //   sumHeights = 10 + // First SizedBox
    //       48 + // TextButton
    //       (screenHeight * 0.56) + // AnimatedContainer
    //       (screenHeight * 0.015) + // Third SizedBox
    //       21.7 + // Text height
    //       15 + // SizedBox after Text
    //       (screenHeight * 0.06) + // TextField container
    //       (screenHeight * 0.02); // SizedBox after TextField
    // }

    // // Calculate remaining space
    // final remainingSpace = contentHeight - sumHeights;

    // // Show button if remaining space is enough or keyboard is closed
    // final showButton = remainingSpace >= buttonHeight || !isKeyboardOpen;
    return WillPopScope(
      onWillPop: _handleBackButton,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      AppLocalizations.of(context)!.guestLogin,
                      style: const TextStyle(
                        fontFamily: 'YekanBakh',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                // Replace AnimatedContainer with a Flex layout for the logo
                Flexible(
                  child: Flex(
                    direction: Axis.vertical,
                    children: [
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            LOGO,
                            width: ((screenWidth * 0.30 > screenHeight * 0.4)
                                ? screenHeight * 0.1
                                : screenWidth * 0.30),
                            height: ((screenWidth * 0.30 > screenHeight * 0.4)
                                ? screenHeight * 0.1
                                : screenWidth * 0.30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                Container(
                  width: screenWidth * 0.9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.hello,
                        style: const TextStyle(
                          fontFamily: 'YekanBakh',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.55,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      Container(
                        width: screenWidth * 0.9,
                        height: screenHeight * 0.06,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: isKeyboardOpen
                              ? Border.all(
                                  color: const Color(0xFF424242), width: 3)
                              : null,
                        ),
                        child: TextField(
                          controller: _phoneController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            fontFamily: 'YekanBakh',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.55,
                            color: Color(0xFF595959),
                          ),
                          textAlign: _phoneController.text.isEmpty
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                AppLocalizations.of(context)!.mobileNumber,
                            hintStyle: const TextStyle(
                              fontFamily: 'YekanBakh',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.8,
                              color: Color(0xFF595959),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChanged: (value) {
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            if (value.length >= 10) {
                              _isSending ? null : _login();
                            }
                          },
                          textDirection: _phoneController.text.isNotEmpty
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      // if (showButton)
                      ElevatedButton(
                        onPressed: _isSending ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSending
                              ? Colors.grey
                              : const Color(0xFF0071DF),
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: screenHeight * 0.02,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize:
                              Size(screenWidth * 0.9, screenHeight * 0.06),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.login,
                          style: TextStyle(
                            fontFamily: 'YekanBakh',
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
