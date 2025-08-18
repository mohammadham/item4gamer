import 'dart:async';

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
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'email_login_confirmation.dart';
import 'package:flutter/services.dart';

class EmailLoginPage extends StatefulWidget {
  final String email;
  const EmailLoginPage({super.key, this.email = ''});

  @override
  _EmailLoginPageState createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _service = AuthService();
  bool _isFocused = false;
  bool _isLoading = false;
  bool _isSending = false;
  int _backButtonCount = 0;
  Timer? _backButtonTimer;

  Future<void> _login() async {
    if (_isLoading) return;

    setState(() {
      _isSending = true;
    });

    try {
      final email = _emailController.text;
      if (!email.contains('@') || !email.contains('.')) {
        showCustomSnackBar(context, 'enterValidEmail');
        return;
      }


      bool loginAction = await _service.loginWithEmailAction(email: email);
      setState(() {
        _isLoading = true;
        _isSending = false;
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailLoginConfirmationPage(
              email: email,
              isRegister: loginAction,
            ),
          ),
        );
      }
    } catch (e) {
      print('Login error: $e');
      if (mounted) {
        showCustomSnackBar(context, 'serverConnectionError');
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
        WebViewModel webviewModel =
            Provider.of<WebViewModel>(context, listen: false);

        Get.find<AppController>().lastVisitedUrl('');

        webviewModel.url = WebUri(URL);

        if (BaseWebViewTab != null) {
          if (BaseWebViewTab!.webViewKey.currentState != null) {
            await CookieManager.instance().deleteAllCookies();
            BaseWebViewTab!.webViewModel.webViewController?.clearHistory();
            BaseWebViewTab!.webViewKey.currentState!
                .resetState(showLoading: true);
          }

          BaseWebViewTab!.webViewModel.webViewController
              ?.loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
        } else {
          BaseWebViewTab =
              WebViewTab(webViewModel: webviewModel, key: webViewTabKey);
        }

        Get.find<AppController>().updateIsBrowserVisible(true);

        Future.delayed(Duration(seconds: 1)).then(
          (value) async {
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
      if(mounted)
        setState(() {
          _isLoading = false;
        });
      LoadingService.hide(); // جایگزین child: buildLoadingScreen()
    });

  }

  @override
  void dispose() {
    _emailController.dispose();
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
    final localizations = AppLocalizations.of(context);
    final String languageCode = Localizations.localeOf(context).languageCode;    return WillPopScope(
      onWillPop: _handleBackButton,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: languageCode == 'fa' ? CrossAxisAlignment.end : CrossAxisAlignment.start, // شرط dynamic اضافه شده

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
                      textAlign: TextAlign.right,
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
                            width: ((screenWidth * 0.30 > screenHeight * 0.4)
                                ? screenHeight * 0.3
                                : screenWidth * 0.60),
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
                    crossAxisAlignment: languageCode == 'fa' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations?.helloEmail ??
                            'Hello, please enter your email',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: 'YekanBakh',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.55,
                          color: Colors.black,
                        ),
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
                          controller: _emailController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            fontFamily: 'YekanBakh',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.55,
                            color: Color(0xFF595959),
                          ),
                          textAlign: languageCode == 'fa' ? TextAlign.right : TextAlign.left,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                localizations?.emailAddress ?? 'Email Address',
                            hintStyle: const TextStyle(
                              fontFamily: 'YekanBakh',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.8,
                              color: Color(0xFF595959),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            if (value.contains('@') && value.contains('.')) {
                              _isSending ? null : _login();
                            }
                          },
                          textDirection: _emailController.text.isNotEmpty
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
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
                        child: _isSending ? CircularProgressIndicator() :Text(
                          localizations?.continue_ ?? 'Continue',
                          style: TextStyle(
                            fontFamily: 'YekanBakh',
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: languageCode == 'fa' ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                      KeyboardVisibilityBuilder(
                        builder: (context, isKeyboardVisible) {
                          if (!isKeyboardVisible &&
                              MediaQuery.of(context).viewInsets.bottom != 0) {
                            isKeyboardVisible = true;
                          }
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
