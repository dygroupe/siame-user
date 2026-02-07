import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/features/checkout/widgets/payment_failed_dialog.dart';
import 'package:sixam_mart/features/wallet/widgets/fund_payment_dialog_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final OrderModel orderModel;
  final bool isCashOnDelivery;
  final String? addFundUrl;
  final String paymentMethod;
  final String guestId;
  final String contactNumber;
  final String? subscriptionUrl;
  final int? storeId;
  final bool? createAccount;
  const PaymentWebViewScreen({super.key, required this.orderModel, required this.isCashOnDelivery, this.addFundUrl, required this.paymentMethod,
    required this.guestId, required this.contactNumber, this.subscriptionUrl, this.storeId, this.createAccount = false});

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentWebViewScreen> {
  late String selectedUrl;
  bool _isLoading = true;
  final bool _canRedirect = true;
  double? _maximumCodOrderAmount;
  PullToRefreshController? pullToRefreshController;
  InAppWebViewController? webViewController;
  final GlobalKey webViewKey = GlobalKey();

  /// Gère les URLs Wave et les redirige vers l'application Wave ou le Play Store
  Future<bool> _handleWaveUrl(String url, InAppWebViewController controller) async {
    try {
      if (url.startsWith('wave://capture/')) {
        final String afterCapture = url.substring('wave://capture/'.length);
        final Uri waveUri = Uri.parse(url);
        if (await canLaunchUrl(waveUri)) {
          await launchUrl(waveUri, mode: LaunchMode.externalApplication);
          return true;
        }
        // Fallback: ouvrir l'URL https sous-jacente
        final Uri httpsUri = Uri.parse(afterCapture);
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        final Uri waveUri = Uri.parse(url);
        if (await canLaunchUrl(waveUri)) {
          await launchUrl(waveUri, mode: LaunchMode.externalApplication);
          return true;
        }
      }
    } catch (_) {}
    // Si rien n'a été lancé, ouvrir le Play Store
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=com.wave.personal'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  /// Gère les URLs Max It et les redirige vers l'application Max It ou le Play Store
  Future<bool> _handleMaxItUrl(String url, InAppWebViewController controller) async {
    try {
      final Uri maxItUri = Uri.parse(url);
      if (await canLaunchUrl(maxItUri)) {
        await launchUrl(maxItUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    // Si rien n'a été lancé, ouvrir le Play Store pour Max It Sénégal
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=com.orange.myorange.osn'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  /// Gère les URLs Orange Money et les redirige vers l'application Orange Money ou le Play Store
  Future<bool> _handleOrangeMoneyUrl(String url, InAppWebViewController controller) async {
    try {
      final Uri orangeMoneyUri = Uri.parse(url);
      if (await canLaunchUrl(orangeMoneyUri)) {
        await launchUrl(orangeMoneyUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    // Si rien n'a été lancé, ouvrir le Play Store pour Orange Money
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=com.orange.orangemoney'),
      mode: LaunchMode.externalApplication,
    );
    return true;
  }

  /// Détecte le type d'URL de paiement et appelle la fonction appropriée
  Future<bool> _handlePaymentUrl(String url, InAppWebViewController controller) async {
    // Max It (schémas maxit:// et sameaosnapp://)
    if (url.startsWith('maxit://') || url.startsWith('sameaosnapp://')) {
      return await _handleMaxItUrl(url, controller);
    }
    // Orange Money
    if (url.startsWith('orangemoney://') || 
        url.startsWith('orange-money://') || 
        url.startsWith('om://')) {
      return await _handleOrangeMoneyUrl(url, controller);
    }
    // Wave
    if (url.startsWith('wave://')) {
      return await _handleWaveUrl(url, controller);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();

    if(widget.addFundUrl == '' && widget.addFundUrl!.isEmpty && widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty){
      selectedUrl = '${AppConstants.baseUrl}/payment-mobile?customer_id=${widget.orderModel.userId == 0 ? widget.guestId : widget.orderModel.userId}&order_id=${widget.orderModel.id}&payment_method=${widget.paymentMethod}';
    } else if(widget.subscriptionUrl != '' && widget.subscriptionUrl!.isNotEmpty){
      selectedUrl = widget.subscriptionUrl!;
    } else{
      selectedUrl = widget.addFundUrl!;
    }


    _initData();
  }

  void _initData() async {
    if(widget.addFundUrl == null  || (widget.addFundUrl != null && widget.addFundUrl!.isEmpty)){
      for(ZoneData zData in AddressHelper.getUserAddressFromSharedPref()!.zoneData!) {
        for(Modules m in zData.modules!) {
          if(m.id == Get.find<SplashController>().module!.id) {
            _maximumCodOrderAmount = m.pivot!.maximumCodOrderAmount;
            break;
          }
        }
      }
    }

    pullToRefreshController = GetPlatform.isWeb || ![TargetPlatform.iOS, TargetPlatform.android].contains(defaultTargetPlatform) ? null : PullToRefreshController(
      onRefresh: () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          webViewController?.reload();
        } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
          webViewController?.loadUrl(urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        _exitApp();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: CustomAppBar(title: '', onBackPressed: () => _exitApp(), backButton: true),
        body: Stack(
          children: [
            InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(url: WebUri(selectedUrl)),
              initialUserScripts: UnmodifiableListView<UserScript>([]),
              pullToRefreshController: pullToRefreshController,
              initialSettings: InAppWebViewSettings(
                isInspectable: kDebugMode,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: "camera; microphone",
                iframeAllowFullscreen: true,
              ),
              onWebViewCreated: (controller) async {
                webViewController = controller;
              },
              onLoadStart: (controller, url) async {
                final current = url?.toString() ?? '';
                if (current.startsWith('wave://') || 
                    current.startsWith('maxit://') || 
                    current.startsWith('sameaosnapp://') || 
                    current.startsWith('orangemoney://') || 
                    current.startsWith('orange-money://') || 
                    current.startsWith('om://')) {
                  await _handlePaymentUrl(current, controller);
                  return;
                }
                Get.find<OrderController>().paymentRedirect(
                  url: url.toString(), canRedirect: _canRedirect, onClose: (){} ,
                  addFundUrl: widget.addFundUrl, orderID: widget.orderModel.id.toString(), contactNumber: widget.contactNumber,
                  subscriptionUrl: widget.subscriptionUrl, storeId: widget.storeId, createAccount: widget.createAccount!,
                  guestId: widget.guestId,
                );
                setState(() {
                  _isLoading = true;
                });
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                Uri uri = navigationAction.request.url!;
                // Intercepte explicitement les schémas de paiement et ouvre l'app
                if (uri.scheme == "wave" || 
                    uri.scheme == "maxit" || 
                    uri.scheme == "sameaosnapp" || 
                    uri.scheme == "orangemoney" || 
                    uri.scheme == "orange-money" || 
                    uri.scheme == "om") {
                  await _handlePaymentUrl(uri.toString(), controller);
                  return NavigationActionPolicy.CANCEL;
                }
                if (!["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return NavigationActionPolicy.CANCEL;
                  }
                }
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStop: (controller, url) async {
                pullToRefreshController?.endRefreshing();
                setState(() {
                  _isLoading = false;
                });
                Get.find<OrderController>().paymentRedirect(
                  url: url.toString(), canRedirect: _canRedirect, onClose: (){} ,
                  addFundUrl: widget.addFundUrl, orderID: widget.orderModel.id.toString(), contactNumber: widget.contactNumber,
                  subscriptionUrl: widget.subscriptionUrl, storeId: widget.storeId, createAccount: widget.createAccount!,
                  guestId: widget.guestId,
                );
                // _redirect(url.toString());
              },
              onProgressChanged: (controller, progress) {
                if (progress == 100) {
                  pullToRefreshController?.endRefreshing();
                }
                // setState(() {
                //   _value = progress / 100;
                // });
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint(consoleMessage.message);
              },
              onReceivedError: (controller, request, error) async {
                final failing = request.url.toString();
                if (failing.startsWith('wave://') || 
                    failing.startsWith('maxit://') || 
                    failing.startsWith('sameaosnapp://') || 
                    failing.startsWith('orangemoney://') || 
                    failing.startsWith('orange-money://') || 
                    failing.startsWith('om://')) {
                  await _handlePaymentUrl(failing, controller);
                  return;
                }
              },
              onCreateWindow: (controller, action) async {
                final uri = action.request.url;
                if (uri == null) return false;
                final url = uri.toString();
                if (url.startsWith('wave://') || 
                    url.startsWith('maxit://') || 
                    url.startsWith('sameaosnapp://') || 
                    url.startsWith('orangemoney://') || 
                    url.startsWith('orange-money://') || 
                    url.startsWith('om://')) {
                  await _handlePaymentUrl(url, controller);
                  return true; // géré
                }
                return false;
              },
            ),
            _isLoading ? Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
            ) : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Future<bool?> _exitApp() async {
    if((widget.addFundUrl == null  || (widget.addFundUrl != null && widget.addFundUrl!.isEmpty)) || !Get.find<SplashController>().configModel!.digitalPaymentInfo!.pluginPaymentGateways!){
      return Get.dialog(PaymentFailedDialog(
        orderID: widget.orderModel.id.toString(),
        orderAmount: widget.orderModel.orderAmount,
        maxCodOrderAmount: _maximumCodOrderAmount,
        orderType: widget.orderModel.orderType,
        isCashOnDelivery: widget.isCashOnDelivery,
        guestId: widget.guestId,
      ));
    }else{
      return Get.dialog(FundPaymentDialogWidget(isSubscription: widget.subscriptionUrl != null && widget.subscriptionUrl!.isNotEmpty));
    }

  }

}