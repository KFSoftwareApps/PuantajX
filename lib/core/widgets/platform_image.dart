import 'package:flutter/material.dart';
import 'platform_image_stub.dart' 
    if (dart.library.io) 'platform_image_mobile.dart'
    if (dart.library.html) 'platform_image_web.dart';

abstract class PlatformImageImpl extends StatelessWidget {
  final String path;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const PlatformImageImpl({
    super.key, 
    required this.path, 
    this.fit,
    this.errorBuilder,
  });

  factory PlatformImageImpl.create({
    required String path, 
    BoxFit? fit,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) = PlatformImage;
}
