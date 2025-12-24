import 'package:flutter/material.dart';
import 'platform_image.dart';

class PlatformImage extends PlatformImageImpl {
  const PlatformImage({
    super.key, 
    required super.path, 
    super.fit,
    super.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      path,
      fit: fit ?? BoxFit.cover,
      errorBuilder: errorBuilder ?? (_,__,___) => const Center(child: Icon(Icons.broken_image)),
    );
  }
}
