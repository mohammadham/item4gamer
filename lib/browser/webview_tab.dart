import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:G4A4/browser/models/web_notification.dart';
import 'package:G4A4/ila_chat/pages/ila_chat_page.dart';
import 'package:G4A4/pages/loading_service.dart';
import 'package:G4A4/services/notification_server_Services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:G4A4/main.dart';
import 'package:G4A4/browser/models/webview_model.dart';
import 'package:G4A4/browser/util.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:G4A4/services/auth_service.dart';
import 'package:G4A4/services/connectivity_service.dart';
import 'package:G4A4/services/dataStore_service.dart';
import 'package:G4A4/config.dart';
import 'package:G4A4/pages/internetError.dart';
import 'package:G4A4/services/UrlListManager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'javascript_console_result.dart';
import 'long_press_alert_dialog.dart';
import 'models/browser_model.dart';
import 'models/window_model.dart';
import 'package:G4A4/widgets/helpers.dart';
import 'package:G4A4/services/deep_link_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

final webViewTabStateKey = GlobalKey<WebViewTabState>();

class WebViewTab extends StatefulWidget {
  WebViewTab({super.key, required this.webViewModel});

  late WebViewModel webViewModel;
  final GlobalKey<WebViewTabState> webViewKey = GlobalKey();

  @override
  State<WebViewTab> createState() => WebViewTabState();
}

class WebViewTabState extends State<WebViewTab> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  FindInteractionController? _findInteractionController;
  WebNotificationController? webNotificationController;
  bool _isWindowClosed = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _httpAuthUsernameController =
      TextEditingController();
  final TextEditingController _httpAuthPasswordController =
      TextEditingController();

  // From CustomWebView
  bool isLoading = true;
  bool _showSplashOverlay = true;
  bool isError = false;
  String currentUrl = '';
  String ReturnUrl = URL;
  int _backButtonCount = 0;
  Timer? _backButtonTimer;
  final urlManager = UrlListManager();
  bool showUrlBar = false;
  bool isNotFirstLoading = false;
  int tryToLoad = 0;
  late Timer _connectivityTimer;
  bool _hasInternet = true;
  Timer? _loadingTimer;
  bool _isLoadingTimeout = false;
  late Worker _deepLinkWorker;
  int prossect = 0;
  bool userfinalyLogged_in = false;
  int _lastProgressUpdate = 0;
  bool backIsClicked = false;
  bool notificationHandlerAdded = false;
  String get authToken => Get.find<AppController>().getAuthToken();
  String get deepLinkLink {
    final link = Get.find<AppController>().getDeepLinksLink();
    if (link.isNotEmpty && (link == 'login' || isValidUrl(link))) {
      return link == 'login' ? LOGIN_URL : link;
    }
    return widget.webViewModel.url.toString();
  }

  bool _isPaymentPage = false;

  String errorTypeCode = '35';

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    // resetState(showLoading: true);
    // Initialize pull-to-refresh
    if (Util.isIOS() || Util.isAndroid()) {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: Colors.blue),
        onRefresh: () async {
          if ([TargetPlatform.iOS].contains(defaultTargetPlatform)) {
            _webViewController?.loadUrl(
                urlRequest:
                    URLRequest(url: await _webViewController?.getUrl()));
          } else {
            _webViewController?.reload();
          }
        },
      );
    }

    // Initialize find interaction
    if (Util.isIOS() || Util.isAndroid() || Util.isMacOS()) {
      _findInteractionController = FindInteractionController();
    }

    // From CustomWebView: UI and connectivity setup
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        // statusBarColor: STATUS_BAR_COLOR,
        systemNavigationBarColor: SYSTEM_NAVIGATION_BAR_COLOR,
        // statusBarIconBrightness: STATUS_BAR_ICON_BRIGHTNESS,
        systemNavigationBarIconBrightness:
            SYSTEM_NAVIGATION_BAR_ICON_BRIGHTNESS,
      ),
    );
    if (isWhiteBlackList) {
      urlManager.fetchLists();
    }
    _startConnectivityCheck();
    _setupDeepLinkHandling();
    // _deepLinkWorker =
    //     ever(Get.find<AppController>().deepLinksLink, (String newLink) {
    //   if (newLink.isNotEmpty && newLink != currentUrl) {
    //     _handleDeepLinkChange(newLink);
    //   }
    // });

    // Initial cookie setup
    if (authToken.isNotEmpty &&
        !Get.find<AppController>().getLoginResponseCookiesSet()) {
      setCookies();
    }

    userScripts = [];
    _loadUserScripts();
  }

  void _setupDeepLinkHandling() {
    // Listen for deep link changes
    _deepLinkWorker =
        ever(Get.find<AppController>().deepLinksLink, (String newLink) {
      if (newLink.isNotEmpty && newLink != currentUrl) {
        print("Deep link changed to: $newLink");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLinkChange(newLink);
        });
      }
    });

    // Register callback with DeepLinkService
    DeepLinkService().onDeepLinkReceived = (String link) {
      if (link.isNotEmpty && link != currentUrl) {
        print("Deep link received directly: $link");
        if (mounted) {
          _handleDeepLinkChange(link);
        }
      }
    };
  }

  void _handleDeepLinkChange(String newLink) async {
    if (isValidUrl(newLink)) {
      print("Loading deep link URL: $newLink");

      // Ensure WebViewController is initialized
      if (_webViewController == null) {
        print("WebViewController is null, cannot load URL");
        return;
      }

      final uri = WebUri(newLink);
      final Map<String, String> queryParams = Map.from(uri.queryParameters)
        ..['utm_source'] = 'app';
      final newUri = uri.replace(queryParameters: queryParams);

      try {
        await _webViewController?.loadUrl(
            urlRequest: URLRequest(url: WebUri.uri(newUri)));

        if (mounted) {
          setState(() {
            currentUrl = newUri.toString();
            print("URL loaded successfully: $currentUrl");
          });
        }
      } catch (e) {
        print("Error loading URL: $e");
      }
    } else {
      print("Invalid URL: $newLink");
    }
  }

