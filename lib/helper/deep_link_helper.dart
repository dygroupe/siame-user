/// Helper pour le deep link de retour paiement Wave (siame://payment).
/// Utilisé côté Flutter pour parser l'URL et naviguer vers l'écran de résultat.
class DeepLinkHelper {
  static const String scheme = 'siame';
  static const String paymentHost = 'payment';
  static const String paramStatus = 'status';
  static const String paramOrderId = 'order_id';
  static const String paramContactNumber = 'contact_number';
  static const String paramGuestId = 'guest_id';
  static const String paramCreateAccount = 'create_account';

  static const String statusSuccess = 'success';
  static const String statusFailed = 'failed';
  static const String statusCancel = 'cancel';

  /// Lien initial reçu au lancement (cold start) — utilisé par le splash pour rediriger.
  static String? initialPaymentDeepLink;
  static String? takeInitialPaymentDeepLink() {
    final link = initialPaymentDeepLink;
    initialPaymentDeepLink = null;
    return link;
  }

  /// Vérifie si l'URL est un deep link de retour paiement Siame.
  static bool isPaymentDeepLink(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == scheme &&
        (uri.host == paymentHost || uri.path == '/payment' || url.startsWith('$scheme://$paymentHost'));
  }

  /// Parse les paramètres du deep link paiement.
  /// Retourne null si l'URL n'est pas un deep link paiement valide.
  static PaymentDeepLinkPayload? parsePaymentDeepLink(String? url) {
    if (!isPaymentDeepLink(url)) return null;
    final uri = Uri.tryParse(url!);
    if (uri == null) return null;

    final orderId = uri.queryParameters[paramOrderId];
    if (orderId == null || orderId.isEmpty) return null;

    return PaymentDeepLinkPayload(
      status: uri.queryParameters[paramStatus] ?? statusFailed,
      orderId: orderId,
      contactNumber: uri.queryParameters[paramContactNumber],
      guestId: uri.queryParameters[paramGuestId] ?? '',
      createAccount: uri.queryParameters[paramCreateAccount] == 'true',
    );
  }
}

class PaymentDeepLinkPayload {
  final String status;
  final String orderId;
  final String? contactNumber;
  final String guestId;
  final bool createAccount;

  PaymentDeepLinkPayload({
    required this.status,
    required this.orderId,
    this.contactNumber,
    this.guestId = '',
    this.createAccount = false,
  });

  bool get isSuccess => DeepLinkHelper.statusSuccess == status;
  bool get isFailed => DeepLinkHelper.statusFailed == status;
  bool get isCancel => DeepLinkHelper.statusCancel == status;
}
