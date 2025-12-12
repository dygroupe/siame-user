import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/helper/image_helper.dart';
import 'package:sixam_mart/util/images.dart';

class ItemImageViewWidget extends StatelessWidget {
  final Item? item;
  final bool isCampaign;
  ItemImageViewWidget({super.key, required this.item, this.isCampaign = false});

  final PageController _controller = PageController();

  /// Obtient la liste des images valides
  List<String> _getValidImageList() {
    if (item == null) return [];
    
    final List<String> validImages = [];
    
    // Ajouter l'image principale si valide
    if (ImageHelper.isValidImageUrl(item!.imageFullUrl)) {
      validImages.add(item!.imageFullUrl!);
    }
    
    // Ajouter les images supplémentaires valides
    if (item!.imagesFullUrl != null && item!.imagesFullUrl!.isNotEmpty) {
      for (final url in item!.imagesFullUrl!) {
        if (ImageHelper.isValidImageUrl(url)) {
          validImages.add(url!);
        }
      }
    }
    
    return validImages;
  }

  @override
  Widget build(BuildContext context) {
    // Vérification de sécurité pour l'item
    if (item == null) {
      return SizedBox(
        height: ResponsiveHelper.isDesktop(context) ? 350 : MediaQuery.of(context).size.width * 0.7,
        child: Center(
          child: Image.asset(Images.placeholder, width: 100, height: 100),
        ),
      );
    }

    // Obtenir la liste des images valides
    final List<String> imageList = _getValidImageList();
    
    // Si aucune image n'est disponible, afficher un placeholder
    if (imageList.isEmpty) {
      return SizedBox(
        height: ResponsiveHelper.isDesktop(context) ? 350 : MediaQuery.of(context).size.width * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(Images.placeholder, width: 100, height: 100),
              const SizedBox(height: 10),
              Text('no_image_available'.tr, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return GetBuilder<ItemController>(builder: (itemController) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: isCampaign ? null : () {
            try {
              if (!isCampaign && item != null) {
                Navigator.of(context).pushNamed(
                  RouteHelper.getItemImagesRoute(item!),
                  arguments: ItemImageViewWidget(item: item),
                );
              }
            } catch (e) {
              print('Erreur lors de la navigation vers les images: $e');
            }
          },
          child: Stack(children: [
            SizedBox(
              height: ResponsiveHelper.isDesktop(context) ? 350 : MediaQuery.of(context).size.width * 0.7,
              child: PageView.builder(
                controller: _controller,
                itemCount: imageList.length,
                itemBuilder: (context, index) {
                  // Vérification de sécurité de l'index
                  if (index < 0 || index >= imageList.length) {
                    return Center(
                      child: Image.asset(Images.placeholder, width: 100, height: 100),
                    );
                  }
                  
                  final imageUrl = imageList[index];
                  if (!ImageHelper.isValidImageUrl(imageUrl)) {
                    return Center(
                      child: Image.asset(Images.placeholder, width: 100, height: 100),
                    );
                  }
                  
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomImage(
                      image: imageUrl,
                      height: 200,
                      width: MediaQuery.of(context).size.width,
                      useHighQuality: true, // Haute qualité pour les images de détail
                    ),
                  );
                },
                onPageChanged: (index) {
                  try {
                    if (index >= 0 && index < imageList.length) {
                      itemController.setImageSliderIndex(index);
                    }
                  } catch (e) {
                    print('Erreur lors du changement de page: $e');
                  }
                },
              ),
            ),
            imageList.length > 1 ? Positioned(
              left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _indicators(context, itemController, imageList),
                ),
              ),
            ) : const SizedBox(),
          ]),
        ),
      ]);
    });
  }

  List<Widget> _indicators(BuildContext context, ItemController itemController, List<String> imageList) {
    List<Widget> indicators = [];
    for (int index = 0; index < imageList.length; index++) {
      indicators.add(TabPageSelectorIndicator(
        backgroundColor: index == itemController.imageSliderIndex ? Theme.of(context).primaryColor : Colors.white,
        borderColor: Colors.white,
        size: 10,
      ));
    }
    return indicators;
  }

}
