import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photo_sorter/sorter.dart';

void main() {
  test('dates from common file names', () {
    expect(dateFromName('IMG_20190512_183005.jpg'), DateTime(2019, 5, 12, 18, 30, 5));
    expect(dateFromName('IMG-20210301-WA0007.jpg'), DateTime(2021, 3, 1, 12));
    expect(dateFromName('Screenshot_2020-07-04-09-15-33-123_com.app.png'), DateTime(2020, 7, 4, 9, 15, 33));
    expect(dateFromName('VID_20180101_000001.mp4'), DateTime(2018, 1, 1, 0, 0, 1));
    expect(dateFromName('PXL_20231225_101010123.jpg'), DateTime(2023, 12, 25, 10, 10, 10));
    expect(dateFromName('photo.jpg'), isNull);
    expect(dateFromName('IMG_20191399_000000.jpg'), isNull);
    expect(dateFromName('1700000000000.jpg'), isNull);
  });

  test('EXIF DateTimeOriginal is read from a JPEG', () {
    final im = img.Image(width: 8, height: 8);
    im.exif.exifIfd['DateTimeOriginal'] = '2017:08:20 14:05:09';
    final jpg = img.encodeJpg(im);
    expect(exifDate(jpg), DateTime(2017, 8, 20, 14, 5, 9));
    expect(parseExifDate('0000:00:00 00:00:00'), isNull);
  });
}
