import 'dart:convert';
import 'package:flutter/material.dart';

import '../theme/lumina_theme.dart';

class ImagenProducto extends StatelessWidget {
  const ImagenProducto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: iconSize,
          color: LuminaColors.primary,
        ),
      );
    }

    final u = url!.trim();

    if (u.startsWith('data:image')) {
      try {
        final base64String = u.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(
              Icons.inventory_2_outlined,
              size: iconSize,
              color: LuminaColors.primary,
            ),
          ),
        );
      } catch (_) {
        return Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: iconSize,
            color: LuminaColors.primary,
          ),
        );
      }
    }

    return Image.network(
      u,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: iconSize,
          color: LuminaColors.primary,
        ),
      ),
    );
  }
}
