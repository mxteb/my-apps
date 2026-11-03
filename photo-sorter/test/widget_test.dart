import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photo_sorter/sorter.dart';

img.Image _scene({int shift = 0}) {
  final im = img.Image(width: 200, height: 150);
  for (var y = 0; y < 150; y++) {
    for (var x = 0; x < 200; x++) {
      final v = ((x * 3 + y * 2 + shift) % 255);
      im.setPixelRgb(x, y, v, (x + y) % 255, (y * 4) % 255);
    }
  }
  img.fillCircle(im, x: 60, y: 70, radius: 30, color: img.ColorRgb8(250, 40, 40));
  return im;
}

void main() {
  test('dHash matches a resized, recompressed copy and differs from another image', () {
    final a = dHash(img.encodePng(_scene()))!;
    final resized = dHash(img.encodeJpg(img.copyResize(_scene(), width: 100), quality: 60))!;
    final other = img.Image(width: 200, height: 150);
    for (var x = 0; x < 200; x++) {
      for (var y = 0; y < 150; y++) {
        other.setPixelRgb(x, y, 255 - x, y, 128);
      }
    }
    final b = dHash(img.encodePng(other))!;
    int bits(int v) => v.toRadixString(2).replaceAll('0', '').length;
    expect(bits(a ^ resized), lessThanOrEqualTo(4));
    expect(bits(a ^ b), greaterThan(10));
  });

  test('findDuplicates marks the newer copy and ignores photo vs video', () {
    final r = findDuplicates([
      ['old', 0xFF00FF00, 0, 0, 400, 300],
      ['copy', 0xFF00FF01, 0, 0, 800, 600],
      ['video', 0xFF00FF00, 1, 12, 400, 300],
      ['different', 0x00FF00FF, 0, 0, 400, 300],
    ]);
    expect(r, {'copy': 'old'});
  });
}
