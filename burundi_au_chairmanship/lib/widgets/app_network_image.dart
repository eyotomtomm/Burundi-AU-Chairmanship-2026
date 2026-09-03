import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/data_saver_service.dart';

/// Drop-in for [CachedNetworkImage] that decodes to a bounded width so list
/// thumbnails don't hold full-resolution bitmaps in memory. Data Saver
/// shrinks the bound further (see [DataSaverService]).
///
/// Use `hero: true` for full-width carousel / header images.
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final bool hero;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final saver = DataSaverService();
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      placeholder: placeholder,
      errorWidget: errorWidget,
      memCacheWidth: hero ? saver.heroCacheWidth : saver.thumbnailCacheWidth,
    );
  }
}
