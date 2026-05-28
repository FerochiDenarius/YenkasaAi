import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final projectRoot = Directory.current;
  final sourceFile = File(
    '${projectRoot.path}/assets/branding/app_icon_source.png',
  );
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing source icon: ${sourceFile.path}');
    exitCode = 1;
    return;
  }

  final decoded = img.decodeImage(sourceFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Unable to decode source icon.');
    exitCode = 1;
    return;
  }

  final macosTargets = <String, int>{
    'app_icon_16.png': 16,
    'app_icon_32.png': 32,
    'app_icon_64.png': 64,
    'app_icon_128.png': 128,
    'app_icon_256.png': 256,
    'app_icon_512.png': 512,
    'app_icon_1024.png': 1024,
  };

  final macosIconDir = Directory(
    '${projectRoot.path}/macos/Runner/Assets.xcassets/AppIcon.appiconset',
  );
  for (final entry in macosTargets.entries) {
    final resized = img.copyResize(
      decoded,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.average,
    );
    File('${macosIconDir.path}/${entry.key}')
        .writeAsBytesSync(img.encodePng(resized, level: 9));
  }

  final windowsResized = img.copyResize(
    decoded,
    width: 256,
    height: 256,
    interpolation: img.Interpolation.average,
  );
  final windowsIcon = File(
    '${projectRoot.path}/windows/runner/resources/app_icon.ico',
  );
  windowsIcon.writeAsBytesSync(img.encodeIco(windowsResized));

  stdout.writeln('Updated desktop app icons from app_icon_source.png');
}
