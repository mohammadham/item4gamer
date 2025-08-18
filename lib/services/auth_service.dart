import 'dart:async';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:G4A4/config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = REST_URL;

  // Email login methods
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/wp-json/app/v1/auth');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    final response = await http.post(url, headers: headers, body: body);
    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      // await _handleAuthResponse(response);
      // Create result map with both headers and body
      return {
        'body': jsonDecode(response.body),
        'headers': response.headers,
        'statusCode': response.statusCode,
      };
    } else {
      throw Exception(responseData['message'] ?? 'Login failed');
    }
  }

  Future<bool> loginWithEmailAction({
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/wp-json/app/v1/auth');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
    });

    final response = await http.post(url, headers: headers, body: body);
    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData['action'] != 'login';
    } else {
      throw Exception(responseData['message'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/wp-json/app/v1/auth');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'email': email, 'password': password});

    final response = await http.post(url, headers: headers, body: body);
    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      // await _handleAuthResponse(response);
      // Create result map with both headers and body
      return {
        'body': jsonDecode(response.body),
        'headers': response.headers,
        'statusCode': response.statusCode,
      };
    } else {
      throw Exception(responseData['message'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> sendResetPasswordEmail(String email) async {
    final url = Uri.parse('$baseUrl/wp-json/app/v1/forgot-password');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
    });

    final response = await http.post(url, headers: headers, body: body);
    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Password reset failed');
    }
  }

  Future<void> _handleAuthResponse(http.Response response) async {
    final responseData = jsonDecode(response.body);
    await saveAccessToken(responseData['data']['access_token']);

    // Save cookies from headers if present
    if (response.headers.containsKey('set-cookie') ||
        response.headers.containsKey('Cookie') ||
        response.headers.containsKey('cookie')) {
      final cookies = response.headers['set-cookie'] ??
          response.headers['Cookie'] ??
          response.headers['cookie'] ??
          '';
      await _storage.write(key: 'auth_cookies', value: cookies);
    }
  }

  // End of email login methods

  // Replace with your actual API key or token if required
  final String apiKey = '';
  String? _verificationId; // Store verificationId for OTP verification
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  // Save access token securely
  Future<void> saveAccessToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _storage.write(key: 'access_token', value: token);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('lastLoginTime', DateTime.now().toIso8601String());
  }

  Future<void> saveAccessTokenData(Map<dynamic, dynamic> dataToken) async {
    await _storage.write(
        key: 'access_token_data', value: jsonEncode(dataToken));
  }

  Future<void> saveAccessGest() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _storage.delete(key: 'access_token');
    await prefs.setBool('isLoggedIn', false);
    await prefs.setString('lastLoginTime', DateTime.now().toIso8601String());
    await prefs.setBool('isGest', true);
  }

  // Retrieve access token
  Future<String> getAccessToken() async {
    return await _storage.read(key: 'access_token') ?? "";
  }

  // Retrieve access login time
  Future<String> getAccessLoginTime() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getString('lastLoginTime') ?? '');
  }

  Future<String> getAccessLoginData() async {
    return await _storage.read(key: 'access_token_data') ?? "";
  }

  // Retrieve access is gest login
  Future<bool> getIsGest() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('isGest') ?? false);
  }

  // Retrieve access is Login
  Future<bool> getIsLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('isLoggedIn') ?? false);
  }

  // Retrieve access is Login
  Future<bool> getIsLoginResponseCookiesSet() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('loginResponseCookiesSet') ?? false);
  }

  Future<void> updateIsLoginResponseCookiesSet(bool action) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('loginResponseCookiesSet', action);
  }

  // Clear access token (e.g., on logout)
  Future<void> clearAccessToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'access_token_data');
    await prefs.setBool('isLoggedIn', false);
    await prefs.setString('lastLoginTime', '');
    await prefs.setBool('isGest', false);
  }

  // Example of an authenticated request
  Future<Map<String, dynamic>> fetchUserData() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('No access token');

    final url = Uri.parse('$baseUrl/wp-json/digits/v1/user');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await clearAccessToken();
      throw Exception('Token expired or invalid');
    } else {
      throw Exception('Failed to fetch user data: ${response.statusCode}');
    }
  }

  ///
  ///return token authentication
  ///
  Future<String> checkUserData() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      await clearAccessToken();
      throw Exception('No access token');
    }

    return accessToken;
  }

  String formatPhoneNumber(String phoneNumber) {
    // Remove any spaces, dashes, or other characters
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Remove leading 0
    if (phoneNumber.startsWith('0')) {
      phoneNumber = phoneNumber.substring(1);
    }

    // Add country code if not present
    if (!phoneNumber.startsWith('+98')) {
      phoneNumber = '+98$phoneNumber';
    }

    return phoneNumber;
  }

  // Future<bool> login(String phoneNumber) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/login'), // Replace with your login endpoint
  //     headers: {'Content-Type': 'application/json'},
  //     body: json.encode({'phone': phoneNumber}),
  //   );

  //   if (response.statusCode == 200) {
  //     // Handle successful login
  //     return true;
  //   } else {
  //     // Handle login failure
  //     return false;
  //   }
  // }

  // Method to send OTP for registration
  Future<Map<String, dynamic>> sendOtpForRegistration(
      String phoneNumber) async {
    final url =
        Uri.parse('$baseUrl/send-otp'); // Replace with the actual endpoint
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': apiKey.isNotEmpty ? 'Bearer $apiKey' : '',
    };
    final body = jsonEncode({
      'phone_number': phoneNumber,
      'action': 'register', // Indicate this is for registration
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  }

//======================================================FireBase API
  // Method to send OTP for login
  Future<Map<String, dynamic>> oneClickLogin({
    required String phoneNumber,
    required String countryCode,
    required String ftoken,
    String otp = '',
  }) async {
    // One Click Login/Signup
    // if (phoneNumber.startsWith('0'))
    //   phoneNumber = phoneNumber.replaceFirst('0', '');
    if (phoneNumber.length < 10) {
      throw Exception('Failed to send OTP: not valid phone number');
    }
    if (otp.length < 3 && otp.isNotEmpty) {
      throw Exception('Failed to send OTP: not valid otp number');
    }
    // phoneNumber = '+98$phoneNumber';

    final url = Uri.parse(
        '$baseUrl/wp-json/digits/v1/one_click'); // Replace with the actual endpoint
    Map<String, String> headers;
    if (apiKey.isNotEmpty) {
      headers = {
        'Content-Type': 'application/json',
        'Authorization': apiKey.isNotEmpty ? 'Bearer $apiKey' : '',
      };
    } else {
      headers = {
        'Content-Type': 'application/json',
      };
    }

    final body = jsonEncode({
      'mobileNo': phoneNumber,
      'countrycode': countryCode.isNotEmpty
          ? countryCode
          : '+98', // Replace with the actual countrycode'
      'otp': otp, // Indicate this is for login
      'ftoken': ftoken,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  }

  // Send OTP via Firebase
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      // Format phone number properly
      phoneNumber = formatPhoneNumber(phoneNumber);
      print('Sending OTP to: $phoneNumber'); // Debug log

      Completer<bool> completer = Completer<bool>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            print('Verification complete error: $e');
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete(true);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      return await completer.future;
    } catch (e) {
      print('SendOtp error: $e');
      return false;
    }
  }

  // Verify OTP and get Firebase ID Token (ftoken)
  Future<String?> fVerifyOtp(String smsCode) async {
    try {
      if (_verificationId == null) {
        throw Exception('No verification ID available');
      }

      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return await userCredential.user?.getIdToken();
    } catch (e) {
      print('Verify OTP error: $e');
      return null;
    }
  }

//================================================================
//================================================================Digit Api
  /// digit check
  /// send opt function with digit end point
  ///
  Future<Map<String, dynamic>> sendOtpForLogin(String phoneNumber,
      {String countrycode = "+98", String type = 'login'}) async {
    // Validate phone number
    if (!phoneNumber.startsWith('0')) {
      phoneNumber = phoneNumber.padRight(1, '0');
    }
    if (phoneNumber.length < 10) {
      throw Exception('Failed to send OTP: not valid phone number');
    }

    // Define the URL
    final url = Uri.parse('$baseUrl/wp-json/digits/v1/send_otp');

    // Create a multipart request
    final request = http.MultipartRequest('POST', url);

    // Add headers
    if (apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }

    // Add form fields
    request.fields['mobileNo'] = phoneNumber;
    request.fields['countrycode'] = countrycode;
    request.fields['type'] = type;

    // Send the request
    final response = await request.send();

    // Handle the response
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  }

  // Method to verify OTP
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final url = Uri.parse(
        '$baseUrl/wp-json/digits/v1/verify_otp'); // Replace with the actual endpoint
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': apiKey.isNotEmpty ? 'Bearer $apiKey' : '',
    };
    final body = jsonEncode({
      'mobileNo': phoneNumber,
      'countrycode': '+98', // Replace with the actual countrycode'
      'otp': otp,
      'type': 'login',
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to verify OTP: ${response.statusCode}');
    }
  }

  // Method to resend OTP
  Future<Map<String, dynamic>> resendOtp(String phoneNumber) async {
    if (phoneNumber.length < 10) {
      throw Exception('Failed to send OTP: not valid phone number');
    }
    final url = Uri.parse(
        '$baseUrl/wp-json/digits/v1/resend_otp'); // Replace with the actual endpoint
    // Create a multipart request
    final request = http.MultipartRequest('POST', url);

    // Add headers
    if (apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
// Add form fields
    request.fields['mobileNo'] = phoneNumber;
    request.fields['countrycode'] = '+98';

    // Send the request
    final response = await request.send();

    // Handle the response
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> sendOtpForOneClickLogin({
    required String phoneNumber,
    required String otp,
    String countryCode = "+98",
    String authToken = "",
  }) async {
    if (authToken.isEmpty) {
      // Validate phone number
      if (phoneNumber.length < 10) {
        throw Exception('Failed to send OTP: not valid phone number');
      }

      // Validate OTP
      if (otp.length < 3 && otp.isNotEmpty) {
        throw Exception('Failed to send OTP: not valid otp number');
      }
    }

    final url = Uri.parse('$baseUrl/wp-json/digits/v1/one_click');

    // Create a multipart request
    final request = http.MultipartRequest('POST', url);

    // Add headers
    if (authToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    } else if (apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }

    // Add form fields
    request.fields['mobileNo'] = phoneNumber;
    request.fields['countrycode'] = countryCode;
    request.fields['otp'] = otp;

    // Send the request
    final streamedResponse = await request.send();

    // Convert to a regular response to access headers more easily
    final response = await http.Response.fromStream(streamedResponse);

    // Create result map with both headers and body
    final result = {
      'body': jsonDecode(response.body),
      'headers': response.headers,
      'statusCode': response.statusCode,
    };

    if (response.statusCode == 200) {
      return result;
    } else {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> sendOtpForOneClickLoginWeb({
    required String phoneNumber,
    required String otp,
    String countryCode = "+98",
  }) async {
    if (phoneNumber.isEmpty || otp.isEmpty) {
      if (phoneNumber.length < 10) {
        throw Exception('Failed to send OTP: not valid phone number');
      }
      if (otp.length < 3 && otp.isNotEmpty) {
        throw Exception('Failed to send OTP: not valid otp number');
      }
    }

    final url = Uri.parse('$baseUrl/wp=admin/admin-ajax.php');
    final request = http.MultipartRequest('POST', url);

    //  headers authorization
    if (apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
    // CORS  headers
    request.headers['Access-Control-Allow-Origin'] = '*';
    request.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
    request.headers['Access-Control-Allow-Headers'] =
        'Origin, Content-Type, Accept, Content-Type, Authorization, X-Requested-With';
    request.headers['X-Requested-With'] = 'XMLHttpRequest';
    request.headers['Access-Control-Allow-Credentials'] = 'true';
    request.headers['Access-Control-Expose-Headers'] = '*';
    //  form fields
    request.fields['username'] = phoneNumber;
    request.fields['mobile/email'] = phoneNumber;
    request.fields['sms-opt'] = otp;

    // Send the request
    final response = await request.send();

    // Handle the response
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  }
}
