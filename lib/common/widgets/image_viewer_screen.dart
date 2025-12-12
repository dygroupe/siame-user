import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/helper/image_helper.dart';
import 'package:sixam_mart/util/images.dart';

class ImageViewerScreen extends StatelessWidget {
  final Item item;
  final bool isCampaign;
  const ImageViewerScreen({super.key, required this.item, this.isCampaign = false});

  /// Obtient la liste des images valides
  List<String> _getValidImageList() {
    final List<String> validImages = [];
    
    // Ajouter l'image principale si valide
    if (ImageHelper.isValidImageUrl(item.imageFullUrl)) {
      validImages.add(item.imageFullUrl!);
    }
    
    // Ajouter les images supplémentaires valides
    if (item.imagesFullUrl != null && item.imagesFullUrl!.isNotEmpty) {
      for (final url in item.imagesFullUrl!) {
        final cleanedUrl = ImageHelper.cleanImageUrl(url);
        if (cleanedUrl != null) {
          validImages.add(cleanedUrl);
        }
      }
    }
    
    return validImages;
  }

  /// Construit un scaffold d'erreur
  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      appBar: CustomAppBar(title: 'product_images'.tr),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(Images.placeholder, width: 100, height: 100),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'no_images_available'.tr,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Obtenir la liste des images valides
      final List<String> imageList = _getValidImageList();
      
      // Si aucune image n'est disponible, afficher un message d'erreur
      if (imageList.isEmpty) {
        return _buildErrorScaffold('no_images_available'.tr);
      }

      // Initialiser l'index de l'image
      try {
        Get.find<ItemController>().setImageIndex(0, false);
      } catch (e) {
        // Ignorer silencieusement l'erreur d'initialisation
        debugPrint('Erreur lors de l\'initialisation de l\'index: $e');
      }
      
      final PageController pageController = PageController();

      return Scaffold(
        appBar: CustomAppBar(title: 'product_images'.tr),
        body: GetBuilder<ItemController>(builder: (itemController) {
          return Column(children: [
            Expanded(child: Stack(children: [
              PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                backgroundDecoration: BoxDecoration(color: Theme.of(context).cardColor),
                itemCount: imageList.length,
                pageController: pageController,
                builder: (BuildContext context, int index) {
                  // Vérification de sécurité de l'index
                  if (index < 0 || index >= imageList.length) {
                    // Utiliser un placeholder valide comme imageProvider
                    return PhotoViewGalleryPageOptions(
                      imageProvider: AssetImage(Images.placeholder),
                      initialScale: PhotoViewComputedScale.contained,
                      heroAttributes: PhotoViewHeroAttributes(tag: 'placeholder_$index'),
                    );
                  }
                  
                  final imageUrl = imageList[index];
                  if (!ImageHelper.isValidImageUrl(imageUrl)) {
                    // Utiliser un placeholder valide comme imageProvider
                    return PhotoViewGalleryPageOptions(
                      imageProvider: AssetImage(Images.placeholder),
                      initialScale: PhotoViewComputedScale.contained,
                      heroAttributes: PhotoViewHeroAttributes(tag: 'invalid_$index'),
                    );
                  }
                  
                  return PhotoViewGalleryPageOptions(
                    imageProvider: kIsWeb 
                        ? NetworkImage('${AppConstants.baseUrl}/image-proxy?url=$imageUrl') 
                        : NetworkImage(imageUrl),
                    initialScale: PhotoViewComputedScale.contained,
                    heroAttributes: PhotoViewHeroAttributes(tag: index.toString()),
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(Images.placeholder, width: 100, height: 100),
                            const SizedBox(height: 10),
                            Text('no_image_available'.tr, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    },
                  );
                },
                loadingBuilder: (context, event) {
                  if (event == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Center(
                    child: SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        value: event.expectedTotalBytes != null && event.expectedTotalBytes! > 0
                            ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                onPageChanged: (int index) {
                  try {
                    if (index >= 0 && index < imageList.length) {
                      itemController.setImageIndex(index, true);
                    }
                  } catch (e) {
                    debugPrint('Erreur lors du changement de page: $e');
                  }
                },
              ),

              // Bouton précédent
              itemController.imageIndex > 0 && imageList.length > 1 ? Positioned(
                left: 5, top: 0, bottom: 0,
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: InkWell(
                    onTap: () {
                      try {
                        final newIndex = itemController.imageIndex - 1;
                        if (newIndex >= 0 && newIndex < imageList.length) {
                          pageController.animateToPage(
                            newIndex,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      } catch (e) {
                        debugPrint('Erreur lors de la navigation précédente: $e');
                      }
                    },
                    child: const Icon(Icons.chevron_left_outlined, size: 40),
                  ),
                ),
              ) : const SizedBox(),

              // Bouton suivant
              itemController.imageIndex < imageList.length - 1 && imageList.length > 1 ? Positioned(
                right: 5, top: 0, bottom: 0,
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: InkWell(
                    onTap: () {
                      try {
                        final newIndex = itemController.imageIndex + 1;
                        if (newIndex >= 0 && newIndex < imageList.length) {
                          pageController.animateToPage(
                            newIndex,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      } catch (e) {
                        debugPrint('Erreur lors de la navigation suivante: $e');
                      }
                    },
                    child: const Icon(Icons.chevron_right_outlined, size: 40),
                  ),
                ),
              ) : const SizedBox(),

            ])),
          ]);
        }),
      );
    } catch (e) {
      debugPrint('Erreur critique dans ImageViewerScreen: $e');
      return _buildErrorScaffold('Erreur inattendue: ${e.toString()}');
    }
  }
}