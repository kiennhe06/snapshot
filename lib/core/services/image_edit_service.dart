import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Named color filter presets.
enum PhotoFilter { none, grayscale, sepia, warm, cool, vivid }

extension PhotoFilterLabel on PhotoFilter {
  String get label => switch (this) {
    PhotoFilter.none => 'Gốc',
    PhotoFilter.grayscale => 'Trắng đen',
    PhotoFilter.sepia => 'Sepia',
    PhotoFilter.warm => 'Ấm',
    PhotoFilter.cool => 'Lạnh',
    PhotoFilter.vivid => 'Rực rỡ',
  };
}

/// Applies non-destructive image edits (brightness/contrast/saturation + a
/// filter preset) using the pure-Dart `image` package, and writes the result to
/// a temporary file. Runs off the original so re-editing stays lossless-ish.
class ImageEditService {
  /// [brightness]/[contrast]/[saturation] are multipliers around 1.0.
  Future<File> apply({
    required File source,
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
    PhotoFilter filter = PhotoFilter.none,
  }) async {
    final bytes = await source.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return source;

    // Tone adjustments.
    image = img.adjustColor(
      image,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );

    // Filter preset.
    image = switch (filter) {
      PhotoFilter.none => image,
      PhotoFilter.grayscale => img.grayscale(image),
      PhotoFilter.sepia => img.sepia(image),
      PhotoFilter.warm => img.colorOffset(image, red: 25, green: 8, blue: -15),
      PhotoFilter.cool => img.colorOffset(image, red: -15, green: 0, blue: 25),
      PhotoFilter.vivid => img.adjustColor(
        image,
        saturation: 1.6,
        contrast: 1.1,
      ),
    };

    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/edit_${const Uuid().v4()}.jpg');
    await out.writeAsBytes(img.encodeJpg(image, quality: 90));
    return out;
  }
}
