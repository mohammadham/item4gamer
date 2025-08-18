import 'dart:async';
import 'package:G4A4/services/dataStore_service.dart';
import 'package:G4A4/widgets/helpers.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:G4A4/config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription? _subscription;
  final _deepLinkController = StreamController<String>.broadcast();
  bool _isInitialized = false;
  // Add a callback for when the app is already running
  Function(String)? onDeepLinkReceived;
  Stream<String> get deepLinkStream => _deepLinkController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Handle initial link if app was launched from dead state
      await handleInitialUri();

      // Listen for incoming links while app is in foreground
      initUriListener();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Deep link initialization error: $e');
    }
  }

  Future<void> handleInitialUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        debugPrint('Got initial link: ${uri.toString()}');
        handleDeepLink(uri.toString(), isADeadState: true);
      }
    } catch (e) {
      debugPrint('Failed to get initial uri: $e');
    }
  }

  void initUriListener() {
    _subscription?.cancel();

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('Got link while app in foreground: ${uri.toString()}');
        handleDeepLink(uri.toString());
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  // Add this method to DeepLinkService
  Future<void> testDeepLink(String link) async {
    debugPrint('Testing deep link: $link');
    handleDeepLink(link);
  }

  // Modify _handleDeepLink to be more robust
  void handleDeepLink(String link, {bool isADeadState = false}) {
    try {
      final uri = Uri.parse(link);
      debugPrint(
          'Processing deep link - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');

      // Handle both HTTPS and custom scheme
      if (((uri.scheme == 'https' || uri.scheme == 'http') &&
              _isValidWebViewLink(uri)) ||
          uri.scheme == 'g4a4') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final processedLink =
              _isLoginDeepLink(uri) ? 'login' : _processLink(uri);

          // Update state
          Get.find<AppController>().updateDeepLinks(true);
          Get.find<AppController>().updateDeepLinksLink(processedLink);

          // Notify listeners
          _deepLinkController.add(processedLink);

          // Call callback if set
          if (onDeepLinkReceived != null) {
            onDeepLinkReceived!(processedLink);
          }
          if (isADeadState) {
            Globals.navigatorKey.currentState?.pushNamed('/home', arguments: {
              'isFirebaseNOTAccessible': false,
              'initialUrl': processedLink,
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing deep link: $e');
    }
  }

  String _processLink(Uri uri) {
    // // Convert external URLs to internal app format if needed
    // if (uri.scheme == 'https') {
    //   // You might want to modify the URL for internal app handling
    //   return uri.toString().replaceFirst('https://', 'G4A4://');
    // }
    // if (uri.scheme == 'http') {
    //   // You might want to modify the URL for internal app handling
    //   return uri.toString().replaceFirst('http://', 'G4A4://');
    // }
    if (uri.scheme == 'g4a4') {
      // You might want to modify the URL for internal app handling
      return uri.toString().replaceFirst('g4a4://', 'https://');
    }
    if (uri.host == 'g4a4.app') {
      // You might want to modify the URL for internal app handling
      return uri.toString().replaceFirst('g4a4.app', 'g4a4.com');
    }

    return uri.toString();
  }

  bool _isLoginDeepLink(Uri uri) {
    return uri.path.contains('/login') ||
        uri.queryParameters['action'] == 'login' ||
        uri.path.contains('/my-account');
  }

  bool _isValidWebViewLink(Uri uri) {
    try {
      final baseUri = Uri.parse(URL);
      return uri.host.contains('g4a4') || uri.host.contains('g4a4');
    } catch (e) {
      debugPrint('Error validating web view link: $e');
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _deepLinkController.close();
    _isInitialized = false;
  }
}
