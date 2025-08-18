import 'dart:async';
import 'package:Item4Gamer/browser/models/webview_model.dart';
import 'package:Item4Gamer/browser/webview_tab.dart';
import 'package:Item4Gamer/main.dart';
import 'package:Item4Gamer/pages/loading_service.dart';
import 'package:Item4Gamer/services/dataStore_service.dart';
import 'package:Item4Gamer/services/notification_server_Services.dart';
import 'package:Item4Gamer/widgets/appWrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:Item4Gamer/services/auth_service.dart';
import 'package:Item4Gamer/pages/email_login.dart';
import 'package:Item4Gamer/config.dart';
import 'package:Item4Gamer/widgets/helpers.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class EmailLoginConfirmationPage extends StatefulWidget {
  final String email;
  final bool isRegister;

  const EmailLoginConfirmationPage({
    super.key,
    required this.email,
    this.isRegister = false,
  });

  @override
  State<EmailLoginConfirmationPage> createState() =>
      _EmailLoginConfirmationPageState();
}

class _EmailLoginConfirmationPageState
    extends State<EmailLoginConfirmationPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  int _backButtonCount = 0;
  Timer? _backButtonTimer;
  int _isTryTwo = 0;

  Future<void> _submit() async {
    if (widget.isRegister) {
      if (_passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        showCustomSnackBar(context, 'enterPasswordAndConfirm');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        showCustomSnackBar(context, 'passwordsDoNotMatch');
        return;
      }
      await _register();
    } else {
      if (_passwordController.text.isEmpty) {
        showCustomSnackBar(context, 'enterPassword8Chars');
        return;
      }
      await _login();
    }
  }

  Future<void> _sendTokenAfterLogin(String authToken) async {
    try {
      final token =
          Get.find<NotificationServerServices>().getMessagesToken() ?? '';
      if (token.isNotEmpty) {
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

  Future<void> _login() async {
    final String verificationCode = _passwordController.text.trim();

    if (verificationCode.length < 8) {
      showCustomSnackBar(context, 'enterPassword8Chars');
      return;
    }
    if (!verificationCode
        .contains(RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$'))) {
      showCustomSnackBar(context, 'passwordRequirements');
      return;
    }
    setState(() => _isLoading = true);
    try {
      bool isSuccess = false;
      final responseData = await AuthService().loginWithEmail(
        email: widget.email,
        password: _passwordController.text,
      );
      final response = responseData['body'];
      Get.find<AppController>()
          .updateLoginResponseHeaders(responseData['headers']);
      await AuthService().saveAccessTokenData(responseData['headers']);
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
        }
      } else {
        if (mounted) {
          showCustomSnackBar(context, 'incorrectEmailOrPassword');
        }

        if (mounted) {
          setState(() {
            _isTryTwo += 1;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'serverError');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final response = await AuthService().registerWithEmail(
        email: widget.email,
        password: _passwordController.text,
      );
      if (!response['success']) {
        if (mounted) {
          showCustomSnackBar(
              context,
              response['message'] ??
                  AppLocalizations.of(context)?.registrationError ??
                  'registration Error');
        }
      } else {
        await _login();
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'serverError');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    try {
      final response = await AuthService().sendResetPasswordEmail(widget.email);
      if (response['success']) {
        if (mounted) {
          showCustomSnackBar(context, 'Reset Password Sent To Email');
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EmailLoginPage(email: widget.email),
              ),
            );
          }
        });
      } else {
        if (mounted) {
          showCustomSnackBar(
              context,
              response['message'] ??
                  AppLocalizations.of(context)?.resetPasswordError ??
                  'resetPasswordError');
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'serverError');
      }
    }
  }

  Future<void> _skip() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().saveAccessGest();
      // Handle guest login success
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
      if (mounted) {
        showCustomSnackBar(context, 'guestLoginError');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _returnToEmailInput() {
    String emailp = widget.email;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => EmailLoginPage(
                email: emailp,
              )),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;
    final localizations = AppLocalizations.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.hide(); // جایگزین child: buildLoadingScreen()
    });
    return WillPopScope(
      onWillPop: _handleBackButton,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      localizations?.guestLogin ?? 'Guest Login',
                      style: const TextStyle(
                        fontFamily: 'YekanBakh',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: Flex(
                    direction: Axis.vertical,
                    children: [
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            LOGO,
                            width: screenWidth * 0.6,
                            height: screenWidth * 0.3,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isRegister
                            ? localizations?.enterPasswordForRegister ??
                                'Enter Password For Register'
                            : localizations?.enterPassword ?? 'Enter Password',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: 'YekanBakh',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Email display with change button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.email,
                                style: const TextStyle(
                                  fontFamily: 'YekanBakh',
                                  fontSize: 14,
                                  color: Color(0xFF595959),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _returnToEmailInput,
                              child: Text(
                                localizations?.change ?? 'Change!',
                                style: const TextStyle(
                                  fontFamily: 'YekanBakh',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Password field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: localizations?.password ?? 'Password',
                            hintStyle: const TextStyle(
                              fontFamily: 'YekanBakh',
                              fontSize: 14,
                              color: Color(0xFF595959),
                            ),
                          ),
                        ),
                      ),
                      // Confirm password field (only for registration)
                      if (widget.isRegister) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: localizations?.confirmPassword ??
                                  'Confirm Password',
                              hintStyle: const TextStyle(
                                fontFamily: 'YekanBakh',
                                fontSize: 14,
                                color: Color(0xFF595959),
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Forgot password (only for login)
                      if (!widget.isRegister) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: Text(
                              localizations?.forgotPassword ??
                                  'Forgot Password?',
                              style: TextStyle(
                                fontFamily: 'YekanBakh',
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: screenHeight * 0.02),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0071DF),
                          padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.02,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize:
                              Size(screenWidth * 0.9, screenHeight * 0.06),
                        ),
                        child: Text(
                          widget.isRegister
                              ? localizations?.registerAndContinue ??
                                  'Register and Continue'
                              : localizations?.login ?? 'Login',
                          style: TextStyle(
                            fontFamily: 'YekanBakh',
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      KeyboardVisibilityBuilder(
                        builder: (context, isKeyboardVisible) {
                          return SizedBox(height: isKeyboardVisible ? 30 : 65);
                        },
                      ),
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
