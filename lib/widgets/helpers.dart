import 'dart:convert';
import 'dart:io';

import 'package:Item4Gamer/pages/frized_splash_screen.dart';
import 'package:Item4Gamer/services/auth_service.dart';
import 'package:Item4Gamer/services/dataStore_service.dart';
import 'package:Item4Gamer/services/deep_link_service.dart';
import 'package:firebase_notifications_handler/firebase_notifications_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

TextDirection textDirection = isRTL ? TextDirection.rtl : TextDirection.ltr;
// Optimize SnackBar display with caching
final Map<String, SnackBar> _snackBarCache = {};

bool isFirebaseAccessible = false;
bool apiSystemProblem = false;
final DeepLinkService deepLinkService = DeepLinkService();

class Globals {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
}

showCustomSnackBar(BuildContext context, String messageKey,
    {Map<String, String>? args}) {
  // Get translated message
  String message;
  try {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      // Try to get translation, if key doesn't exist, use the key as fallback
      message = _getTranslatedMessage(localizations, messageKey, args);
    } else {
      message = messageKey; // Fallback to original text
    }
  } catch (e) {
    message = messageKey; // Fallback to original text if translation fails
  }

  // Use cached SnackBar if available
  final keyboardIsOpen =
      MediaQuery.of(context).viewInsets.bottom != 0 ? '_open' : '_close';
  final cacheKey = message + keyboardIsOpen;

  if (!_snackBarCache.containsKey(cacheKey)) {
    // Calculate horizontal margin based on message length
    double horizontalMargin =
        MediaQuery.of(context).size.width - (message.length * 8) > 0
            ? ((MediaQuery.of(context).size.width - (message.length * 8)) / 2)
            : 30;

    // Determine if we should show from top or bottom
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;
    final screenHeight = MediaQuery.of(context).size.height;

    // Position logic:
    // - If keyboard is open, show at top with padding
    // - If screen is in landscape or small height, show at top
    // - Otherwise show at bottom with padding
    final showAtTop = isKeyboardOpen ||
        screenHeight < 500 ||
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Calculate vertical margin
    double verticalMargin;
    if (showAtTop) {
      // Show at top with safe area padding
      verticalMargin = MediaQuery.of(context).padding.top + 10;
    } else {
      // Show at bottom with padding
      verticalMargin = 20;
    }

    _snackBarCache[cacheKey] = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: showAtTop
            ? MediaQuery.of(context).size.height - (verticalMargin + 100)
            : verticalMargin,
        top: showAtTop ? verticalMargin : 0,
      ),
      dismissDirection: showAtTop ? DismissDirection.up : DismissDirection.down,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      backgroundColor: Colors.grey[700],
      content: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 30,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'YekanBakh',
              fontSize: 14,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      duration: const Duration(seconds: 2),
    );
  }

  // Show the SnackBar
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(_snackBarCache[cacheKey]!);
}

String _getTranslatedMessage(
    AppLocalizations localizations, String key, Map<String, String>? args) {
  try {
    // Use reflection-like approach to get the translation
    switch (key) {
      case 'backButtonWarning':
        return localizations.backButtonWarning;
      case 'enterValidPhone':
        return localizations.enterValidPhone;
      case 'otpSendError':
        return localizations.otpSendError;
      case 'serverConnectionError':
        return localizations.serverConnectionError;
      case 'guestLoginError':
        return localizations.guestLoginError;
      case 'enterCompleteCode':
        return localizations.enterCompleteCode;
      case 'incorrectCode':
        return localizations.incorrectCode;
      case 'resendError':
        return localizations.resendError;
      case 'enterValidEmail':
        return localizations.enterValidEmail;
      case 'enterPasswordAndConfirm':
        return localizations.enterPasswordAndConfirm;
      case 'passwordsDoNotMatch':
        return localizations.passwordsDoNotMatch;
      case 'enterPassword8Chars':
        return localizations.enterPassword8Chars;
      case 'passwordRequirements':
        return localizations.passwordRequirements;
      case 'incorrectEmailOrPassword':
        return localizations.incorrectEmailOrPassword;
      case 'serverError':
        return localizations.serverError;
      case 'registrationError':
        return localizations.registrationError;
      case 'resetPasswordSent':
        return localizations.resetPasswordSent;
      case 'resetPasswordError':
        return localizations.resetPasswordError;
      case 'checkInternet':
        return localizations.checkInternet;
      default:
        return key; // Return the key itself as fallback
    }
  } catch (e) {
    return key; // Return the key itself as fallback
  }
}

