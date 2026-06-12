import 'dart:io';
import 'package:image/image.dart';

void main() {
  var bytes = File('assets/app_logo.png').readAsBytesSync();
  var img = decodeImage(bytes);
  if (img != null) {
    File('assets/app_logo.png').writeAsBytesSync(encodePng(img));
    print('Fixed assets/app_logo.png');
  } else {
    print('Failed to decode image');
  }
}
