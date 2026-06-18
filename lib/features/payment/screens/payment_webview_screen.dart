import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
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
import 'package:sixam_mart/helper/deep_link_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
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

  const PaymentWebViewScreen({
    super.key,
    required this.orderModel,
    required this.isCashOnDelivery,
    this.addFundUrl,
    required this.paymentMethod,
    required this.guestId,
    required this.contactNumber,
    this.subscriptionUrl,
    this.storeId,
    this.createAccount = false,
  });

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentWebViewScreen> {
  late String selectedUrl;
  bool _isPaymentInProgress = false;
  bool _isPaymentCompleted = false;
  double? _maximumCodOrderAmount;

  @override
  void initState() {
    super.initState();
    if (widget.addFundUrl == '' && widget.addFundUrl!.isEmpty && widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty) {
      selectedUrl = '${AppConstants.baseUrl}/payment-mobile?customer_id=${widget.orderModel.userId == 0 ? widget.guestId : widget.orderModel.userId}&order_id=${widget.orderModel.id}&payment_method=${widget.paymentMethod}'
          '&payment_platform=app'
          '&guest_id=${Uri.encodeComponent(widget.guestId)}'
          '&create_account=${widget.createAccount == true}'
          '&contact_number=${Uri.encodeComponent(widget.contactNumber)}';
    } else if (widget.subscriptionUrl != '' && widget.subscriptionUrl!.isNotEmpty) {
      selectedUrl = widget.subscriptionUrl!;
    } else {
      selectedUrl = widget.addFundUrl!;
    }
    _initData();
    _startPayment();
  }

  void _initData() async {
    if (widget.addFundUrl == null || (widget.addFundUrl != null && widget.addFundUrl!.isEmpty)) {
      for (ZoneData zData in AddressHelper.getUserAddressFromSharedPref()!.zoneData!) {
        for (Modules m in zData.modules!) {
          if (m.id == Get.find<SplashController>().module!.id) {
            _maximumCodOrderAmount = m.pivot!.maximumCodOrderAmount;
            break;
          }
        }
      }
    }
  }

  Future<void> _startPayment() async {
    setState(() => _isPaymentInProgress = true);

    try {
      final theme = Theme.of(context);
      await launchUrl(
        Uri.parse(selectedUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Erreur de lancement du paiement: $e');
      }
      _showPaymentError();
    }
  }

  Future<bool> _handleWaveUrl(String url) async {
    try {
      if (url.startsWith('wave://capture/')) {
        final String afterCapture = url.substring('wave://capture/'.length);
        final Uri waveUri = Uri.parse(url);
        if (await canLaunchUrl(waveUri)) {
          await launchUrl(waveUri, mode: LaunchMode.externalApplication);
          return true;
        }
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
    final String waveStoreUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/app/wave-mobile-money/id1523884528'
        : 'https://play.google.com/store/apps/details?id=com.wave.personal';
    await launchUrl(Uri.parse(waveStoreUrl), mode: LaunchMode.externalApplication);
    return true;
  }

  Future<bool> _handleMaxItUrl(String url) async {
    try {
      final Uri maxItUri = Uri.parse(url);
      try {
        await launchUrl(maxItUri, mode: LaunchMode.externalApplication);
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('Erreur lors de l\'ouverture de Max It avec l\'URL: $url - $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur dans _handleMaxItUrl: $e');
      }
    }

    final String storeUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/app/id1039327980'
        : 'https://play.google.com/store/apps/details?id=com.orange.myorange.osn';
    await launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication);
    return true;
  }

  Future<bool> _handleOrangeMoneyUrl(String url) async {
    try {
      final Uri orangeMoneyUri = Uri.parse(url);
      if (await canLaunchUrl(orangeMoneyUri)) {
        await launchUrl(orangeMoneyUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    final String orangeMoneyStoreUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/app/orange-money-senegal/id1447224280'
        : 'https://play.google.com/store/apps/details?id=com.orange.orangemoney';
    await launchUrl(Uri.parse(orangeMoneyStoreUrl), mode: LaunchMode.externalApplication);
    return true;
  }

  Future<bool> _handleSiamePaymentDeepLink(String url) async {
    final payload = DeepLinkHelper.parsePaymentDeepLink(url);
    if (payload == null) return false;

    setState(() => _isPaymentCompleted = true);
    Get.offNamed(RouteHelper.getOrderSuccessRoute(
      payload.orderId,
      payload.contactNumber,
      createAccount: payload.createAccount,
      guestId: payload.guestId,
    ));
    return true;
  }

  Future<bool> _handlePaymentUrl(String url) async {
    if (DeepLinkHelper.isPaymentDeepLink(url)) {
      return await _handleSiamePaymentDeepLink(url);
    }
    if (url.startsWith('maxit://') ||
        url.startsWith('sameaosnapp://') ||
        url.startsWith('intent://') ||
        url.startsWith('maxit:/') ||
        url.startsWith('sameaosnapp:/') ||
        url.startsWith('intent:/')) {
      return await _handleMaxItUrl(url);
    }
    if (url.startsWith('orangemoney://') ||
        url.startsWith('orange-money://') ||
        url.startsWith('om://')) {
      return await _handleOrangeMoneyUrl(url);
    }
    if (url.startsWith('wave://')) {
      return await _handleWaveUrl(url);
    }
    return false;
  }

  void _showPaymentError() {
    setState(() => _isPaymentInProgress = false);
    Get.dialog(PaymentFailedDialog(
      orderID: widget.orderModel.id.toString(),
      orderAmount: widget.orderModel.orderAmount,
      maxCodOrderAmount: _maximumCodOrderAmount,
      orderType: widget.orderModel.orderType,
      isCashOnDelivery: widget.isCashOnDelivery,
      guestId: widget.guestId,
    ));
  }

  Future<bool?> _exitApp() async {
    if ((widget.addFundUrl == null || (widget.addFundUrl != null && widget.addFundUrl!.isEmpty)) || !Get.find<SplashController>().configModel!.digitalPaymentInfo!.pluginPaymentGateways!) {
      return Get.dialog(PaymentFailedDialog(
        orderID: widget.orderModel.id.toString(),
        orderAmount: widget.orderModel.orderAmount,
        maxCodOrderAmount: _maximumCodOrderAmount,
        orderType: widget.orderModel.orderType,
        isCashOnDelivery: widget.isCashOnDelivery,
        guestId: widget.guestId,
      ));
    } else {
      return Get.dialog(FundPaymentDialogWidget(isSubscription: widget.subscriptionUrl != null && widget.subscriptionUrl!.isNotEmpty));
    }
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
        appBar: CustomAppBar(
          title: '',
          onBackPressed: () => _exitApp(),
          backButton: true,
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/image/payment_complete_gif.gif',
                        fit: BoxFit.contain,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                            strokeWidth: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Paiement en cours',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Veuillez patienter pendant le traitement du paiement...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).disabledColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPaymentIcon(widget.paymentMethod),
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getPaymentMethodName(widget.paymentMethod),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'wave':
        return Icons.payment_outlined;
      case 'orange_money':
      case 'orangemoney':
      case 'orange-money':
        return Icons.phone_android_outlined;
      case 'paystack':
        return Icons.credit_card_outlined;
      case 'flutterwave':
        return Icons.flash_on_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  String _getPaymentMethodName(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'wave':
        return 'Wave';
      case 'orange_money':
      case 'orangemoney':
      case 'orange-money':
        return 'Orange Money';
      case 'paystack':
        return 'Paystack';
      case 'flutterwave':
        return 'Flutterwave';
      default:
        return 'Paiement en ligne';
    }
  }
}