double contentViewAfterKeyboardOpen(BuildContext context) {
  final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
  final screenHeight = MediaQuery.of(context).size.height;
  return screenHeight - keyboardHeight;
}

Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      final result = await Permission.notification.request();
      final FlutterLocalNotificationsPlugin _notificationsPlugin =
          FlutterLocalNotificationsPlugin();
      // request notification permissions for android 13 or above

      _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .requestNotificationsPermission();
      _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .requestExactAlarmsPermission();
      if (result.isDenied) {
        print('Notification permission denied on Android');
        // Optionally show a dialog to guide the user to settings
      }
    }
  }
  if (Platform.isIOS) {
    // _firebaseMessaging.requestPermission();
    FirebaseMessaging messaging = await FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('Notification permission denied on iOS');
      // Optionally show a dialog to guide the user to settings
    }
  }
}

Future<bool> checkLoginStatus() async {
  try {
    // final isGuest = await _checkGestStatus();

    // // If guest mode is active, return true
    // if (isGuest) {
    //   return true;
    // }
    // if (Get.find<AppController>().getLoginResponseCookiesSet()) {
    //   return true;
    // }

    final isLoggedIn = await AuthService().getIsLogin();
    final loginTime = await AuthService().getAccessLoginTime();
    String storedToken = await AuthService().getAccessToken();
    bool loginResponseCookiesSet =
        await AuthService().getIsLoginResponseCookiesSet();
    final headers = jsonDecode(await AuthService().getAccessLoginData());

    if (!isLoggedIn || loginTime.isEmpty || storedToken.isEmpty) {
      return false;
    }

    final loginDateTime = DateTime.parse(loginTime);
    if (loginDateTime
        .isBefore(DateTime.now().subtract(const Duration(days: 15)))) {
      // Clear expired login
      // await AuthService().clearAccessToken();
      return false;
    }
    try {
      final response = await AuthService().sendOtpForOneClickLogin(
          otp: "", phoneNumber: "", authToken: storedToken);
      final result = response['body'];
      if (result != null) {
        if (result['success'] == false) {
          final resultData = result['data'];
          if (resultData['code'] != null ||
              resultData['code'] == '-1' ||
              resultData['level'] == '2') {
            return false;
          }
          if (headers['set-cookie'] != null) {
            Get.find<AppController>().updateAuthToken(storedToken);
            Get.find<AppController>().updateLoginResponseHeaders(headers);
            Get.find<AppController>()
                .updateLoginResponseCookiesSet(loginResponseCookiesSet);
            return true;
          }
        }
      }
    } catch (e) {
      print('Check login error: $e');

      apiSystemProblem = true;

      return false;
    }
    return false;
    // return true;
  } catch (e) {
    print('Check login status error: $e');
    return false;
  }
}

 Widget buildLoadingScreen() {
  return const Scaffold(
    body: RepaintBoundary(
      child: IgnorePointer(
        child: const SplashScreenFrize(
          splashTimeFrized: 0.9,
          type: LOGO_MOTION_TYPE,
        ),
      ),
    ),
  );
}

Future<bool> checkGestStatus() async {
  try {
    final isGuest = await AuthService().getIsGest();
    final guestTime = await AuthService().getAccessLoginTime();

    if (!isGuest || guestTime.isEmpty) {
      return false;
    }

    final loginDateTime = DateTime.parse(guestTime);
    if (loginDateTime
        .isBefore(DateTime.now().subtract(const Duration(hours: 24)))) {
      // Clear expired guest status
      // await AuthService().clearAccessToken();
      return false;
    }

    return true;
  } catch (e) {
    print('Check guest status error: $e');
    return false;
  }
}
