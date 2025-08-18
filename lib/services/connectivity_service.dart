import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> checkConnection() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<Timer> startConnectivityCheck(dynamic context) async {
    return Timer.periodic(
      const Duration(seconds: 5),
      (timer) => checkInternetConnection(context),
    );
  }

  Future<void> checkInternetConnection(dynamic context) async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => ErrorPage()),
      // );
      // Show a SnackBar to inform the user to press back again to exit
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[200],
          content: const Text(
            // 'لطفا اینترنت خود را بررسی کنید !',
            'No Internet Connection',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'YekanBakh',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Cache connectivity result
  List<ConnectivityResult>? _lastResult;
  DateTime? _lastCheckTime;
  Future<bool> checkInternetConnectionV() async {
    try {
      // Use cached result if recent (within 5 seconds)
      if (_lastResult != null &&
          _lastCheckTime != null &&
          DateTime.now().difference(_lastCheckTime!).inSeconds < 5) {
        return _lastResult!.contains(ConnectivityResult.mobile) ||
            _lastResult!.contains(ConnectivityResult.wifi) ||
            _lastResult!.contains(ConnectivityResult.ethernet);
      }

      final connectivityResult = await _connectivity.checkConnectivity();
      _lastResult = connectivityResult;
      _lastCheckTime = DateTime.now();
      // print(jsonEncode(connectivityResult));
      return connectivityResult.isNotEmpty &&
          (connectivityResult.contains(ConnectivityResult.mobile) ||
              connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.ethernet));
    } catch (e) {
      return false;
    }
  }
}
