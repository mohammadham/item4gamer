import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../ila_config.dart';
import '../models/ila_models.dart';

class IlaService {
  // دریافت هدرهای احراز هویت
  Map<String, String> get _headers => {
        'api-token': IlaConfig.apiToken,
        'Accept': 'application/json',
        // 'Content-Type': 'application/json', // برای فرم دیتا ممکن است نیاز نباشد
      };

  // ایجاد مکالمه جدید
  Future<String?> createConversation() async {
    final url = Uri.parse('${IlaConfig.baseUrl}/conversation/new');
    try {
      final response = await http.post(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final id = data['conversation']['id'];
          await _saveConversationId(id);
          return id;
        }
      }
      print('Error creating conversation: ${response.body}');
    } catch (e) {
      print('Exception creating conversation: $e');
    }
    return null;
  }

  // دریافت لیست پیام‌ها
  Future<List<IlaMessage>> getMessages(String conversationId,
      {int page = 1}) async {
    final url = Uri.parse(
        '${IlaConfig.baseUrl}/conversation/$conversationId/message/list?page=$page');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List messages = data['messages'];
          return messages.map((e) => IlaMessage.fromJson(e)).toList();
        }
      }
      print('Error getting messages: ${response.body}');
    } catch (e) {
      print('Exception getting messages: $e');
    }
    return [];
  }

  // ارسال پیام متنی
  Future<bool> sendMessage(String conversationId, String message) async {
    final url = Uri.parse(
        '${IlaConfig.baseUrl}/conversation/$conversationId/message/send');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_headers);
      request.fields['message'] = message;

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(respStr);
        return data['status'] == 'success';
      }
      print('Error sending message: $respStr');
    } catch (e) {
      print('Exception sending message: $e');
    }
    return false;
  }

  // آپلود فایل
  Future<bool> sendFile(
      String conversationId, File file, String? message) async {
    final url = Uri.parse(
        '${IlaConfig.baseUrl}/conversation/$conversationId/message/send');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_headers);
      if (message != null) {
        request.fields['message'] = message;
      }

      // افزودن فایل
      final fileStream = http.MultipartFile.fromBytes(
        'file', // نام فیلد فایل
        await file.readAsBytes(),
        filename: file.path.split('/').last,
      );
      request.files.add(fileStream);

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(respStr);
        return data['status'] == 'success';
      }
      print('Error sending file: $respStr');
    } catch (e) {
      print('Exception sending file: $e');
    }
    return false;
  }

  // ارسال ویس
  Future<bool> sendVoice(String conversationId, File file) async {
    final url = Uri.parse(
        '${IlaConfig.baseUrl}/conversation/$conversationId/message/send');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_headers);

      // افزودن فایل ویس
      final fileStream = await http.MultipartFile.fromPath(
        'file', // نام فیلد فایل (معمولاً مشابه فایل عادی است)
        file.path,
      );
      request.files.add(fileStream);

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(respStr);
        return data['status'] == 'success';
      }
      print('Error sending voice: $respStr');
    } catch (e) {
      print('Exception sending voice: $e');
    }
    return false;
  }

  // ذخیره و بازیابی ID مکالمه
  Future<void> _saveConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(IlaConfig.conversationIdKey, id);
  }

  Future<String?> getSavedConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(IlaConfig.conversationIdKey);
  }
}