//web notification
  Future<WebNotificationPermission> _onNotificationRequestPermission() async {
    final url = await _webViewController?.getUrl();
    if (url == null) return WebNotificationPermission.DENIED;

    final host = url.host;
    final savedPermission =
        await WebNotificationPermissionDb.getPermission(host);
    if (savedPermission != null) {
      return WebNotificationPermission.values
          .firstWhere((e) => e.name.toLowerCase() == savedPermission);
    }

    final permission = await showDialog<WebNotificationPermission>(
          context: context,
          builder: (context) {
            final localizations = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(localizations.notificationPermissionRequest(host)),
              actions: [
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, WebNotificationPermission.DENIED),
                  child: Text(localizations.deny),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, WebNotificationPermission.GRANTED),
                  child: Text(localizations.allow),
                ),
              ],
            );
          },
        ) ??
        WebNotificationPermission.DENIED;

    await WebNotificationPermissionDb.savePermission(host, permission);
    return permission;
  }

  void _onShowNotification(WebNotification notification) async {
    webNotificationController?.notifications[notification.id] = notification;
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'web_notification_channel',
      'Web Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin
        .show(
      notification.id,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: notification.id.toString(),
    )
        .then((_) {
      // Simulate a click event (for testing)
      notification.dispatchClick();
    });

    // Handle vibration
    final vibrate = notification.vibrate;
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (hasVibrator && vibrate != null && vibrate.isNotEmpty) {
      if (vibrate.length % 2 != 0) vibrate.add(0);
      final intensities = <int>[];
      for (int i = 0; i < vibrate.length; i++) {
        intensities.add(i % 2 == 0 && vibrate[i] > 0 ? 255 : 0);
      }
      await Vibration.vibrate(pattern: vibrate, intensities: intensities);
    }
  }

  void _onCloseNotification(int id) {
    final notification = webNotificationController?.notifications[id];
    if (notification != null) {
      webNotificationController?.notifications.remove(id);
    }
    flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> _loadUserScripts() async {
    // Placeholder script
    final placeholderScript = UserScript(
      source: """
      window.Notification = function() {
        console.log('Placeholder Notification constructor called');
      };
      window.Notification.permission = 'default';
      window.Notification.requestPermission = function() {
        console.log('Placeholder requestPermission called');
        return Promise.resolve('default');
      };
      console.log('Placeholder Notification defined');
    """,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
    userScripts.add(placeholderScript);

    // Polyfill script
    try {
      String webNotificationJs =
          await rootBundle.loadString('assets/js/web_notification.js');
      final jsNotificationApiUserScript = UserScript(
        source: webNotificationJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      );
      userScripts.add(jsNotificationApiUserScript);

      String jsContent =
          await rootBundle.loadString('assets/js/select-customizer.js');
      final jsSelectCustomizerUserScript = UserScript(
        source: jsContent,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      );
      userScripts.add(jsSelectCustomizerUserScript);

      // بارگذاری Blob URL Helper (باید قبل از Shadow DOM Interceptor باشد)
      String blobUrlHelperJs =
          await rootBundle.loadString('assets/js/blob_url_helper.js');
      final jsBlobUrlHelperUserScript = UserScript(
        source: blobUrlHelperJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      );
      userScripts.add(jsBlobUrlHelperUserScript);
      print('Blob URL Helper loaded successfully');

      // بارگذاری Shadow DOM Interceptor
      String shadowDomJs =
          await rootBundle.loadString('assets/js/shadow_dom_interceptor.js');
      final jsShadowDomUserScript = UserScript(
        source: shadowDomJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      );
      userScripts.add(jsShadowDomUserScript);
      print('Shadow DOM Interceptor loaded successfully');

      // بارگذاری ILA Chat Helper
      String ilaChatHelperJs =
          await rootBundle.loadString('assets/js/ila_chat_helper.js');
      final jsIlaChatHelperUserScript = UserScript(
        source: ilaChatHelperJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      );
      userScripts.add(jsIlaChatHelperUserScript);
      print('ILA Chat Helper loaded successfully');

      // بارگذاری Media Display Fixer
      String mediaDisplayFixerJs =
          await rootBundle.loadString('assets/js/media_display_fixer.js');
      final jsMediaDisplayFixerUserScript = UserScript(
        source: mediaDisplayFixerJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      );
      userScripts.add(jsMediaDisplayFixerUserScript);
      print('Media Display Fixer loaded successfully');
    } catch (e) {
      print('Error loading user scripts: $e');
    }

    // Load saved permissions
    await WebNotificationPermissionDb.loadSavedPermissions();
    final permissions = await WebNotificationPermissionDb.getPermissions();
    final json = jsonEncode(permissions);
    userScripts.add(UserScript(
      source: """
      (function(window) {
        console.log('Applying saved permissions');
        var notificationPermissionDb = $json;
        if (notificationPermissionDb[window.location.host] === 'granted') {
          Notification._permission = 'granted';
        }
      })(window);
    """,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    ));
  }

  bool _addJavaScriptHandlers() {
    if (_webViewController == null) {
      notificationHandlerAdded = false;
      return false;
    }
    _webViewController?.addJavaScriptHandler(
      handlerName: 'Notification.requestPermission',
      callback: (arguments) async {
        print('JavaScript handler: Notification.requestPermission called');
        final permission = await _onNotificationRequestPermission();
        return permission.name.toLowerCase();
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'Notification.show',
      callback: (arguments) {
        print(
            'JavaScript handler: Notification.show called with args: $arguments');
        if (_webViewController != null) {
          final notification =
              WebNotification.fromJson(arguments[0], _webViewController!);
          _onShowNotification(notification);
        }
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'Notification.close',
      callback: (arguments) {
        print(
            'JavaScript handler: Notification.close called with id: ${arguments[0]}');
        final notificationId = arguments[0];
        _onCloseNotification(notificationId);
      },
    );

    // Handler برای Shadow DOM Media Detection
    _webViewController?.addJavaScriptHandler(
      handlerName: 'shadowMediaDetected',
      callback: (arguments) {
        print('Shadow DOM Media detected: $arguments');
        _handleShadowDomMedia(arguments[0]);
      },
    );

    // Handlers برای Blob URL Helper
    _webViewController?.addJavaScriptHandler(
      handlerName: 'blobUrlCreated',
      callback: (arguments) {
        print('Blob URL created: $arguments');
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'blobUrlRevoked',
      callback: (arguments) {
        print('Blob URL revoked: $arguments');
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'blobResponseDetected',
      callback: (arguments) {
        print('Blob response detected: $arguments');
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'mediaFetchDetected',
      callback: (arguments) {
        print('Media fetch detected: $arguments');
      },
    );

    // Handlers برای ILA Chat Helper
    _webViewController?.addJavaScriptHandler(
      handlerName: 'ilaAudioPlayClicked',
      callback: (arguments) {
        print('ILA Chat audio play clicked: $arguments');
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'ilaImageClicked',
      callback: (arguments) {
        print('ILA Chat image clicked: $arguments');
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'shadowAudioInteraction',
      callback: (arguments) {
        print('Shadow DOM audio interaction: $arguments');
      },
    );

    _webViewController?.addJavaScriptHandler(
      handlerName: 'shadowImageInteraction',
      callback: (arguments) {
        print('Shadow DOM image interaction: $arguments');
      },
    );

    print('JavaScript handlers added successfully');
    return true;
  }

  // متد جدید برای مدیریت media های Shadow DOM
  void _handleShadowDomMedia(Map<String, dynamic> mediaInfo) async {
    try {
      final type = mediaInfo['type'] as String?;
      final url = mediaInfo['url'] as String?;
      final base64 = mediaInfo['base64'] as String?;

      print(
          'Handling Shadow DOM media: type=$type, url=$url, hasBase64=${base64 != null}');

      if (type == null || url == null) {
        print('Invalid media info received');
        return;
      }

      // اگر فایل صوتی است و base64 دارد، آن را ذخیره کنیم (برای دانلود ویس)
      if ((type == 'audio' || type == 'audio_loaded') && base64 != null) {
        // بررسی کنیم آیا کاربر درخواست دانلود داده؟
        // یا شاید بهتر است یک دکمه دانلود نمایش دهیم؟
        // فعلا اتوماتیک ذخیره نمی‌کنیم تا اسپم نشود، اما اگر کاربر روی دکمه دانلود کلیک کرد (که در وب ویو است)
        // باید هندل شود.
        // اما چون کاربر گفت \"دانلود آن از طریق برنامه\"، شاید منظورش این است که وقتی روی دکمه دانلود در چت کلیک می‌کند کار نمی‌کند.

        // اگر URL از نوع blob است، ما آن را به فایل تبدیل می‌کنیم
        if (url.startsWith('blob:')) {
          final dir = await getExternalStorageDirectory();
          final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
          final file = File('${dir!.path}/$fileName');

          // تبدیل base64 به فایل
          final splitData = base64.split(',');
          final bytes =
              base64Decode(splitData.length > 1 ? splitData[1] : splitData[0]);
          await file.writeAsBytes(bytes);

          print('Voice saved to: ${file.path}');
          // نمایش اسنک بار با قابلیت باز کردن
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Voice saved: $fileName'),
              action: SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    // Open file logic
                  }),
            ));
          }
        }
      }
      switch (type) {
        case 'audio':
        case 'audio_loaded':
          print('Audio media detected in Shadow DOM: $url');
          // فایل صوتی در WebView به درستی نمایش داده می‌شود
          break;
        case 'image':
        case 'image_loaded':
          print('Image media detected in Shadow DOM: $url');
          // تصویر در WebView به درستی نمایش داده می‌شود
          break;
        case 'video':
          print('Video media detected in Shadow DOM: $url');
          // ویدیو در WebView به درستی نمایش داده می‌شود
          break;
        default:
          print('Unknown media type: $type');
      }

      // اگر نیاز به ذخیره یا پردازش خاص دارید، می‌توانید اینجا اضافه کنید
    } catch (e) {
      print('Error handling Shadow DOM media: $e');
    }
  }

//webnotification
  @override
  void dispose() {
    _webViewController = null;
    widget.webViewModel.webViewController = null;
    widget.webViewModel.pullToRefreshController = null;
    widget.webViewModel.findInteractionController = null;
    _httpAuthUsernameController.dispose();
    _httpAuthPasswordController.dispose();
    _focusNode.dispose();
    _backButtonTimer?.cancel();
    _connectivityTimer.cancel();
    _loadingTimer?.cancel();
    _deepLinkWorker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_webViewController != null && (Util.isAndroid() || Util.isWindows())) {
      if (state == AppLifecycleState.paused) {
        pauseAll();
      } else {
        resumeAll();
      }
    }
  }

  void pauseAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
    pauseTimers();
  }

  void resumeAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
    resumeTimers();
  }

  void pause() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
  }

  void resume() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
  }

  void pauseTimers() {
    if (!Util.isWindows()) {
      _webViewController?.pauseTimers();
    }
  }

  void resumeTimers() {
    if (!Util.isWindows()) {
      _webViewController?.resumeTimers();
    }
  }

  // From CustomWebView: Cookie management
  Future<void> setCookies() async {
    final isGest = await AuthService().getIsGest();
    if (authToken.isNotEmpty && !isGest) {
      final cookieHeader =
          Get.find<AppController>().getLoginResponseHeaders()['set-cookie'] ??
              Get.find<AppController>().getLoginResponseHeaders()['Cookie'] ??
              Get.find<AppController>().getLoginResponseHeaders()['cookie'];
      if (cookieHeader != null) {
        // پاکسازی کوکی‌های قبلی
        // await CookieManager.instance().deleteAllCookies();
//cheack cookies is set or not
        if (!Get.find<AppController>().getLoginResponseCookiesSet()) {
          await addCookiesToWebView(cookieHeader);
        }
        // تنظیم وضعیت لاگین
        userfinalyLogged_in = true;
        Get.find<AppController>().updateLoginResponseCookiesSet(true);
        AuthService().updateIsLoginResponseCookiesSet(true);

        print("Cookies set successfully for logged in user");
      }
    }
    if (isGest && !isNotFirstLoading) {
      await CookieManager.instance().deleteAllCookies();
    }
  }

  Future<void> addCookiesToWebView(String cookieHeader) async {
    try {
      if (await CookieManager.instance().getAllCookies().then((cookies) {
        bool result = false;
        print(cookies);
        if (cookies.isNotEmpty) {
          cookies.forEach((cookie) {
            if (cookie.name.toLowerCase().contains('wordpress_logged_in')) {
              if (cookieHeader.contains(cookie.value)) {
                result = true;
                return;
              }
            }
          });
        }
        return result;
      })) {
        return;
      }
    } catch (e) {
      if (await CookieManager.instance()
          .getCookies(url: WebUri(URL))
          .then((cookies) {
        bool result = false;
        print(cookies);
        if (cookies.isNotEmpty) {
          cookies.forEach((cookie) {
            if (cookie.name.toLowerCase().contains('wordpress_logged_in')) {
              if (cookieHeader.contains(cookie.value)) {
                result = true;
                return;
              }
            }
          });
        }
        return result;
      })) {
        return;
      }
    }
    // await CookieManager.instance().deleteAllCookies();
    final cookies = cookieHeader.split(',');
    final defaultDomain = Uri.parse(URL).host;
    for (final cookieStr in cookies) {
      final parts = cookieStr.split(';');
      final nameValue = parts[0].split('=');
      if (nameValue.length < 2) continue;
      final name = nameValue[0].trim();
      final value = Uri.decodeComponent(nameValue[1].trim());
      String path = '/';
      String? domain;
      bool secure = false;
      for (final part in parts.skip(1)) {
        final keyVal = part.trim().split('=');
        final key = keyVal[0].toLowerCase();
        final val = keyVal.length > 1 ? keyVal[1] : null;
        switch (key) {
          case 'path':
            path = val ?? '/';
            break;
          case 'domain':
            domain = val;
            break;
          case 'secure':
            secure = true;
            break;
        }
      }
      domain ??= defaultDomain;
      await CookieManager.instance().setCookie(
        url: WebUri('https://$domain'),
        name: name,
        value: value,
        path: path,
        isSecure: secure,
      );
    }
  }

  // From CustomWebView: Navigation handling
  Future<NavigationActionPolicy> _handleNavigation(
      InAppWebViewController controler,
      NavigationAction navigationAction) async {
    final uri = navigationAction.request.url;

    if (uri == null) return NavigationActionPolicy.CANCEL;
    // setState(() => showUrlBar = false);
    // if (mounted) {
    //   setState(() {
    //     showUrlBar = false;
    //   });
    // }

    // Check if payment page
    if (mounted) {
      setState(() {
        _isPaymentPage = UrlListManager.getUrlType(uri.toString()) == 'PAYMENT';
      });
    }
    print('Navigation URI: ${uri}');
    if (uri.path.contains(LOGOUT_PATH)) {
      await _webViewController!
          .loadUrl(urlRequest: URLRequest(url: WebUri(URL)))
          .whenComplete(() {
        Future.delayed(Duration(microseconds: 1000), () {
          _handleTokenExpiration();
          return NavigationActionPolicy.CANCEL;
        });
      });
    }
    final isGest = await AuthService().getIsGest();
    if (isGest &&
        (uri.path.contains('/my-account') || uri.path.contains('/profile'))) {
      _handleTokenExpiration();
      return NavigationActionPolicy.CANCEL;
    }
    if (uri.path.contains('/my-account') ||
        uri.path.contains('/checkout/pay-out') ||
        uri.path.contains('/profile')) {
      if (await _checkLoginStatus()) {
        if (mounted)
          setState(() {
            Get.find<AppController>().lastVisitedUrl(uri.toString());
            currentUrl = uri.toString();
          });
        return NavigationActionPolicy.ALLOW;
      } else if (isNotFirstLoading) {
        _handleTokenExpiration();
        return NavigationActionPolicy.CANCEL;
      } else {
        setCookies();
        controler.reload();
        return NavigationActionPolicy.CANCEL;
      }
    }

    if (isWhiteBlackList &&
        urlManager.blacklist.isNotEmpty &&
        UrlListManager.isBlacklisted(uri.toString())) {
      if (UrlListManager.getUrlType(uri.toString()) != 'PAYMENT') {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationActionPolicy.CANCEL;
      } else {
        // setState(() => showUrlBar = true);
        if (mounted && showUrlBar != true) {
          setState(() {
            showUrlBar = true;
          });
        }
        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            navigationAction.isForMainFrame) {
          // only for Android
          final currenturl = await controler!.getUrl();
          if (currenturl != null) {
            var headers = navigationAction.request.headers;
            headers ??= {};
            var hasRefererHeader =
                headers.keys.map((k) => k.toLowerCase()).contains('referer');
            if (!hasRefererHeader) {
              // use the full current URL (unsafe-url) or
              // create your own URL structure here based on a Referrer-Policy.
              headers['Referer'] = currenturl.toString();
              navigationAction.request.headers = headers;
            }
          }
          await controler!.loadUrl(urlRequest: navigationAction.request);
          return NavigationActionPolicy.CANCEL;
        }
      }
    }
    if (!uri.toString().contains(WebUri(URL).toString()) &&
            ((navigationAction.isRedirect ?? false) ||
                !navigationAction.isForMainFrame) ||
        !uri.toString().contains(WebUri(URL).toString()) &&
            navigationAction.isForMainFrame) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationActionPolicy.CANCEL;
      }
    }
    if (mounted)
      setState(() {
        Get.find<AppController>().lastVisitedUrl(uri.toString());
        currentUrl = uri.toString();
      });
    return NavigationActionPolicy.ALLOW;
  }

  Future<bool> _checkLoginStatus() async {
    if (authToken.isEmpty || authToken == "") {
      return false;
    }
    if ((userfinalyLogged_in &&
        Get.find<AppController>().getLoginResponseCookiesSet())) {
      return true;
    }
    final htmlBody = await _webViewController?.evaluateJavascript(
        source: "document.getElementsByTagName('body')[0].outerHTML");
    if (htmlBody.toString().contains('logged-in')) {
      return true;
    }
    bool isLoggedIn = false;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        isLoggedIn =
            await CookieManager.instance().getAllCookies().then((cookies) {
          bool result = false;
          print(cookies);
          if (cookies.isNotEmpty) {
            cookies.forEach((cookie) {
              if (cookie.name.toLowerCase().contains('wordpress_logged_in')) {
                result = true;
                return;
              }
            });
          }
          return result;
        });
      } else {
        isLoggedIn = await CookieManager.instance()
            .getCookies(url: WebUri(URL))
            .then((cookies) {
          bool result = false;
          print(cookies);
          if (cookies.isNotEmpty) {
            cookies.forEach((cookie) {
              if (cookie.name.toLowerCase().contains('wordpress_logged_in')) {
                result = true;
                return;
              }
            });
          }
          return result;
        });
      }
    } catch (e) {
      final cookies = await _webViewController?.evaluateJavascript(
          source: 'document.cookie');
      isLoggedIn =
          cookies?.toString().contains('wordpress_logged_in_') ?? false;
    }

    if (isLoggedIn) {
      Get.find<AppController>().updateLoginResponseCookiesSet(true);
      AuthService().updateIsLoginResponseCookiesSet(true);
      userfinalyLogged_in = true;
      return true;
    } else {
      // await CookieManager.instance().deleteAllCookies();
      _handleTokenExpiration();
      return false;
    }
  }

  Future<void> ensureControllerInitialized() async {
    if (_webViewController == null) {
      await Future.delayed(Duration(milliseconds: 100));
      if (_webViewController == null) {
        throw Exception('WebViewController is not ready yet');
      }
    }
  }

  void resetController() {
    _webViewController = null;
    widget.webViewModel.webViewController = null;
  }

  void resetState({bool showLoading = true}) {
    if (mounted) {
      setState(() {
        isLoading = showLoading;
        _showSplashOverlay = showLoading;
        isError = false;
        _backButtonCount = 0;
        _backButtonTimer?.cancel();
        showUrlBar = false;
        isNotFirstLoading = !showLoading;
        tryToLoad = 0;
        _hasInternet = true;
        _loadingTimer?.cancel();
        _isLoadingTimeout = false;
        prossect = 0;
        userfinalyLogged_in = false;
        _lastProgressUpdate = 0;
        _isPaymentPage = false;
      });
    }
  }

  void _handleTokenExpiration() async {
    print('Handling token expiration');
    if (BaseWebViewTab != null && authToken.isEmpty) {
      BaseWebViewTab!.webViewKey.currentState?.resetController();
      // BaseWebViewTab!.webViewModel.webViewController?.dispose();
      // BaseWebViewTab!.webViewModel.webViewController = null;
      BaseWebViewTab!.webViewKey.currentState?.resetState(showLoading: true);
    }
    // else {
    //   BaseWebViewTab = null; // بازنشانی کامل WebViewTab
    // }
    if (authToken.isNotEmpty) {
      await CookieManager.instance().deleteAllCookies();
      await _webViewController!.clearHistory();
      await _webViewController!.platform.clearFormData();
      await widget.webViewModel.webViewController!.clearHistory();
      await widget.webViewModel.webViewController!.platform.clearFormData();
      if (mounted) setState(() {});
      setState(() {
        isNotFirstLoading = false;
        // BaseWebViewTab = null;
      });
    }
    // _webViewController!.clearHistory();
    await AuthService().clearAccessToken();
    Get.find<AppController>().updateAuthToken('');
    Get.find<AppController>().lastVisitedUrl(URL);
    Get.find<AppController>().updateLoginResponseHeaders({});
    Get.find<AppController>().updateLoginResponseCookiesSet(false);
    await NotificationServerServices().ClearFCMToken();

    // final windowModel = Provider.of<WindowModel>(context, listen: false);
    // while (true) {
    // if (await _webViewController!
    //     .getOriginalUrl()!
    //     .toString()
    //     .contains(Uri.parse(URL).host)) {
    //   if (await _webViewController!.canGoBack()) {
    //     await _webViewController!.goBack();
    //   } else {
    //     await _webViewController!
    //         .loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
    //   }
    // }
    // }
    if (mounted) {
      setState(() {
        isLoading = true;
        _showSplashOverlay = true;
        print('Loading started for login transition');
      });
    }
    _webViewController!
        .stopLoading()
        // .then((_) {
        // if (widget.webViewModel.tabIndex != null) {
        //   windowModel.closeTab(windowModel.getCurrentTabIndex());
        // }
        // })
        .then((_) {
      // windowModel.closeAllTabs();

      Get.find<AppController>().updateIsBrowserVisibleReturn(false);
      Get.find<AppController>().updateIsBrowserVisible(false);
      if (mounted) {
        Globals.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
      // dispose();
    });
    // _webViewController.clearCache();
    // Close the current tab
  }

  // From CustomWebView: Progress handling
  void _handleProgress(int progress) {
    print('Progress updated: $progress');
    if (progress >= 50 && !isNotFirstLoading) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            isNotFirstLoading = true;
            Future.delayed(
                const Duration(seconds: 1),
                () => mounted
                    ? setState(() => _showSplashOverlay = false)
                    : null);
          });
        }
      });
    }
    _updateProgress(progress);
    if (progress == 100) {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() {
          tryToLoad = 0;
          isLoading = false;
          _showSplashOverlay = false;
          isNotFirstLoading = true;
          _isLoadingTimeout = false;
          print('Progress 100%: Loading stopped');
        });
      }
    }
  }

  // From CustomWebView: Error handling
  void _handleError(WebResourceRequest request, WebResourceError error) {
    _loadingTimer?.cancel();
    if (mounted) {
      setState(() {
        showUrlBar = false;

        // errorTypeCode = '2';
      });
    }
    final errorsType = {
      '1': WebResourceErrorType
          .APP_TRANSPORT_SECURITY_REQUIRES_SECURE_CONNECTION,
      '2': WebResourceErrorType.BACKGROUND_SESSION_IN_USE_BY_ANOTHER_PROCESS,
      '3': WebResourceErrorType.BACKGROUND_SESSION_REQUIRES_SHARED_CONTAINER,
      '4': WebResourceErrorType.BACKGROUND_SESSION_REQUIRES_SHARED_CONTAINER,
      '5': WebResourceErrorType.BACKGROUND_SESSION_WAS_DISCONNECTED,
      '6': WebResourceErrorType.BAD_SERVER_RESPONSE,
      '7': WebResourceErrorType.BAD_URL,
      '8': WebResourceErrorType.CALL_IS_ACTIVE,
      '9': WebResourceErrorType.CANCELLED,
      '10': WebResourceErrorType.CANNOT_CLOSE_FILE,
      '11': WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
      '12': WebResourceErrorType.CANNOT_CREATE_FILE,
      '13': WebResourceErrorType.CANNOT_DECODE_CONTENT_DATA,
      '14': WebResourceErrorType.CANNOT_DECODE_RAW_DATA,
      '15': WebResourceErrorType.CANNOT_LOAD_FROM_NETWORK,
      '16': WebResourceErrorType.CANNOT_MOVE_FILE,
      '17': WebResourceErrorType.CANNOT_OPEN_FILE,
      '18': WebResourceErrorType.CANNOT_PARSE_RESPONSE,
      '19': WebResourceErrorType.CANNOT_REMOVE_FILE,
      '20': WebResourceErrorType.CANNOT_WRITE_TO_FILE,
      '21': WebResourceErrorType.CLIENT_CERTIFICATE_REJECTED,
      '22': WebResourceErrorType.CLIENT_CERTIFICATE_REQUIRED,
      '23': WebResourceErrorType.CONNECTION_ABORTED,
      '24': WebResourceErrorType.DATA_LENGTH_EXCEEDS_MAXIMUM,
      '25': WebResourceErrorType.DATA_NOT_ALLOWED,
      '26': WebResourceErrorType.DOWNLOAD_DECODING_FAILED_MID_STREAM,
      '27': WebResourceErrorType.DOWNLOAD_DECODING_FAILED_TO_COMPLETE,
      '28': WebResourceErrorType.FAILED_SSL_HANDSHAKE,
      '29': WebResourceErrorType.FILE_IS_DIRECTORY,
      '30': WebResourceErrorType.FILE_NOT_FOUND,
      '31': WebResourceErrorType.GENERIC_FILE_ERROR,
      '32': WebResourceErrorType.HOST_LOOKUP,
      '33': WebResourceErrorType.INTERNATIONAL_ROAMING_OFF,
      '34': WebResourceErrorType.IO,
      '35': WebResourceErrorType.NETWORK_CONNECTION_LOST,
      '36': WebResourceErrorType.NOT_CONNECTED_TO_INTERNET,
      '37': WebResourceErrorType.NO_PERMISSIONS_TO_READ_FILE,
      '38': WebResourceErrorType.PROXY_AUTHENTICATION,
      '39': WebResourceErrorType.REDIRECT_FAILED,
      '40': WebResourceErrorType.REDIRECT_TO_NON_EXISTENT_LOCATION,
      '41': WebResourceErrorType.REQUEST_BODY_STREAM_EXHAUSTED,
      '42': WebResourceErrorType.RESET,
      '43': WebResourceErrorType.RESOURCE_UNAVAILABLE,
      '44': WebResourceErrorType.SECURE_CONNECTION_FAILED,
      '45': WebResourceErrorType.SERVER_CERTIFICATE_HAS_BAD_DATE,
      '46': WebResourceErrorType.SERVER_CERTIFICATE_HAS_UNKNOWN_ROOT,
      '47': WebResourceErrorType.SERVER_CERTIFICATE_NOT_YET_VALID,
      '48': WebResourceErrorType.SERVER_CERTIFICATE_UNTRUSTED,
      '49': WebResourceErrorType.SERVER_UNREACHABLE,
      '50': WebResourceErrorType.TIMEOUT,
      '51': WebResourceErrorType.TOO_MANY_REDIRECTS,
      '52': WebResourceErrorType.TOO_MANY_REQUESTS,
      '53': WebResourceErrorType.UNEXPECTED_ERROR,
      '54': WebResourceErrorType.UNKNOWN,
      '55': WebResourceErrorType.UNSAFE_RESOURCE,
      '56': WebResourceErrorType.UNSUPPORTED_AUTH_SCHEME,
      '57': WebResourceErrorType.UNSUPPORTED_SCHEME,
      '58': WebResourceErrorType.USER_AUTHENTICATION_FAILED,
      '59': WebResourceErrorType.USER_AUTHENTICATION_REQUIRED,
      '60': WebResourceErrorType.USER_CANCELLED_AUTHENTICATION,
      '61': WebResourceErrorType.VALID_PROXY_AUTHENTICATION_REQUIRED,
      '62': WebResourceErrorType.ZERO_BYTE_RESOURCE,
    };
    errorsType.forEach((id, errorType) {
      if (errorType == error.type) {
        if (mounted)
          setState(() {
            errorTypeCode = id;
          });
      }
    });
    bool isConnectivityError = ['INTERNET_DISCONNECTED', 'NAME_NOT_RESOLVED']
        .any((desc) => error.description.toUpperCase().contains(desc));
    if (error.type == WebResourceErrorType.USER_AUTHENTICATION_FAILED) {
      _handleTokenExpiration();
      return;
    }
    if (error.description.toUpperCase().contains('TIMED_OUT') &&
        prossect <= 60) {
      if (tryToLoad < 1) {
        tryToLoad++;
        _webViewController?.reload();
        return;
      }
      if (mounted) {
        setState(() {
          showUrlBar = false;
          isError = true;
          // errorTypeCode = '2';
        });
      }
    }
    if (isConnectivityError && prossect < 60) {
      if (mounted) {
        setState(() {
          showUrlBar = false;
          isError = true;
          // errorTypeCode = '1';
        });
      }
    }
  }

  // From CustomWebView: Back button handling
  Future<bool> _handleBackButton() async {
    bool? action = null;
    if (await _webViewController!.canGoBack()) {
      action = false;
      setState(() {
        backIsClicked = true;
      });
      final copyBackForwardList =
          await _webViewController!.getCopyBackForwardList();
      // ابتدا URL صفحه قبلی را بررسی کنیم
      final previousUrl = ReturnUrl;
      if (previousUrl.isNotEmpty) {
        // ذخیره وضعیت فعلی
        final currentUrl = await _webViewController!.getUrl();

        // بررسی آدرس‌های خاص
        if ((((previousUrl.contains('/my-account') ||
                        previousUrl.contains('/checkout/pay-out') ||
                        previousUrl.contains('/profile')) &&
                    authToken.isEmpty) ||
                UrlListManager.getUrlType(previousUrl.toString()) ==
                    'PAYMENT') &&
            previousUrl != currentUrl) {
          if (UrlListManager.getUrlType(previousUrl.toString()) == 'PAYMENT') {
            // برگشت به URL اصلی
            await _webViewController!.loadUrl(
                urlRequest: URLRequest(url: WebUri(URL + CLOSE_NAV_BAR_URL)));
            // await _webViewController!.loadUrl(
            //     urlRequest: URLRequest(url: WebUri(URL + RETURN_NAV_BAR_URL)));
            return false;
          }
          // بررسی وضعیت لاگین
          final isLogin = await _checkLoginStatus();
          if (isLogin &&
              UrlListManager.getUrlType(previousUrl.toString()) != 'PAYMENT') {
            // کاربر لاگین است، مشکلی نیست
            await _webViewController!.goBack();
            return false;
          } else if (!isLogin) {
            // کاربر لاگین نیست
            if (isNotFirstLoading) {
              // برگشت به URL اصلی
              await _webViewController!
                  .loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
              // اجرای منطق انقضای توکن
              _handleTokenExpiration();
              return false;
            } else {
              // تلاش برای تنظیم کوکی‌ها و بارگذاری مجدد
              setCookies();
              _webViewController!.reload();
              return false;
            }
          }
        }
      }
      if (copyBackForwardList != null) {
        int _index = copyBackForwardList.currentIndex ?? 0;
        int currentIndex = _index;
        _index -= 1;
        WebUri? backUrl = null;
        while (_index >= 0) {
          backUrl = copyBackForwardList.list?.elementAt(_index).url;
          if (backUrl.isBlank != true) {
            if (!backUrl.toString().contains('about:blank') &&
                UrlListManager.getUrlType(backUrl.toString()) != 'PAYMENT') {
              // try {
              // WebHistoryItem _element =
              //     copyBackForwardList.list?.elementAt(_index) ??
              //         WebHistoryItem(
              //             index: 0,
              //             originalUrl: WebUri(URL),
              //             title: 'G4A4',
              //             url: WebUri(URL));

              // await _webViewController!.goTo(historyItem: _element);

              // } catch (e) {
              //   print(e.toString());
              // }
              break;
            }
          }
          _index--;
        }
        _index = _index - currentIndex;
        await _webViewController?.goBackOrForward(steps: _index);
        // await _webViewController!.goBack();
      } else {
        // اگر نتوانستیم وضعیت صفحه قبلی را بررسی کنیم، از روش قبلی استفاده می‌کنیم
        await _webViewController!.goBack().then((e) async {
          final uri = await _webViewController!.getUrl();
          action = false;
          if (uri == null) {
            return;
          }
          // بررسی آدرس‌های خاص
          if (((uri.path.contains('/my-account') ||
                      uri.path.contains('/checkout/pay-out') ||
                      uri.path.contains('/profile')) &&
                  authToken.isEmpty) ||
              UrlListManager.getUrlType(uri.toString()) == 'PAYMENT') {
            if (UrlListManager.getUrlType(uri.toString()) == 'PAYMENT') {
              // برگشت به URL اصلی
              await _webViewController!
                  .loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
              return;
            }
            if (await _checkLoginStatus()) {
              return;
            } else if (isNotFirstLoading) {
              _webViewController!
                  .loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
              _handleTokenExpiration();
              return;
            } else {
              setCookies();
              _webViewController!.reload();
              return;
            }
          } else {
            action = false;
          }
        });
      }

      if (action != null) return action!;
    }

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

  // From CustomWebView: Connectivity check
  void _startConnectivityCheck() {
    _connectivityTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _hasInternet = await ConnectivityService().checkInternetConnectionV();
      if (!_hasInternet && mounted && !isError) {
        showCustomSnackBar(context, 'checkInternet');
      }
    });
  }

  // From CustomWebView: File picker
  // Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
  //   if (!await _requestPermissions()) return [];
  //   if (params.acceptTypes.any((type) => type.contains('image'))) {
  //     final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
  //     return photo != null ? [Uri.file(photo.path).toString()] : [];
  //   }
  //   final result = await FilePicker.platform.pickFiles(allowMultiple: params.mode == FileSelectorMode.openMultiple);
  //   return result?.files.map((file) => Uri.file(file.path!).toString()).toList() ?? [];
  // }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isGranted) return true;
      final statusP = await Permission.photos.request();
      if (statusP.isGranted) return true;
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            final localizations = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(localizations.fileAccessPermission),
              content: Text(localizations.fileAccessPermissionMessage),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(localizations.later)),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: Text(localizations.settings)),
              ],
            );
          },
        );
      }
      return false;
    }
    return true;
  }

  // JavaScript injections
  String _getJavaScriptInjection() {
    return '''
      (function() {
        var originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function() {
          this._headers = {};
          return originalOpen.apply(this, arguments);
        };
        var originalSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
        XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
          this._headers[header] = value;
          return originalSetRequestHeader.apply(this, arguments);
        };
        var originalSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.send = function() {
          if (!this._headers['Authorization']) {
            this.setRequestHeader('Authorization', 'Bearer $authToken');
          }
          return originalSend.apply(this, arguments);
        };
        var originalFetch = window.fetch;
        window.fetch = function(url, options) {
          if (!options) options = {};
          if (!options.headers) options.headers = {};
          if (!options.headers['Authorization']) {
            options.headers['Authorization'] = 'Bearer $authToken';
          }
          return originalFetch(url, options);
        };
      })();
    ''';
  }

  String _getJavascriptInjectionDataLayerEventsList() {
    String dataLayer = '';
    for (final event in DATA_LAYER_EVENTS_LIST) {
      dataLayer += '''
        window.dataLayer = window.dataLayer || [];
        window.dataLayer.push({
          'event': '${event['event']}',
          'event_category': '${event['event_category']}',
          'event_label': '${event['event_label']}'
        });
      ''';
    }
    return dataLayer;
  }

  String _getJavascriptInjectionGtagAndPublicEventsList() {
    return '''
      document.querySelectorAll('link[rel="preload"]').forEach(link => {
        if (!link.getAttribute('as')) link.setAttribute('as', 'fetch');
      });
      window.yektanet = window.yektanet || {};
      ${GTAG_ACTION ? '''
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', '$GTAG_ACTION_Configuration');
      ''' : ''}
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      bool isBrowserVisible =
          Get.find<AppController>().getIsBrowserVisibleReturn();

      if (isBrowserVisible) {
        if (!Get.find<AppController>().getLoginResponseCookiesSet() &&
            authToken != '') {
          setCookies().whenComplete(() async {
            isNotFirstLoading = true;
          });
          print(
              'Resetting state: showLoading = ${Get.find<AppController>().getAuthToken()}, $isLoading  ,  $isNotFirstLoading  , $_hasInternet');
          Future.delayed(Duration(seconds: 1)).then((value) {
            Get.find<AppController>().updateIsBrowserVisibleReturn(false);
          });
        } else {
          // isNotFirstLoading = true;
          print(
              'Resetting state: showLoading = ${Get.find<AppController>().getAuthToken()}, $isLoading  ,  $isNotFirstLoading  , $_hasInternet');
          Future.delayed(Duration(seconds: 3)).then((value) {
            Get.find<AppController>().updateIsBrowserVisibleReturn(false);
          });
        }

        // _webViewController?.reload();
      }
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   LoadingService.hide(); // جایگزین child: buildLoadingScreen()
      // });
      return WillPopScope(
        onWillPop: _handleBackButton,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR):
                () => _webViewController?.reload(),
          },
          child: SafeArea(
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              floatingActionButton: _isPaymentPage
                  ? null
                  : GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const IlaChatPage()),
                        );
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://app.ila.chat/storage/bots/2/961818.png',
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return KeyboardVisibilityBuilder(
                      builder: (context, isKeyboardVisible) {
                    final bottomInset =
                        MediaQuery.of(context).viewInsets.bottom;
                    return AnimatedPadding(
                      duration: Duration(
                          milliseconds: isKeyboardVisible
                              ? 5
                              : 5), // Adjust for smoothness
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                          bottom: isKeyboardVisible ? bottomInset : 0),
                      child: Column(
                        children: [
                          if (showUrlBar)
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 15),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey[300]!),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: Offset(0, 1))
                                ],
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      // if (mounted) {
                                      //   setState(() => showUrlBar = false);
                                      // }
                                      if (await _webViewController!
                                          .canGoBack()) {
                                        if (ReturnUrl.isNotEmpty &&
                                            (!ReturnUrl.contains(
                                                    'about:blank') &&
                                                !ReturnUrl.contains(
                                                    'pay-order') &&
                                                UrlListManager.getUrlType(
                                                        ReturnUrl) !=
                                                    'PAYMENT')) {
                                          _webViewController!.goBack();
                                        } else {
                                          await _handleBackButton();
                                        }
                                      } else {
                                        await _webViewController!.loadUrl(
                                            urlRequest: URLRequest(
                                                url: WebUri(
                                                    URL + CLOSE_NAV_BAR_URL)));
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.arrow_back,
                                          size: 18, color: Colors.blue),
                                    ),
                                  ),
                                  const Icon(Icons.lock,
                                      size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentUrl,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w400),
                                      textAlign: TextAlign.left,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.search,
                                      size: 18, color: Colors.grey[600]),
                                  // InkWell(
                                  //   onTap: () async {
                                  //     // if (await _webViewController!.canGoBack()) {
                                  //     //   _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(URL+CLOSE_NAV_BAR_URL)));
                                  //     // }else{
                                  //     if (mounted) {
                                  //       setState(() => showUrlBar = false);
                                  //     }
                                  //     _webViewController!
                                  //         .loadUrl(
                                  //             urlRequest: URLRequest(
                                  //                 url: WebUri(URL +
                                  //                     RETURN_NAV_BAR_URL)))
                                  //         .then((_) {});
                                  //     // }
                                  //   },
                                  //   child: Container(
                                  //     padding: EdgeInsets.all(4),
                                  //     decoration: BoxDecoration(
                                  //       color: Colors.blue.withOpacity(0.1),
                                  //       borderRadius: BorderRadius.circular(12),
                                  //     ),
                                  //     child: Icon(Icons.close_sharp,
                                  //         size: 18, color: Colors.red[600]),
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Stack(
                              children: [
                                Focus(
                                  autofocus: true,
                                  focusNode: _focusNode,
                                  child: _buildWebView(),
                                ),
                                if (isLoading && !(isNotFirstLoading))
                                  AnimatedOpacity(
                                    opacity: _showSplashOverlay ? 1.0 : 1.0,
                                    duration: const Duration(seconds: 2),
                                    child: Builder(
                                      // برای دسترسی به context
                                      builder: (context) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          LoadingService.show(
                                              context); // جایگزین child: buildLoadingScreen()
                                        });
                                        return const SizedBox
                                            .shrink(); // placeholder، چون overlay جدا است
                                      },
                                    ),
                                    onEnd: () {
                                      LoadingService
                                          .hide(); // وقتی animation تمام شد، hide
                                    },
                                  ),
                                if (isLoading && !(_hasInternet))
                                  AnimatedOpacity(
                                    opacity: _showSplashOverlay ? 1.0 : 1.0,
                                    duration: const Duration(seconds: 2),
                                    child: Builder(
                                      // برای دسترسی به context
                                      builder: (context) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          LoadingService.show(
                                              context); // جایگزین child: buildLoadingScreen()
                                        });
                                        return const SizedBox
                                            .shrink(); // placeholder، چون overlay جدا است
                                      },
                                    ),
                                    onEnd: () {
                                      LoadingService
                                          .hide(); // وقتی animation تمام شد، hide
                                    },
                                  ),
                                if ((isError || _isLoadingTimeout))
                                  ErrorPage(
                                    returnPath: currentUrl,
                                    returnAction: false,
                                    errorCode: errorTypeCode,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        ),
      );
    });
  }

  void _updateProgress(int progress) {
    if ((progress - _lastProgressUpdate).abs() >= 10 || progress == 100) {
      _lastProgressUpdate = progress;
      if (mounted) setState(() => prossect = progress);
    }
  }

  Future<void> onJavaScriptAlertDialog(JsAlertRequest request) async {
    final titleStyle = TextStyle(
      fontFamily: 'YekanBakh',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.55,
      color: Colors.black,
    );

    final contentStyle = TextStyle(
      fontFamily: 'YekanBakh',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.55,
      color: Colors.black,
    );

    final buttonStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(request.message!, style: contentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.confirm,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: Colors.white,
              ),
            ),
            style: buttonStyle,
          ),
        ],
      ),
    );
  }

  Future<bool?> onJavaScriptConfirmDialog(JsConfirmRequest request) async {
    final titleStyle = TextStyle(
      fontFamily: 'YekanBakh',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.55,
      color: Colors.black,
    );

    final contentStyle = TextStyle(
      fontFamily: 'YekanBakh',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.55,
      color: Colors.black,
    );

    final buttonStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(request.message!, style: contentStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppLocalizations.of(context)!.yes,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: Colors.white,
              ),
            ),
            style: buttonStyle,
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              AppLocalizations.of(context)!.no,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: Colors.white,
              ),
            ),
            style: buttonStyle,
          ),
        ],
      ),
    );
  }

  Future<String?> onJavaScriptTextInputDialog(JsPromptRequest request) async {
    final TextEditingController controller =
        TextEditingController(text: request.defaultValue);

    final titleStyle = TextStyle(
      fontFamily: 'YekanBakh',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.55,
      color: Colors.black,
    );

    final contentStyle = TextStyle(
      fontFamily: 'YekanBakh',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.55,
      color: Colors.black,
    );

    final buttonStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: controller,
          style: contentStyle,
          decoration: InputDecoration(hintText: request.message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(
              AppLocalizations.of(context)!.confirm,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: Colors.white,
              ),
            ),
            style: buttonStyle,
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.55,
                color: Colors.white,
              ),
            ),
            style: buttonStyle,
          ),
        ],
      ),
    );
  }

  InAppWebView _buildWebView() {
    var browserModel = Provider.of<BrowserModel>(context, listen: true);
    var windowModel = Provider.of<WindowModel>(context, listen: true);
    var settings = browserModel.getSettings();
    var currentWebViewModel = Provider.of<WebViewModel>(context, listen: true);

    if (Util.isAndroid()) {
      try {
        InAppWebViewController.setWebContentsDebuggingEnabled(
            settings.debuggingEnabled);
      } catch (e) {
        print(e.toString());
        InAppWebViewController.setWebContentsDebuggingEnabled(true);
      }
    }

    var initialSettings = InAppWebViewSettings(
        incognito: currentWebViewModel.isIncognitoMode,
        useOnDownloadStart: true,
        useOnLoadResource: true,
        safeBrowsingEnabled: true,
        allowsLinkPreview: false,
        isFraudulentWebsiteWarningEnabled: true);
    // widget.webViewModel.settings! ?? InAppWebViewSettings();
    initialSettings.isInspectable = settings.debuggingEnabled;
    // initialSettings.isInspectable = true;
    initialSettings.useOnDownloadStart = true;
    initialSettings.useOnLoadResource = true;
    initialSettings.useShouldOverrideUrlLoading = true;
    initialSettings.javaScriptCanOpenWindowsAutomatically = true;
    initialSettings.mediaPlaybackRequiresUserGesture = false;

    initialSettings.userAgent =
        "Mozilla/5.0 (Linux; Android 9; LG-H870 Build/PKQ1.190522.001) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36";
    initialSettings.transparentBackground = true;
    initialSettings.safeBrowsingEnabled = true;
    initialSettings.disableDefaultErrorPage = true;
    initialSettings.supportMultipleWindows = false;
    initialSettings.verticalScrollbarThumbColor =
        const Color.fromRGBO(0, 0, 0, 0.5);
    initialSettings.horizontalScrollbarThumbColor =
        const Color.fromRGBO(0, 0, 0, 0.5);
    initialSettings.allowsLinkPreview = false;
    initialSettings.isFraudulentWebsiteWarningEnabled = true;
    initialSettings.disableLongPressContextMenuOnLinks = true;
    initialSettings.allowingReadAccessTo = WebUri('file://$WEB_ARCHIVE_DIR/');
    initialSettings.cacheEnabled = true;
    initialSettings.sharedCookiesEnabled = true;
    initialSettings.cacheMode = CacheMode.LOAD_DEFAULT;
    initialSettings.useHybridComposition = true;
    initialSettings.allowsInlineMediaPlayback = true;
    initialSettings.supportZoom = false;
    initialSettings.javaScriptEnabled = true;
    initialSettings.initialScale = 1; // Changed from 0 to 1 (valid scale)
    initialSettings.maximumZoomScale = 1.0; // Float, but ensure non-null
    initialSettings.minimumZoomScale = 1.0; // Float, but ensure non-null
    initialSettings.pageZoom = 1.0; // Ensure non-null
    initialSettings.geolocationEnabled = true;

    return InAppWebView(
      keepAlive: widget.webViewModel.keepAlive,

      webViewEnvironment: webViewEnvironment,
      initialUrlRequest: URLRequest(url: widget.webViewModel.url),
      initialSettings: initialSettings,
      windowId: widget.webViewModel.windowId,
      pullToRefreshController: _pullToRefreshController,
      findInteractionController: _findInteractionController,
      initialUserScripts: UnmodifiableListView(userScripts),
      onJsAlert: (controller, jsAlertRequest) async {
        await onJavaScriptAlertDialog(jsAlertRequest);
        return JsAlertResponse(handledByClient: true);
      },
      onJsPrompt: (controller, jsPromptRequest) async {
        final result = await onJavaScriptTextInputDialog(jsPromptRequest);
        return JsPromptResponse(
            handledByClient: true,
            action: result != null
                ? JsPromptResponseAction.CONFIRM
                : JsPromptResponseAction.CANCEL,
            value: result);
      },
      onJsConfirm: (controller, jsConfirmRequest) async {
        bool? result = await onJavaScriptConfirmDialog(jsConfirmRequest);
        return JsConfirmResponse(
          handledByClient: true,
          action: result == true
              ? JsConfirmResponseAction.CONFIRM
              : JsConfirmResponseAction.CANCEL,
        );
      },

      onWebViewCreated: (controller) async {
        if (!mounted) return;
        initialSettings.transparentBackground = false;
        _webViewController = controller;
        widget.webViewModel.webViewController = controller;
        await ensureControllerInitialized();
        webNotificationController =
            WebNotificationController(_webViewController!);
        notificationHandlerAdded = _addJavaScriptHandlers();
        if (!notificationHandlerAdded) {
          _webViewController = controller;
          notificationHandlerAdded = _addJavaScriptHandlers();
        }
        if (_webViewController != null && mounted) {
          await _webViewController!.setSettings(settings: initialSettings);
        }
        widget.webViewModel.pullToRefreshController = _pullToRefreshController;
        widget.webViewModel.findInteractionController =
            _findInteractionController;
        try {
          if (mounted) {
            if (Util.isAndroid()) controller.startSafeBrowsing();
            widget.webViewModel.settings = await controller.getSettings();
          }
        } catch (e) {
          await Future.delayed(Duration(seconds: 1)).then((_) async {
            if (mounted) {
              if (Util.isAndroid()) controller.startSafeBrowsing();
              widget.webViewModel.settings = await controller.getSettings();
            }
          });
        }
        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);

        if (authToken.isNotEmpty) if (mounted)
          await controller.evaluateJavascript(
              source: _getJavaScriptInjection());

        // WebNotificationPermissionDb.clear();
        // await webNotificationController?.resetPermission();
        await webNotificationController?.requestPermission();
        if (mounted) {
          setState(() {});
        }
        // _focusNode.requestFocus();
      },

      onLoadStart: (controller, url) async {
        // Check if payment page
        if (mounted) {
          setState(() {
            _isPaymentPage =
                UrlListManager.getUrlType(url.toString()) == 'PAYMENT';
          });
        }
        if (mounted) {
          setState(() {
            isLoading = true;
            _showSplashOverlay = true;
            isError = false;
            currentUrl = url?.toString() ?? '';
            _isLoadingTimeout = false;
            prossect = 0;
          });
        }
        if (isWhiteBlackList && urlManager.blacklist.isNotEmpty) {
          if (UrlListManager.getUrlType(url.toString()) == 'PAYMENT') {
            // setState(() => showUrlBar = true);
            if (mounted && showUrlBar != true) {
              setState(() {
                showUrlBar = true;
              });
            }
          } else {
            if (mounted && showUrlBar != false) {
              setState(() {
                showUrlBar = false;
              });
            }
          }
        }
        if (backIsClicked) {
          if (url!.path.contains('/my-account') ||
              url!.path.contains('/checkout/pay-out') ||
              url!.path.contains('/profile')) {
            // بررسی وضعیت لاگین
            if (!await _checkLoginStatus()) {
              // کاربر لاگین نیست
              if (isNotFirstLoading) {
                // برگشت به URL اصلی
                await _webViewController!
                    .loadUrl(urlRequest: URLRequest(url: WebUri(URL)));
                // اجرای منطق انقضای توکن
                _handleTokenExpiration();
                return;
              } else {
                // تلاش برای تنظیم کوکی‌ها و بارگذاری مجدد
                setCookies();
                _webViewController!.reload();
                return;
              }
            }
          }
          if (mounted)
            setState(() {
              backIsClicked = false;
            });
        }
        _loadingTimer = Timer(const Duration(minutes: 5), () {
          if (mounted && prossect < 60)
            setState(() {
              isError = _isLoadingTimeout = true;
              errorTypeCode = '50';
            });
        });
        widget.webViewModel.isSecure = Util.urlIsSecure(url!);
        widget.webViewModel.url = url;
        widget.webViewModel.loaded = false;
        widget.webViewModel.setLoadedResources([]);
        widget.webViewModel.setJavaScriptConsoleResults([]);
        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);
        else if (widget.webViewModel.needsToCompleteInitialLoad)
          controller.stopLoading();
        if (!notificationHandlerAdded) {
          _webViewController = controller;
          notificationHandlerAdded = _addJavaScriptHandlers();
        }
        windowModel.notifyWebViewTabUpdated();
      },
      onLongPressHitTestResult: (controller, hitTestResult) async {
        if (LongPressAlertDialog.hitTestResultSupported
            .contains(hitTestResult.type)) {
          var requestFocusNodeHrefResult =
              await controller.requestFocusNodeHref();

          if (requestFocusNodeHrefResult != null) {
            showDialog(
              context: context,
              builder: (context) {
                return LongPressAlertDialog(
                  webViewModel: widget.webViewModel,
                  hitTestResult: hitTestResult,
                  requestFocusNodeHrefResult: requestFocusNodeHrefResult,
                );
              },
            );
          }
        }
      },
      onLoadStop: (controller, url) async {
        if (url == null) return;

        // Check if payment page
        if (mounted) {
          setState(() {
            _isPaymentPage =
                UrlListManager.getUrlType(url.toString()) == 'PAYMENT';
          });
        }

        if (mounted) _pullToRefreshController?.endRefreshing();
        await controller.evaluateJavascript(
            source: _getJavascriptInjectionDataLayerEventsList());
        await controller.evaluateJavascript(
            source: _getJavascriptInjectionGtagAndPublicEventsList());
        widget.webViewModel.url = url;
        widget.webViewModel.favicon = null;
        widget.webViewModel.loaded = true;
        var sslCertificateFuture = controller.getCertificate();

        var titleFuture = controller.getTitle();
        var faviconsFuture = controller.getFavicons();

        var sslCertificate = await sslCertificateFuture;
        if (sslCertificate == null && !Util.isLocalizedContent(url!))
          widget.webViewModel.isSecure = false;

        widget.webViewModel.title = await titleFuture;

        List<Favicon>? favicons;
        try {
          favicons = await faviconsFuture;
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
        }
        if (favicons != null && favicons.isNotEmpty) {
          for (var fav in favicons) {
            if (widget.webViewModel.favicon == null) {
              widget.webViewModel.favicon = fav;
            } else {
              if ((widget.webViewModel.favicon!.width == null &&
                      !widget.webViewModel.favicon!.url
                          .toString()
                          .endsWith("favicon.ico")) ||
                  (fav.width != null &&
                      widget.webViewModel.favicon!.width != null &&
                      fav.width! > widget.webViewModel.favicon!.width!)) {
                widget.webViewModel.favicon = fav;
              }
            }
          }
        }
        if (isCurrentTab(currentWebViewModel)) {
          widget.webViewModel.needsToCompleteInitialLoad = false;
          currentWebViewModel.updateWithValue(widget.webViewModel);

          var screenshotData = controller
              .takeScreenshot(
                  screenshotConfiguration: ScreenshotConfiguration(
                      compressFormat: CompressFormat.JPEG, quality: 20))
              .timeout(
                const Duration(milliseconds: 1500),
                onTimeout: () => null,
              );
          widget.webViewModel.screenshot = await screenshotData;
        }
        if (mounted) {
          setState(() {
            isLoading = false;
            _showSplashOverlay = false;
            print(
                'Loading stopped: isLoading = $isLoading, _showSplashOverlay = $_showSplashOverlay');
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          LoadingService.hide(); // جایگزین child: buildLoadingScreen()
        });
        // _openKeyboardWithDelay();
        windowModel.notifyWebViewTabUpdated();
      },
      onProgressChanged: (controller, progress) {
        if (progress > 60 && !isNotFirstLoading) {
          print(progress);
          setState(() {
            isNotFirstLoading = true;
          });
        }

        _handleProgress(progress);
        if (progress == 100 && mounted)
          _pullToRefreshController?.endRefreshing();

        widget.webViewModel.progress = progress / 100;

        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);
      },
      onUpdateVisitedHistory: (controller, url, androidIsReload) async {
        widget.webViewModel.url = url;
        widget.webViewModel.title = await controller.getTitle();

        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);

        windowModel.notifyWebViewTabUpdated();
      },

      onConsoleMessage: (controller, consoleMessage) {
        Color consoleTextColor = Colors.black;
        Color consoleBackgroundColor = Colors.transparent;
        IconData? consoleIconData;
        Color? consoleIconColor;
        if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
          consoleTextColor = Colors.red;
          consoleIconData = Icons.report_problem;
          consoleIconColor = Colors.red;
        } else if (consoleMessage.messageLevel == ConsoleMessageLevel.TIP) {
          consoleTextColor = Colors.blue;
          consoleIconData = Icons.info;
          consoleIconColor = Colors.blueAccent;
        } else if (consoleMessage.messageLevel == ConsoleMessageLevel.WARNING) {
          consoleBackgroundColor = const Color.fromRGBO(255, 251, 227, 1);
          consoleIconData = Icons.report_problem;
          consoleIconColor = Colors.orangeAccent;
        }
        widget.webViewModel.addJavaScriptConsoleResults(JavaScriptConsoleResult(
          data: consoleMessage.message,
          textColor: consoleTextColor,
          backgroundColor: consoleBackgroundColor,
          iconData: consoleIconData,
          iconColor: consoleIconColor,
        ));
        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);
      },
      onLoadResource: (controller, resource) {
        widget.webViewModel.addLoadedResources(resource);

        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        ReturnUrl = currentUrl;
        var url = navigationAction.request.url;

        if (url == null) return NavigationActionPolicy.CANCEL;
        if (url.toString().contains('about:blank')) {
          // if (prossect < 60) {
          if (mounted) {
            setState(() {
              showUrlBar = false;
              isError = true;
              errorTypeCode = '54';
            });
          }
          // }
          return NavigationActionPolicy.CANCEL;
        }
        if (url != null &&
            !["http", "https", "file", "chrome", "data", "javascript"]
                .contains(url.scheme)) {
          print('URL scheme: ${url}');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
            return NavigationActionPolicy.CANCEL;
          }
        }
        return _handleNavigation(controller, navigationAction);
      },
      onPageCommitVisible: (controller, url) {
        if (url.toString().contains('about:blank')) {
          if (mounted) {
            setState(() {
              showUrlBar = false;
              isError = true;
              // errorTypeCode = '4';
            });
          }
        }
      },
      onDownloadStartRequest: (controller, url) async {
        print('Download request: ${url.toString()}');

        String path = url.url.path;
        String fileName = path.substring(path.lastIndexOf('/') + 1);

        // اگر fileName خالی است، نام پیش‌فرض بده
        if (fileName.isEmpty || fileName == '/') {
          fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
        }

        // بررسی اگر blob URL است
        if (url.toString().startsWith('blob:')) {
          print('Blob URL download detected, attempting to handle...');
          // برای blob URLs باید از روش دیگری استفاده کنیم
          // می‌توانیم JavaScript را فراخوانی کنیم تا blob را به base64 تبدیل کند
          try {
            final base64Data = await controller.evaluateJavascript(source: """
              (async function() {
                try {
                  const response = await fetch('${url.toString()}');
                  const blob = await response.blob();
                  return new Promise((resolve) => {
                    const reader = new FileReader();
                    reader.onloadend = () => resolve(reader.result);
                    reader.readAsDataURL(blob);
                  });
                } catch (e) {
                  console.error('Error converting blob:', e);
                  return null;
                }
              })();
            """);

            if (base64Data != null) {
              print('Blob converted to base64 successfully');
              // اینجا می‌توانید base64 را ذخیره کنید
              try {
                final splitData = base64Data.split(',');
                final bytes = base64Decode(splitData.last);

                // Try to guess extension if missing
                if (!fileName.contains('.')) {
                  final mimeType = splitData[0].split(':')[1].split(';')[0];
                  if (mimeType.contains('/')) {
                    fileName += '.' + mimeType.split('/').last;
                  }
                }

                final directory = Platform.isAndroid
                    ? await getExternalStorageDirectory()
                    : await getApplicationDocumentsDirectory();

                if (directory != null) {
                  final file = File('${directory.path}/$fileName');
                  await file.writeAsBytes(bytes);
                  print('File saved to: ${file.path}');

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved: ${file.path}')));
                  }
                }
              } catch (e) {
                print('Error saving blob file: $e');
              }
            }
          } catch (e) {
            print('Error handling blob download: $e');
          }
        } else {
          // دانلود عادی
          try {
            await FlutterDownloader.enqueue(
              url: url.toString(),
              fileName: fileName,
              savedDir: (await getTemporaryDirectory()).path,
              showNotification: true,
              openFileFromNotification: true,
            );
            print('Download started: $fileName');
          } catch (e) {
            print('Error starting download: $e');
          }
        }
      },
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        var sslError = challenge.protectionSpace.sslError;
        if (sslError != null && (sslError.code != null)) {
          if ((Util.isIOS() || Util.isMacOS()) &&
              sslError.code == SslErrorType.UNSPECIFIED) {
            return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED);
          }
          widget.webViewModel.isSecure = false;
          if (isCurrentTab(currentWebViewModel))
            currentWebViewModel.updateWithValue(widget.webViewModel);
          return ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.CANCEL);
        }
        return ServerTrustAuthResponse(
            action: ServerTrustAuthResponseAction.PROCEED);
      },
      onReceivedError: (controller, request, error) async {
        var isForMainFrame = request.isForMainFrame ?? false;
        if (!isForMainFrame) {
          return;
        }
        try {
          if (mounted) _pullToRefreshController?.endRefreshing();
        } catch (e) {
          // Initialize pull-to-refresh
          if (Util.isIOS() || Util.isAndroid()) {
            _pullToRefreshController = PullToRefreshController(
              settings: PullToRefreshSettings(color: Colors.blue),
              onRefresh: () async {
                if ([TargetPlatform.iOS].contains(defaultTargetPlatform)) {
                  _webViewController?.loadUrl(
                      urlRequest:
                          URLRequest(url: await _webViewController?.getUrl()));
                } else {
                  _webViewController?.reload();
                }
              },
            );
          }
        }
        if ((Util.isIOS() || Util.isMacOS() || Util.isWindows()) &&
            error.type == WebResourceErrorType.CANCELLED) {
          // NSURLErrorDomain
          return;
        }
        if (Util.isWindows() &&
            error.type == WebResourceErrorType.CONNECTION_ABORTED) {
          // CONNECTION_ABORTED
          return;
        }

        _handleError(request, error);
        widget.webViewModel.url = request.url;
        widget.webViewModel.isSecure = false;
        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);
      },
      onTitleChanged: (controller, title) async {
        widget.webViewModel.title = title;
        if (isCurrentTab(currentWebViewModel))
          currentWebViewModel.updateWithValue(widget.webViewModel);
        windowModel.notifyWebViewTabUpdated();
      },
      onCreateWindow: (controller, createWindowRequest) async {
        var webViewTab = WebViewTab(
          key: GlobalKey(),
          webViewModel: WebViewModel(
              url: WebUri(URL), windowId: createWindowRequest.windowId),
        );
        windowModel.addTab(webViewTab);
        return true;
      },
      onCloseWindow: (controller) {
        if (_isWindowClosed) return;
        _isWindowClosed = true;
        if (widget.webViewModel.tabIndex != null) {
          windowModel.closeTab(windowModel.getCurrentTabIndex());
          //return home page
          Globals.navigatorKey.currentState?.pushNamed('/home');
        }
      },
      onPermissionRequest: (controller, permissionRequest) async {
        List resources = permissionRequest.resources;
        if (resources.length >= 1) {
          resources.forEach((element) async {
            print('request premission: ' + element.toString());
            if (element.toString().contains("AUDIO_CAPTURE") ||
                element.toString().contains("MICROPHONE")) {
              await Permission.microphone.request();
              await Permission.audio.request();
            }
            if (element.toString().contains("VIDEO_CAPTURE") ||
                element.toString().contains("CAMERA")) {
              await Permission.camera.request();
              await Permission.videos.request();
            }
            if (element.toString().contains("STORAGE")) {
              await Permission.storage.request();
            }
            if (element.toString().contains("ALARM") ||
                element.toString().contains("NOTIFICATION")) {
              await Permission.notification.request();
            }
          });
        }

        return PermissionResponse(
            resources: permissionRequest.resources,
            action: PermissionResponseAction.GRANT);
      },
      onReceivedHttpAuthRequest: (controller, challenge) async {
        var action = await createHttpAuthDialog(challenge);
        return HttpAuthResponse(
          username: _httpAuthUsernameController.text.trim(),
          password: _httpAuthPasswordController.text,
          action: action,
          permanentPersistence: true,
        );
      },

      // androidOnShowFileSelector: _androidFilePicker,
    );
  }

  bool isCurrentTab(WebViewModel currentWebViewModel) {
    return currentWebViewModel.tabIndex == widget.webViewModel.tabIndex;
  }

  Future<HttpAuthResponseAction> createHttpAuthDialog(
      URLAuthenticationChallenge challenge) async {
    HttpAuthResponseAction action = HttpAuthResponseAction.CANCEL;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(localizations.login),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(challenge.protectionSpace.host),
              TextField(
                  decoration:
                      InputDecoration(labelText: localizations.username),
                  controller: _httpAuthUsernameController),
              TextField(
                  decoration:
                      InputDecoration(labelText: localizations.password),
                  controller: _httpAuthPasswordController,
                  obscureText: true),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
                child: Text(localizations.cancel),
                onPressed: () {
                  action = HttpAuthResponseAction.CANCEL;
                  Navigator.of(context).pop();
                }),
            ElevatedButton(
                child: Text(localizations.ok),
                onPressed: () {
                  action = HttpAuthResponseAction.PROCEED;
                  Navigator.of(context).pop();
                }),
          ],
        );
      },
    );
    return action;
  }

  void onShowTab() async {
    resume();
    if (widget.webViewModel.needsToCompleteInitialLoad) {
      widget.webViewModel.needsToCompleteInitialLoad = false;
      await widget.webViewModel.webViewController
          ?.loadUrl(urlRequest: URLRequest(url: widget.webViewModel.url));
    }
  }

  void onHideTab() async => pause();

  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
}
