import 'package:G4A4/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UrlListManager {
  static final UrlListManager _instance = UrlListManager._internal();

  factory UrlListManager() {
    return _instance;
  }

  UrlListManager._internal();

  // Static lists as fallback
  static const List<String> _staticWhitelist = StaticWhitelist;

  static List<String> _staticBlacklist = getAllBlacklistedUrls();
  // Dynamic lists from API
  List<String> _dynamicWhitelist = [];
  List<String> _dynamicBlacklist = [];

  // Getters for current lists
  List<String> get whitelist =>
      _dynamicWhitelist.isNotEmpty ? _dynamicWhitelist : _staticWhitelist;

  List<String> get blacklist =>
      _dynamicBlacklist.isNotEmpty ? _dynamicBlacklist : _staticBlacklist;

  Future<void> fetchLists() async {
    if (WhiteBlackListAPI.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse(WhiteBlackListAPI),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _dynamicWhitelist = List<String>.from(data['whitelist']);
        _dynamicBlacklist = List<String>.from(data['blacklist']);
      } else {
        _resetToDynamicLists();
      }
    } catch (e) {
      _resetToDynamicLists();
    }
  }

  void _resetToDynamicLists() {
    _dynamicWhitelist = [];
    _dynamicBlacklist = [];
  }

  // Combine all blacklisted URLs
  static List<String> getAllBlacklistedUrls() {
    return [
      ...PAYMENT_GATEWAYS,
      ...SOCIAL_MEDIA,
      ...COMMUNICATION,
      ...MAPS,
      ...APP_STORES,
      ...FILE_SHARING,
      ...VIDEO_CONFERENCING,
      ...MESSAGING,
      ...BANKING,
    ];
  }

  // Check if URL is blacklisted
  static bool isBlacklisted(String url) {
    final String normalizedUrl = url.toLowerCase();
    return getAllBlacklistedUrls().any((blacklistedUrl) =>
        normalizedUrl.contains(blacklistedUrl.toLowerCase()));
  }

  // Get URL type
  static String getUrlType(String url) {
    final String normalizedUrl = url.toLowerCase();

    if (PAYMENT_GATEWAYS
        .any((gateway) => normalizedUrl.contains(gateway.toLowerCase()))) {
      return 'PAYMENT';
    }
    if (SOCIAL_MEDIA
        .any((social) => normalizedUrl.contains(social.toLowerCase()))) {
      return 'SOCIAL';
    }
    if (COMMUNICATION
        .any((comm) => normalizedUrl.startsWith(comm.toLowerCase()))) {
      return 'COMMUNICATION';
    }
    if (MAPS.any((map) => normalizedUrl.contains(map.toLowerCase()))) {
      return 'MAP';
    }
    if (APP_STORES
        .any((store) => normalizedUrl.contains(store.toLowerCase()))) {
      return 'STORE';
    }
    if (FILE_SHARING
        .any((file) => normalizedUrl.contains(file.toLowerCase()))) {
      return 'FILE_SHARING';
    }
    if (VIDEO_CONFERENCING
        .any((conf) => normalizedUrl.contains(conf.toLowerCase()))) {
      return 'VIDEO_CONFERENCE';
    }
    if (MESSAGING.any((msg) => normalizedUrl.contains(msg.toLowerCase()))) {
      return 'MESSAGING';
    }
    if (BANKING.any((bank) => normalizedUrl.contains(bank.toLowerCase()))) {
      return 'BANKING';
    }

    return 'OTHER';
  }

  // Get appropriate action for URL type
  static String getUrlAction(String url) {
    final urlType = getUrlType(url);

    switch (urlType) {
      case 'PAYMENT':
        return 'EXTERNAL_BROWSER';
      case 'SOCIAL':
        return 'APP_OR_BROWSER';
      case 'COMMUNICATION':
        return 'SYSTEM_APP';
      case 'MAP':
        return 'MAP_APP';
      case 'STORE':
        return 'STORE_APP';
      case 'FILE_SHARING':
        return 'EXTERNAL_BROWSER';
      case 'VIDEO_CONFERENCE':
        return 'APP_OR_BROWSER';
      case 'MESSAGING':
        return 'APP_OR_BROWSER';
      case 'BANKING':
        return 'EXTERNAL_BROWSER';
      default:
        return 'IN_APP';
    }
  }
}
