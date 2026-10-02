import 'package:flutter/material.dart';

import '../../../widgets/stickers/glossy_stickers.dart';

/// Preview grid for the native glossy animated stickers. Dark ground so the
/// white die-cut outline + volume read the way they will in the picker.
class StickerGalleryScreen extends StatelessWidget {
  const StickerGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = GlossySticker.values;
    return Scaffold(
      backgroundColor: const Color(0xFF15131C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15131C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Sticker (xem thử)'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.84,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final s = items[i];
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B27),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Center(child: GlossyStickerView(s, size: 96))),
                const SizedBox(height: 6),
                Text(
                  glossyStickerLabel(s),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
