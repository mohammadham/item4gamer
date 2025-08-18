import 'package:flutter/material.dart';

const bool isWebViewWithoutLogin = false;
const String URL = "https://g4a4.com/"; // most end with /
const String TITLE = "G4A4";
//rest url api address for firebase and another Services API
const String REST_URL = 'https://g4a4.com'; // dont end with /
const String LOGIN_URL =
    "https://g4a4.com/my-account/"; // most end with /  and  if LOGIN_WITH_API and FireBaseAuth is not available and set to false show  LOGIN_URL instead
const bool LOGIN_WITH_API =
    true; // if LOGIN_WITH_API and firebase is not available and set to false show  LOGIN_URL instead
const String LOGIN_TYPE =
    "phone"; // "phone" or "email" - determines which login flow to use
const String LOGOUT_PATH =
    'my-account/customer-logout'; // most end without / and not with base URL like
const String CLOSE_NAV_BAR_URL = 'checkout';
const String RETURN_NAV_BAR_URL =
    'cart'; //مسیر برگشت اگر صفحه برگشت به صفحه پرداخت باشد برای دکمه بکوارد
//if website is wordpress and not webview
const int FEATURED_CATEGORY_ID = 20;
const String FEATURED_CATEGORY_TITLE = 'Featured';
const isRTL = false;

//if website is wordpress
const String REST_URL_PREFIX = 'wp-json';

//logo motion for naviagtion
enum CustomSplashScreenType { lottie, image, gif, video }

const String LOGO_MOTION_LOTTIE = 'assets/gifs/data.json';
const String LOGO_MOTION_GIF = 'assets/gifs/loading.gif';
const String LOGO_MOTION_IMAGE =
    'assets/gifs/loading.png'; // if is it not exist use LOGO
const String LOGO_MOTION_VIDEO = 'assets/gifs/loading.mp4';
const String LOGO_MOTION = 'assets/gifs/loading.gif';
const double LOGO_MOTION_WIDTH_PER = 1; // its % width for image and gif
const double LOGO_MOTION_HEIGHT_PER = 1; // its % height for image and gif
const int LOGO_MOTION_TIME =
    3; // time of play video  or lottie or gif or show image
const CustomSplashScreenType LOGO_MOTION_TYPE =
    CustomSplashScreenType.lottie; //image || gif || video || lottie

//logos use in application
const String LOGO = 'assets/images/logoLight.png';
const String LOGO_DARK = 'assets/images/logoDark.png';
const String LOGO_APP = 'assets/images/logoLight.png';
const String LOGO_APP_DARK = 'assets/images/logoDark.png';
const String INTERNET_ERROR_ICON = 'assets/icons/internet-Icon.png';
// White and black list for webview
// if is webview then white list is for another address is able to opened with app
// and black list is for other links cant open and most send to another browser
const bool isWhiteBlackList = true; // for active it

const List<String> StaticWhitelist = [];

// Payment Gateways and Financial Services
const List<String> PAYMENT_GATEWAYS = [
  // Shaparak Payment Gateways
  'asan.shaparak.ir',
  'bpm.shaparak.ir',
  'pec.shaparak.ir',
  'pecco.shaparak.ir',
  'sep.shaparak.ir',
  'sep۲.shaparak.ir',
  'pep.shaparak.ir',
  'pna.shaparak.ir',
  'sadad.shaparak.ir',
  'ikc.shaparak.ir',
  'fanava.shaparak.ir',
  'fcp.shaparak.ir',
  'mabna.shaparak.ir',
  'ecd.shaparak.ir',
  'pas.shaparak.ir',
  'bmi.shaparak.ir',
  'shaparak.ir',
  'zarinpal.com'

      // Additional Payment Services
      'pay.ir',
  'zarinpal.ir',
  'zibal.ir',
  'payping.ir',
  'nextpay.org',
  'idpay.ir',
  'paystar.ir',
  'merchant.paypal.com',
  // 'checkout.stripe.com',
  // 'checkout/order-pay'
];

