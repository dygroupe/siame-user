import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/helper/image_helper.dart';

class CustomImage extends StatelessWidget {
  final String image;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final bool isNotification;
  final String placeholder;
  final bool isHovered;
  final Color? color;
  /// Désactive l'optimisation de cache pour les images importantes (ex: page de détail)
  final bool useHighQuality;
  const CustomImage({super.key, required this.image, this.height, this.width, this.fit = BoxFit.cover, this.isNotification = false, this.placeholder = '', this.isHovered = false, this.color, this.useHighQuality = false});

  // Calcule cacheHeight et cacheWidth pour optimiser la mémoire GPU
  // Utilise la densité d'écran pour déterminer la taille optimale
  int? _getCacheHeight(BuildContext context) {
    if (height == null || height!.isInfinite || height!.isNaN) return null;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    if (devicePixelRatio.isInfinite || devicePixelRatio.isNaN || devicePixelRatio <= 0) return null;
    
    // Pour les images haute qualité (page de détail), on utilise une résolution plus élevée
    if (useHighQuality) {
      // Utilise jusqu'à 4x la densité d'écran pour une meilleure qualité
      final maxDensity = devicePixelRatio > 4.0 ? 4.0 : devicePixelRatio;
      final result = height! * maxDensity;
      if (result.isInfinite || result.isNaN || result <= 0) return null;
      return result.round();
    }
    
    // Pour les images normales (liste, grille), on limite à 3x pour économiser la mémoire GPU
    final maxDensity = devicePixelRatio > 3.0 ? 3.0 : devicePixelRatio;
    final result = height! * maxDensity;
    if (result.isInfinite || result.isNaN || result <= 0) return null;
    return result.round();
  }

  int? _getCacheWidth(BuildContext context) {
    if (width == null || width!.isInfinite || width!.isNaN) return null;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    if (devicePixelRatio.isInfinite || devicePixelRatio.isNaN || devicePixelRatio <= 0) return null;
    
    // Pour les images haute qualité (page de détail), on utilise une résolution plus élevée
    if (useHighQuality) {
      // Utilise jusqu'à 4x la densité d'écran pour une meilleure qualité
      final maxDensity = devicePixelRatio > 4.0 ? 4.0 : devicePixelRatio;
      final result = width! * maxDensity;
      if (result.isInfinite || result.isNaN || result <= 0) return null;
      return result.round();
    }
    
    // Pour les images normales (liste, grille), on limite à 3x pour économiser la mémoire GPU
    final maxDensity = devicePixelRatio > 3.0 ? 3.0 : devicePixelRatio;
    final result = width! * maxDensity;
    if (result.isInfinite || result.isNaN || result <= 0) return null;
    return result.round();
  }

  @override
  Widget build(BuildContext context) {
    final cacheHeight = _getCacheHeight(context);
    final cacheWidth = _getCacheWidth(context);
    
    // Valider l'URL de l'image
    final cleanedImageUrl = ImageHelper.cleanImageUrl(image);
    if (cleanedImageUrl == null) {
      // Afficher un placeholder si l'URL est invalide
      return Image.asset(
        placeholder.isNotEmpty ? placeholder : (isNotification ? Images.notificationPlaceholder : Images.placeholder),
        height: height,
        width: width,
        fit: fit,
        color: color,
      );
    }
    
    return AnimatedScale(
      scale: isHovered ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: CachedNetworkImage(
        color: color,
        imageUrl: kIsWeb ? '${AppConstants.baseUrl}/image-proxy?url=$cleanedImageUrl' : cleanedImageUrl,
        height: height,
        width: width,
        fit: fit,
        // Optimisation mémoire GPU : limite la résolution des images en cache
        // Pour les images haute qualité, on désactive les limitations de cache
        memCacheHeight: useHighQuality ? null : cacheHeight,
        memCacheWidth: useHighQuality ? null : cacheWidth,
        // Optimisation mémoire GPU : limite la résolution des images lors du chargement
        maxHeightDiskCache: useHighQuality ? null : (cacheHeight != null && cacheHeight! > 0 ? (cacheHeight! * 1.5).round() : null),
        maxWidthDiskCache: useHighQuality ? null : (cacheWidth != null && cacheWidth! > 0 ? (cacheWidth! * 1.5).round() : null),
        placeholder: (context, url) => Image.asset(
          placeholder.isNotEmpty ? placeholder : (isNotification ? Images.notificationPlaceholder : Images.placeholder),
          height: height, width: width, fit: fit, color: color,
          // Optimisation pour les images locales aussi
          cacheHeight: cacheHeight,
          cacheWidth: cacheWidth,
        ),
        errorWidget: (context, url, error) => Image.asset(
          placeholder.isNotEmpty ? placeholder : (isNotification ? Images.notificationPlaceholder : Images.placeholder),
          height: height, width: width, fit: fit, color: color,
          // Optimisation pour les images locales aussi
          cacheHeight: cacheHeight,
          cacheWidth: cacheWidth,
        ),
      ),
    );
  }
}
