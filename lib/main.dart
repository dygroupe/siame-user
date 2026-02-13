import 'dart:async';
import 'dart:ui';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/notification_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/deep_link_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/theme/dark_theme.dart';
import 'package:app_links/app_links.dart';
import 'package:sixam_mart/theme/light_theme.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/messages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/widgets/cookies_view.dart';
import 'helper/get_di.dart' as di;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /*///Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };


  ///Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };*/

  if(GetPlatform.isWeb){
    await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: "AIzaSyD0Z911mOoWCVkeGdjhIKwWFPRgvd6ZyAw",
        authDomain: "stackmart-500c7.firebaseapp.com",
        projectId: "stackmart-500c7",
        storageBucket: "stackmart-500c7.appspot.com",
        messagingSenderId: "491987943015",
        appId: "1:491987943015:web:d8bc7ab8dbc9991c8f1ec2"
    ));
  } else if(GetPlatform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyBhoCakbF2BDT5V53XnWGIYfhtUTar99kA",
          appId: "1:926015535595:android:cc29bfe3bc21ebc53441ae",
          messagingSenderId: "926015535595",
          projectId: "siame-adfe1",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  Map<String, Map<String, String>> languages = await di.init();

  NotificationBodyModel? body;
  try {
    if (GetPlatform.isMobile) {
      final RemoteMessage? remoteMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (remoteMessage != null) {
        body = NotificationHelper.convertNotification(remoteMessage.data);
      }
      await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    }
  }catch(_) {}

  if (GetPlatform.isMobile) {
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      final uri = initial is Uri ? initial : (initial != null ? Uri.tryParse(initial.toString()) : null);
      if (uri != null) {
        final url = uri.toString();
        if (DeepLinkHelper.isPaymentDeepLink(url)) {
          DeepLinkHelper.initialPaymentDeepLink = url;
        }
      }
    } catch (_) {}
  }

  if (ResponsiveHelper.isWeb()) {
    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: "380903914182154",
      cookie: true,
      xfbml: true,
      version: "v15.0",
    );
  }

  runApp(MyApp(languages: languages, body: body));
}

class MyApp extends StatefulWidget {
  final Map<String, Map<String, String>>? languages;
  final NotificationBodyModel? body;
  const MyApp({super.key, required this.languages, required this.body});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    _route();
    if (GetPlatform.isMobile) {
      _listenToPaymentDeepLinks();
    }
  }

  void _listenToPaymentDeepLinks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLinks().uriLinkStream.listen((Uri? uri) {
        if (uri == null) return;
        final url = uri.toString();
        if (!DeepLinkHelper.isPaymentDeepLink(url)) return;
        final payload = DeepLinkHelper.parsePaymentDeepLink(url);
        if (payload != null) {
          Get.offNamed(RouteHelper.getOrderSuccessRoute(
            payload.orderId,
            payload.contactNumber,
            createAccount: payload.createAccount,
            guestId: payload.guestId,
          ));
        }
      });
    });
  }

  void _route() async {
    if(GetPlatform.isWeb) {
       Get.find<SplashController>().initSharedData();
      if(AddressHelper.getUserAddressFromSharedPref() != null && AddressHelper.getUserAddressFromSharedPref()!.zoneIds == null) {
        Get.find<AuthController>().clearSharedAddress();
      }

      if(!AuthHelper.isLoggedIn() && !AuthHelper.isGuestLoggedIn()) {
        await Get.find<AuthController>().guestLogin();
      }

      if((AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn()) && Get.find<SplashController>().cacheModule != null) {
        Get.find<CartController>().getCartDataOnline();
      }

      Get.find<SplashController>().getConfigData(loadLandingData: (GetPlatform.isWeb && AddressHelper.getUserAddressFromSharedPref() == null), fromMainFunction: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(builder: (themeController) {
      return GetBuilder<LocalizationController>(builder: (localizeController) {
        return GetBuilder<SplashController>(builder: (splashController) {
          return (GetPlatform.isWeb && splashController.configModel == null) ? const SizedBox() : GetMaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: Get.key,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
            ),
            theme: themeController.darkTheme ? dark() : light(),
            locale: localizeController.locale,
            translations: Messages(languages: widget.languages),
            fallbackLocale: Locale(AppConstants.languages[0].languageCode!, AppConstants.languages[0].countryCode),
            initialRoute: GetPlatform.isWeb ? RouteHelper.getInitialRoute() : RouteHelper.getSplashRoute(widget.body),
            getPages: RouteHelper.routes,
            defaultTransition: Transition.topLevel,
            transitionDuration: const Duration(milliseconds: 500),
            builder: (BuildContext context, widget) {
              return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)), child: Material(
                child: SafeArea(
                  top: false, bottom: GetPlatform.isAndroid,
                  child: Stack(children: [
                    widget!,

                    GetBuilder<SplashController>(builder: (splashController){
                      if(!splashController.savedCookiesData && !splashController.getAcceptCookiesStatus(splashController.configModel != null ? splashController.configModel!.cookiesText! : '')){
                        return ResponsiveHelper.isWeb() ? const Align(alignment: Alignment.bottomCenter, child: CookiesView()) : const SizedBox();
                      }else{
                        return const SizedBox();
                      }
                    })
                  ]),
                ),
              ));
            },
          );
        });
      });
    });
  }
}