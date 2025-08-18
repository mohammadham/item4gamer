import 'dart:convert';
import 'package:G4A4/config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationServerServices extends GetxController {
  final String baseUrl = REST_URL;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  var lastTimeMessagesTokenUpdate = DateTime.now().obs;
  var messagesToken = "".obs; // Observable variable
  var messagesTokenServerSet = false.obs; // Observable variable

  void UpdateLastTimeMessagesToken(DateTime value) {
    lastTimeMessagesTokenUpdate.value = value;
  }

  DateTime getLastTimeMessagesTokenUpdate() {
    return lastTimeMessagesTokenUpdate.value;
  }

  void UpdateMessagesTokenServerSet(bool value) async {
    await _storage.write(
        key: 'messagesTokenServerSet', value: value ? 'set' : '');
    messagesTokenServerSet.value = value;
  }

  Future<bool> getMessagesTokenServerSet() async {
    return (await _storage.read(key: 'messages_access_token') ?? "") == 'set'
        ? true
        : messagesTokenServerSet.value;
  }

  void updateMessagesToken(String value) {
    messagesToken.value = value;
  }

  String? getMessagesToken() {
    if (messagesToken.value.isEmpty) {
      return null;
    }
    return messagesToken.value;
  }

  Future<void> saveAccessToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _storage.write(key: 'messages_access_token', value: token);
    await prefs.setString(
        'lastFCMUpdateTime', DateTime.now().toIso8601String());
  }

  Future<String> getAccessToken() async {
    return await _storage.read(key: 'messages_access_token') ?? "";
  }

  // Retrieve access login time
  Future<String> getFCMUpdateTime() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getString('lastFCMUpdateTime') ?? '');
  }

  Future ClearFCMToken() async {
    await _storage.delete(key: 'messages_access_token');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('lastFCMUpdateTime');
    return;
  }

  // Method to resend OTP
  Future<bool> SendActiveTokenNotification(
      String notificationToken, String AuthorizationToken) async {
    if (notificationToken.isEmpty || AuthorizationToken.isEmpty) {
      return false;
    }

    final url = Uri.parse(
        '$baseUrl/wp-json/app/v1/set-notification?token=$notificationToken');

    // Increase timeout and add retries
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final response = await http.get(url, headers: {
          'Authorization': 'Bearer $AuthorizationToken'
        }).timeout(const Duration(seconds: 5)); // Increased timeout

        if (response.statusCode == 200) {
          final responseBody = await response.body;
          print('FCM token sent to server: $responseBody');
          final res = jsonDecode(responseBody);
          return res['success'] ?? false;
        } else {
          print('Failed to send FCM token: ${response.statusCode}');
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: 2 * retryCount));
            continue;
          }
        }
      } catch (e) {
        print('Error sending FCM token (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount));
          continue;
        }
      }
    }

    return false;
  }
}