// Social Media Apps and Domains
const List<String> SOCIAL_MEDIA = [
  // Facebook
  'facebook.com',
  'm.facebook.com',
  'fb.me',
  'fb.com',
  'fb.watch',

  // Instagram
  'instagram.com',
  'ig.me',

  // Twitter/X
  'twitter.com',
  'x.com',
  't.co',

  // LinkedIn
  'linkedin.com',
  'lnkd.in',

  // Telegram
  't.me',
  'telegram.me',
  'telegram.org',

  // WhatsApp
  'whatsapp.com',
  'wa.me',

  // YouTube
  'youtube.com',
  'youtu.be',
  'yt.be',

  // TikTok
  'tiktok.com',
  'vm.tiktok.com',

  // Snapchat
  'snapchat.com',
  't.snap.com',

  // Pinterest
  'pinterest.com',
  'pin.it',
  'ila.chat'
];

// Email and Communication
const List<String> COMMUNICATION = [
  'mailto:',
  'tel:',
  'sms:',
  'facetime:',
  'skype:',
];

// Maps and Location Services
const List<String> MAPS = [
  'maps.google.com',
  'waze.com',
  'geo:',
  'maps.apple.com',
];

// App Stores and Package Managers
const List<String> APP_STORES = [
  'play.google.com',
  'market://',
  'apps.apple.com',
  'itms-apps://',
  'appstore://',
];

// File Sharing and Storage
const List<String> FILE_SHARING = [
  'drive.google.com',
  'dropbox.com',
  'onedrive.live.com',
  'box.com',
  'mega.nz',
  'wetransfer.com',
];

// Video Conferencing
const List<String> VIDEO_CONFERENCING = [
  'zoom.us',
  'meet.google.com',
  'teams.microsoft.com',
  'webex.com',
];

// Messaging Apps
const List<String> MESSAGING = [
  'discord.com',
  'discord.gg',
  'slack.com',
  'messenger.com',
];

// Banking Apps
const List<String> BANKING = [
  'mb.bankemellat.ir',
  'bmi.ir',
  'bpi.ir',
  'banksepah.ir',
  'enbank.ir',
  'ba24.ir',
  'bank-maskan.ir',
];

const String WhiteBlackListAPI =
    ''; // dont end with / and if is not empty cheack and if is empty not fetch any things from server

// FireBase goole Configs
// 1. Create a Firebase Project

//     Go to the Firebase Console.

//     Click "Add Project".

//     Enter a project name (e.g., "My Flutter App") and follow the steps to create the project.

// 2. Add Firebase to Your Flutter App

//     In the Firebase Console, click on the Android icon (since Flutter uses Android and iOS platforms).

//     Enter your app's package name (e.g., com.example.myapp). You can find this in your android/app/build.gradle file under applicationId.

//     Click "Register App".

//     Download the google-services.json file and place it in your Flutter project under android/app/
// install firebase cli and after that
// login to firebase
// firebase login
// after that you can get configure of flutter project with run the following command:
// dart pub global activate flutterfire_cli
// flutterfire configure --project=g4a4-app
const bool FireBase = true;
const bool FireBaseMessages = true;
const bool FireBaseAuth = false;
const String? FireBaseAuthToken = null;

// const String LAST_CACHE_CLEAR_KEY = 'last_cache_clear';
// const String APP_VERSION = '1.0.0';
// const String APP_NAME = 'G4a4';
// const String APP_DESCRIPTION = 'G4a4';
// const String APP_DEVELOPER = 'G4a4';
// const String APP_SUPPORT_EMAIL = '';
// const String APP_TERMS = '';
// const String APP_PRIVACY = '';
// const String APP_SHARE = '';
// const String APP_SHARE_SUBJECT = '';
// const String APP_SHARE_MESSAGE = '';
//================================================================
//color nav config
const Color STATUS_BAR_COLOR = Colors.white;
const Color SYSTEM_NAVIGATION_BAR_COLOR = Colors.white;
const Brightness STATUS_BAR_ICON_BRIGHTNESS = Brightness.dark;
const Brightness SYSTEM_NAVIGATION_BAR_ICON_BRIGHTNESS = Brightness.dark;

//=======================================================================
// List of errors to ignore or handle

// Error    Code	                            Description	Meaning
// -1	      ERR_BLOCKED_BY_ORB	              The request was blocked due to ORB (Opaque Response Blocking).
// -2	      ERR_CONNECTION_REFUSED	          The server refused the connection.
// -3	      ERR_NAME_NOT_RESOLVED	            The hostname could not be resolved.
// -4	      ERR_TIMED_OUT	                    The request timed out.
// -5	      ERR_SSL_PROTOCOL_ERROR	          An SSL protocol error occurred.
// -6	      ERR_ADDRESS_UNREACHABLE	          The address is unreachable.
// -7	      ERR_INVALID_URL	                  The URL is invalid.
// -8	      ERR_UNKNOWN_URL_SCHEME	          The URL scheme is not supported.

