/// Helper pour la validation et le nettoyage des URLs d'images
class ImageHelper {
  /// Valide si une URL d'image est valide
  /// Vérifie les cas: null, undefined, espaces, URLs invalides
  static bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    
    // Vérifier si l'URL n'est pas juste des espaces ou des caractères spéciaux
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || 
        trimmedUrl.toLowerCase() == 'null' || 
        trimmedUrl.toLowerCase() == 'undefined' ||
        trimmedUrl == 'null' ||
        trimmedUrl == 'undefined') {
      return false;
    }
    
    try {
      final uri = Uri.parse(trimmedUrl);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Nettoie et valide une URL d'image
  /// Retourne null si l'URL est invalide
  static String? cleanImageUrl(String? url) {
    if (url == null) return null;
    
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || 
        trimmedUrl.toLowerCase() == 'null' || 
        trimmedUrl.toLowerCase() == 'undefined') {
      return null;
    }
    
    if (isValidImageUrl(trimmedUrl)) {
      return trimmedUrl;
    }
    
    return null;
  }

  /// Filtre une liste d'URLs pour ne garder que les valides
  static List<String> filterValidImageUrls(List<String?>? urls) {
    if (urls == null || urls.isEmpty) return [];
    
    final validUrls = <String>[];
    for (final url in urls) {
      final cleanedUrl = cleanImageUrl(url);
      if (cleanedUrl != null) {
        validUrls.add(cleanedUrl);
      }
    }
    
    return validUrls;
  }
}

