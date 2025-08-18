import 'package:get/get.dart';
import 'package:G4A4/config.dart';

class AppController extends GetxController {
  var authToken = "".obs; // Observable variable

  var iniUrl = URL.obs; // Observable variable
  var lastVisitedUrl = URL.obs; // Observable variable
  var isFirebaseAuthNOTAccessible = false.obs;
  var lastTimeCached = DateTime.now().obs;

  var deepLinks = false.obs;
  var deepLinksLink = ''.obs;
  var loginResponseHeaders = {}.obs;
  var loginResponseCookiesSet = false.obs;
  var isBrowserVisible = false.obs;
  var isBrowserVisibleReturnBack = false.obs;
  void updateIsBrowserVisible(bool action) {
    isBrowserVisible.value = action;
  }

  void updateIsBrowserVisibleReturn(bool action) {
    isBrowserVisibleReturnBack.value = action;
  }

  bool getIsBrowserVisibleReturn() {
    return isBrowserVisibleReturnBack.value;
  }

  Future<bool> getIsBrowserVisible() async {
    return isBrowserVisible.value;
  }

  bool noneAsyncGetIsBrowserVisible() {
    return isBrowserVisible.value;
  }

  void updateLoginResponseHeaders(Map<dynamic, dynamic> action) {
    loginResponseHeaders.value = action;
  }

  void updateDeepLinks(bool action) {
    deepLinks.value = action;
  }

  void updateLoginResponseCookiesSet(bool action) {
    loginResponseCookiesSet.value = action;
  }

  void updateDeepLinksLink(String action) {
    if (action.isNotEmpty && deepLinksLink.value != action) {
      print('Updating deep link to: $action');
      deepLinksLink.value = action;
      updateDeepLinks(true);
    }
  }

  void updateAuthToken(String value) {
    authToken.value = value;
  }

  void updateIniUrl(String value) {
    iniUrl.value = value;
  }

  void updateLastVisitedUrl(String value) {
    lastVisitedUrl.value = value;
  }

  void updateIsFirebaseAuthNOTAccessible(bool value) {
    isFirebaseAuthNOTAccessible.value = value;
  }

  void updateLastTimeCached(DateTime value) {
    lastTimeCached.value = value;
  }

  DateTime getLastTimeCached() {
    return lastTimeCached.value;
  }

  Map<dynamic, dynamic> getLoginResponseHeaders() {
    return loginResponseHeaders.value;
  }

  String getAuthToken() {
    return authToken.value;
  }

  String getDeepLinksLink() {
    return deepLinksLink.value;
  }

  bool getDeepLinks() {
    return deepLinks.value;
  }

  bool getLoginResponseCookiesSet() {
    return loginResponseCookiesSet.value;
  }

  String getIniUrl() {
    return iniUrl.value;
  }

  String getLastVisitedUrl() {
    return lastVisitedUrl.value;
  }

  bool getIsFirebaseAuthNOTAccessible() {
    return isFirebaseAuthNOTAccessible.value;
  }
}