// You can add these errors to your ignoredErrors list if needed.

// List<Map<String, dynamic>> IGNORED_ERRORS = [
//   {
//     'errorCode': WebResourceErrorType.CALL_IS_ACTIVE,
//     'description': 'ERR_BLOCKED_BY_ORB',
//   },
//   // {
//   //   'errorCode': -2,
//   //   'description': 'ERR_CONNECTION_REFUSED',
//   // },
//   {
//     'errorCode': WebResourceErrorType.HOST_LOOKUP,
//     'description': 'ERR_SSL_PROTOCOL_ERROR',
//   },
//   {
//     'errorCode': WebResourceErrorType.UNSUPPORTED_AUTH_SCHEME,
//     'description': 'ERR_ADDRESS_UNREACHABLE',
//   },
//   {
//     'errorCode': WebResourceErrorType.UNSUPPORTED_SCHEME,
//     'description': 'ERR_SSL_PROTOCOL_ERROR',
//   },
//   {
//     'errorCode': WebResourceErrorType.IO,
//     'description': 'ERR_ADDRESS_UNREACHABLE',
//   },
//   {
//     'errorCode': WebResourceErrorType.PROXY_AUTHENTICATION,
//     'description': 'ERR_SSL_PROTOCOL_ERROR',
//   },
//   {
//     'errorCode': WebResourceErrorType.TOO_MANY_REQUESTS,
//     'description': 'ERR_ADDRESS_UNREACHABLE',
//   },
//   {
//     'errorCode': WebResourceErrorType.PROXY_AUTHENTICATION,
//     'description': 'ERR_SSL_PROTOCOL_ERROR',
//   },
//   {
//     'errorCode': WebResourceErrorType.FAILED_SSL_HANDSHAKE,
//     'description': 'ERR_ADDRESS_UNREACHABLE',
//   },
//   {
//     'errorCode': WebResourceErrorType.SECURE_CONNECTION_FAILED,
//     'description': 'ERR_SSL_PROTOCOL_ERROR',
//   },
//   {
//     'errorCode': WebResourceErrorType.CANCELLED,
//     'description': 'ERR_ADDRESS_UNREACHABLE',
//   },
//   {
//     'errorCode': WebResourceErrorType.NO_PERMISSIONS_TO_READ_FILE,
//     'description': 'ERR_SSL_PROTOCOL_ERROR',
//   },
//   {
//     'errorCode': WebResourceErrorType.CANNOT_PARSE_RESPONSE,
//     'description': 'ERR_ADDRESS_UNREACHABLE',
//   },
//   {
//     'errorCode': WebResourceErrorType.RESOURCE_UNAVAILABLE,
//     'description': 'ERR_SSL_PROTOCOL_ERROR',
//   },
//   // Add more errors as needed
// ];

//=======================================================================
//list of allowed urls for load and show without url bar

const List<String> ALLOWED_URLS = [
  'google-analytics.com',
  'googletagmanager.com',
  'gstatic.com',
  'googleapis.com',
  'firebase.com',
  'firebaseio.com',
  'firebasestorage.googleapis.com',
  'firebasedynamiclinks.app.goo.gl',
  'firebasemessaging.googleapis.com',
  'firestore.googleapis.com',
  'doubleclick.net',
  'googleadservices.com',
  'googlesyndication.com',
  'g4a4.com'
];

//==========================================================================
//datalayer events list
// لیست ایونت‌ها
final List<Map<String, String>> DATA_LAYER_EVENTS_LIST = [
  {
    'event': 'application',
    'event_category': 'engagement',
    'event_label': 'application',
  },
  // {
  //   'event': 'page_view',
  //   'event_category': 'navigation',
  //   'event_label': 'home_page',
  // },
  // {
  //   'event': 'form_submit',
  //   'event_category': 'engagement',
  //   'event_label': 'contact_form',
  // },
  // اضافه کردن ایونت‌های بیشتر در اینجا
];
// ________________________________________________________________
//Gtag action form
const bool GTAG_ACTION = false;
const String GTAG_ACTION_Configuration = "G-3QJZP535ML";
