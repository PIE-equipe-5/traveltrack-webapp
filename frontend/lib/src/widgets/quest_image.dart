import 'package:flutter/material.dart';

class QuestImage extends StatelessWidget {
  const QuestImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.black45),
      ),
    );

    if (imageUrl.trim().isEmpty) return placeholder();
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Impossible de charger l’image de quête : $error');
        return placeholder();
      },
    );
  }
}
