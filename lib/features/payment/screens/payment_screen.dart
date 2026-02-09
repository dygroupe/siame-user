import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sixam_mart/features/checkout/widgets/payment_failed_dialog.dart';
import 'package:sixam_mart/features/wallet/widgets/fund_payment_dialog_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final OrderModel orderModel;
  final bool isCashOnDelivery;
  final String? addFundUrl;
  final String paymentMethod;
  final String guestId;
  final String contactNumber;
  final String? subscriptionUrl;
  final int? storeId;
  final bool createAccount;
  final int? createUserId;
  const PaymentScreen({super.key, required this.orderModel, required this.isCashOnDelivery, this.addFundUrl, required this.paymentMethod,
    required this.guestId, required this.contactNumber, this.storeId, this.subscriptionUrl, this.createAccount = false, this.createUserId});

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  late String selectedUrl;
  double value = 0.0;
  final bool _isLoading = true;
  PullToRefreshController? pullToRefreshController;
  late MyInAppBrowser browser;
  double? _maximumCodOrderAmount;

  @override
  void initState() {
    super.initState();

    if(widget.addFundUrl == '' && widget.addFundUrl!.isEmpty && widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty){
      selectedUrl = '${AppConstants.baseUrl}/payment-mobile?customer_id=${widget.createAccount ? widget.createUserId : widget.orderModel.userId == 0 ? widget.guestId : widget.orderModel.userId}&order_id=${widget.orderModel.id}&payment_method=${widget.paymentMethod}';
    } else if(widget.subscriptionUrl != '' && widget.subscriptionUrl!.isNotEmpty){
      selectedUrl = widget.subscriptionUrl!;
    } else{
      selectedUrl = widget.addFundUrl!;
    }

    if (kDebugMode) {
      print('==========url=======> $selectedUrl');
    }

    _initData();
  }

  void _initData() async {

    if(widget.addFundUrl == '' && widget.addFundUrl!.isEmpty && widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty){
      for(ZoneData zData in AddressHelper.getUserAddressFromSharedPref()!.zoneData!) {
        for(Modules m in zData.modules!) {
          if(m.id == Get.find<SplashController>().module!.id) {
            _maximumCodOrderAmount = m.pivot!.maximumCodOrderAmount;
            break;
          }
        }
      }
    }

    browser = MyInAppBrowser(
      orderID: widget.orderModel.id.toString(), orderType: widget.orderModel.orderType,
      orderAmount: widget.orderModel.orderAmount, maxCodOrderAmount: _maximumCodOrderAmount,
      isCashOnDelivery: widget.isCashOnDelivery, addFundUrl: widget.addFundUrl,
      contactNumber: widget.contactNumber, storeId: widget.storeId,
      subscriptionUrl: widget.subscriptionUrl, createAccount: widget.createAccount,
      guestId: widget.guestId,
    );

    if(GetPlatform.isAndroid){
      await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);

      bool swAvailable = await WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE);
      bool swInterceptAvailable = await WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_SHOULD_INTERCEPT_REQUEST);

      if (swAvailable && swInterceptAvailable) {
        ServiceWorkerController serviceWorkerController = ServiceWorkerController.instance();
        await serviceWorkerController.setServiceWorkerClient(ServiceWorkerClient(
          shouldInterceptRequest: (request) async {
            if (kDebugMode) {
              print(request);
            }
            return null;
          },
        ));
      }
    }

    await browser.openUrlRequest(
      urlRequest: URLRequest(url: WebUri(selectedUrl)),
      settings: InAppBrowserClassSettings(
        webViewSettings: InAppWebViewSettings(useShouldOverrideUrlLoading: true, useOnLoadResource: true),
        browserSettings: InAppBrowserSettings(hideUrlBar: true, hideToolbarTop: GetPlatform.isAndroid),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _exitApp().then((value) => value!);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: CustomAppBar(title: 'payment'.tr, onBackPressed: () => _exitApp()),
        body: Center(
          child: SizedBox(
            width: Dimensions.webMaxWidth,
            child: Stack(
              children: [
                _isLoading ? Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                ) : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _exitApp() async {
    if((widget.addFundUrl == null || widget.addFundUrl!.isEmpty) && (widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty)){
      return Get.dialog(PaymentFailedDialog(
        orderID: widget.orderModel.id.toString(), orderAmount: widget.orderModel.orderAmount,
        maxCodOrderAmount: _maximumCodOrderAmount, orderType: widget.orderModel.orderType,
        isCashOnDelivery: widget.isCashOnDelivery, guestId: widget.createAccount ? widget.createUserId.toString() : widget.guestId,
      ));
    } else{
      return Get.dialog(FundPaymentDialogWidget(isSubscription: widget.subscriptionUrl != null && widget.subscriptionUrl!.isNotEmpty));
    }
  }

}

class MyInAppBrowser extends InAppBrowser {
  final String orderID;
  final String? orderType;
  final double? orderAmount;
  final double? maxCodOrderAmount;
  final bool isCashOnDelivery;
  final String? addFundUrl;
  final String? subscriptionUrl;
  final String? contactNumber;
  final int? storeId;
  final bool createAccount;
  final String guestId;

  MyInAppBrowser({
    super.windowId, super.initialUserScripts,
    required this.orderID, required this.orderType, required this.orderAmount,
    required this.maxCodOrderAmount, required this.isCashOnDelivery,
    this.addFundUrl, this.subscriptionUrl, this.contactNumber, this.storeId,
    required this.createAccount, required this.guestId});

  final bool _canRedirect = true;

  /// Ouvre une URL externe (Wave, Max It, Orange Money) et gère les fallbacks
  Future<void> _openExternalUrl(String raw) async {
    try {
      // Fallback store pour Max It : App Store sur iOS, Play Store sur Android
      final String maxItStoreUrl = defaultTargetPlatform == TargetPlatform.iOS
          ? 'https://apps.apple.com/app/id1039327980' // Orange Max it Sénégal
          : 'https://play.google.com/store/apps/details?id=com.orange.myorange.osn';

      // Intent URL (Android) - envoyé par le backend pour Max It (gère aussi les formats mal formatés)
      if (raw.startsWith('intent://') || raw.startsWith('intent:/')) {
        // Corriger le format de l'URL si nécessaire
        String correctedUrl = raw;
        if (raw.startsWith('intent:/') && !raw.startsWith('intent://')) {
          correctedUrl = raw.replaceFirst('intent:/', 'intent://');
        }
        try {
          final Uri intentUri = Uri.parse(correctedUrl);
          if (await canLaunchUrl(intentUri)) {
            await launchUrl(intentUri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Erreur lors de l\'ouverture de Max It avec l\'URL: $correctedUrl - $e');
          }
        }
        await launchUrl(Uri.parse(maxItStoreUrl), mode: LaunchMode.externalApplication);
        return;
      }
      // Wave avec capture
      if (raw.startsWith('wave://capture/')) {
        final String afterCapture = raw.substring('wave://capture/'.length);
        final Uri waveUri = Uri.parse(raw);
        if (await canLaunchUrl(waveUri)) {
          await launchUrl(waveUri, mode: LaunchMode.externalApplication);
          return;
        }
        final Uri httpsUri = Uri.parse(afterCapture);
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Max It (gère aussi les formats mal formatés)
      if (raw.startsWith('maxit://') || raw.startsWith('maxit:/')) {
        // Corriger le format de l'URL si nécessaire
        String correctedUrl = raw;
        if (raw.startsWith('maxit:/') && !raw.startsWith('maxit://')) {
          correctedUrl = raw.replaceFirst('maxit:/', 'maxit://');
        }
        try {
          final Uri maxItUri = Uri.parse(correctedUrl);
          if (await canLaunchUrl(maxItUri)) {
            await launchUrl(maxItUri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Erreur lors de l\'ouverture de Max It avec l\'URL: $correctedUrl - $e');
          }
        }
        await launchUrl(Uri.parse(maxItStoreUrl), mode: LaunchMode.externalApplication);
        return;
      }

      // Max It (schéma officiel Sonatel : sameaosnapp)
      // Gère aussi les formats mal formatés (sameaosnapp:/ au lieu de sameaosnapp://)
      if (raw.startsWith('sameaosnapp://') || raw.startsWith('sameaosnapp:/')) {
        // Corriger le format de l'URL si nécessaire
        String correctedUrl = raw;
        if (raw.startsWith('sameaosnapp:/') && !raw.startsWith('sameaosnapp://')) {
          correctedUrl = raw.replaceFirst('sameaosnapp:/', 'sameaosnapp://');
        }
        try {
          final Uri maxItUri = Uri.parse(correctedUrl);
          if (await canLaunchUrl(maxItUri)) {
            await launchUrl(maxItUri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Erreur lors de l\'ouverture de Max It avec l\'URL: $correctedUrl - $e');
          }
        }
        await launchUrl(Uri.parse(maxItStoreUrl), mode: LaunchMode.externalApplication);
        return;
      }
      
      // Orange Money
      if (raw.startsWith('orangemoney://') || 
          raw.startsWith('orange-money://') || 
          raw.startsWith('om://')) {
        final Uri orangeMoneyUri = Uri.parse(raw);
        if (await canLaunchUrl(orangeMoneyUri)) {
          await launchUrl(orangeMoneyUri, mode: LaunchMode.externalApplication);
          return;
        }
        final String orangeMoneyStoreUrl = defaultTargetPlatform == TargetPlatform.iOS
            ? 'https://apps.apple.com/app/orange-money-senegal/id1447224280' // Orange Money Sénégal
            : 'https://play.google.com/store/apps/details?id=com.orange.orangemoney';
        await launchUrl(Uri.parse(orangeMoneyStoreUrl), mode: LaunchMode.externalApplication);
        return;
      }

      // Wave standard
      if (raw.startsWith('wave://')) {
        final Uri waveUri = Uri.parse(raw);
        if (await canLaunchUrl(waveUri)) {
          await launchUrl(waveUri, mode: LaunchMode.externalApplication);
          return;
        }
        final String waveStoreUrl = defaultTargetPlatform == TargetPlatform.iOS
            ? 'https://apps.apple.com/app/wave-mobile-money/id1523884528'
            : 'https://play.google.com/store/apps/details?id=com.wave.personal';
        await launchUrl(Uri.parse(waveStoreUrl), mode: LaunchMode.externalApplication);
        return;
      }
      
      // Autres URLs
      final uri = Uri.parse(raw);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    // Fallback par défaut si aucune URL n'a été lancée
  }

  @override
  Future onBrowserCreated() async {
    if (kDebugMode) {
      print("\n\nBrowser Created!\n\n");
    }
  }

  @override
  Future onLoadStart(url) async {
    if (kDebugMode) {
      print("\n\nStarted: $url\n\n");
    }
    final current = url.toString();
    // Intercepte les schémas personnalisés (y compris les formats mal formatés)
    if (current.startsWith('wave://') || 
        current.startsWith('maxit://') || 
        current.startsWith('sameaosnapp://') || 
        current.startsWith('orangemoney://') || 
        current.startsWith('orange-money://') || 
        current.startsWith('om://') || 
        current.startsWith('intent://') ||
        current.startsWith('sameaosnapp:/') ||
        current.startsWith('maxit:/') ||
        current.startsWith('intent:/')) {
      await _openExternalUrl(current);
      return;
    }
    Get.find<OrderController>().paymentRedirect(
      url: url.toString(), canRedirect: _canRedirect, onClose: () => close(),
      addFundUrl: addFundUrl, orderID: orderID, contactNumber: contactNumber, storeId: storeId,
      subscriptionUrl: subscriptionUrl, createAccount: createAccount, guestId: guestId,
    );

  }


  @override
  Future onLoadStop(url) async {
    pullToRefreshController?.endRefreshing();
    if (kDebugMode) {
      print("\n\nStopped: $url\n\n");
    }
    Get.find<OrderController>().paymentRedirect(
      url: url.toString(), canRedirect: _canRedirect, onClose: () => close(),
      addFundUrl: addFundUrl, orderID: orderID, contactNumber: contactNumber, storeId: storeId,
      subscriptionUrl: subscriptionUrl, createAccount: createAccount, guestId: guestId,
    );
  }

  // @override
  // Future<ServerTrustAuthResponse?>? onReceivedServerTrustAuthRequest(URLAuthenticationChallenge challenge) async {
  //   if (kDebugMode) {
  //     print("\n\n onReceivedServerTrustAuthRequest: ${challenge.toString()}\n\n");
  //   }
  //   return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
  // }
  //
  // @override
  // Future<ShouldAllowDeprecatedTLSAction?>? shouldAllowDeprecatedTLS(URLAuthenticationChallenge challenge) async {
  //   if (kDebugMode) {
  //     print("\n\n shouldAllowDeprecatedTLS: ${challenge.protectionSpace.host}\n\n");
  //   }
  //   return ShouldAllowDeprecatedTLSAction.ALLOW;
  // }

  @override
  void onLoadError(url, code, message) {
    pullToRefreshController?.endRefreshing();
    if (kDebugMode) {
      print("Can't load [$url] Error: $message");
    }
    final failing = url.toString();
    final errorMessage = message.toString();
    
    // Gère les erreurs pour les schémas personnalisés (y compris ERR_UNKNOWN_URL_SCHEME)
    // Gère aussi les formats mal formatés
    if (failing.startsWith('wave://') || 
        failing.startsWith('maxit://') || 
        failing.startsWith('sameaosnapp://') || 
        failing.startsWith('orangemoney://') || 
        failing.startsWith('orange-money://') || 
        failing.startsWith('om://') || 
        failing.startsWith('intent://') ||
        failing.startsWith('sameaosnapp:/') ||
        failing.startsWith('maxit:/') ||
        failing.startsWith('intent:/') ||
        errorMessage.contains('ERR_UNKNOWN_URL_SCHEME')) {
      _openExternalUrl(failing);
    }
  }

  @override
  void onProgressChanged(progress) {
    if (progress == 100) {
      pullToRefreshController?.endRefreshing();
    }
    if (kDebugMode) {
      print("Progress: $progress");
    }
  }

  @override
  void onExit() {
    if (kDebugMode) {
      print("\n\nBrowser closed!\n\n");
    }
  }

  @override
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(navigationAction) async {
    if (kDebugMode) {
      print("\n\nOverride ${navigationAction.request.url}\n\n");
    }
    final uri = navigationAction.request.url;
    final url = uri?.toString() ?? '';
    // Intercepte les schémas personnalisés (y compris les formats mal formatés)
    if (url.startsWith('wave://') || 
        url.startsWith('maxit://') || 
        url.startsWith('sameaosnapp://') || 
        url.startsWith('orangemoney://') || 
        url.startsWith('orange-money://') || 
        url.startsWith('om://') || 
        url.startsWith('intent://') ||
        url.startsWith('sameaosnapp:/') ||
        url.startsWith('maxit:/') ||
        url.startsWith('intent:/')) {
      await _openExternalUrl(url);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  @override
  void onLoadResource(resource) {
    if (kDebugMode) {
      print("Started at: ${resource.startTime}ms ---> duration: ${resource.duration}ms ${resource.url ?? ''}");
    }
  }

  @override
  void onConsoleMessage(consoleMessage) {
    if (kDebugMode) {
      print("""
    console output:
      message: ${consoleMessage.message}
      messageLevel: ${consoleMessage.messageLevel.toValue()}
   """);
    }
  }


}