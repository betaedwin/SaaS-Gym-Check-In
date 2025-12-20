import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_formatting.dart';

const String kTrainingSnapshotLogoAsset = 'web/icons/Icon-512.png';
const String kTrainingSnapshotGymName = 'Jiu-Jitsu Gym';

Future<Uint8List> renderTrainingSnapshotPngBytes({
  required String memberName,
  required DateTime? memberSince,
  required int totalCheckIns,
  required Color accentColor,
  int sizePx = 1080,
}) async {
  if (memberName.trim().isEmpty) {
    throw ArgumentError('memberName must not be empty');
  }

  final logoBytes = await rootBundle.load(kTrainingSnapshotLogoAsset);
  final logoCodec = await ui.instantiateImageCodec(
    logoBytes.buffer.asUint8List(),
    targetWidth: (sizePx * 0.18).round(),
    targetHeight: (sizePx * 0.18).round(),
  );
  final logoFrame = await logoCodec.getNextFrame();
  final logoImage = logoFrame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, sizePx.toDouble(), sizePx.toDouble()),
  );

  const backgroundColor = Color(0xFF0F0F12);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, sizePx.toDouble(), sizePx.toDouble()),
    Paint()..color = backgroundColor,
  );

  final centerX = sizePx / 2.0;
  final logoSize = sizePx * 0.18;
  final logoCenterY = sizePx * 0.20;
  final logoRect = Rect.fromCenter(
    center: Offset(centerX, logoCenterY),
    width: logoSize,
    height: logoSize,
  );
  paintImage(
    canvas: canvas,
    rect: logoRect,
    image: logoImage,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );

  final gymNamePainter = TextPainter(
    text: const TextSpan(
      text: kTrainingSnapshotGymName,
      style: TextStyle(
        color: Colors.white,
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: sizePx.toDouble() * 0.85);
  gymNamePainter.paint(
    canvas,
    Offset(centerX - gymNamePainter.width / 2, sizePx * 0.32),
  );

  final dividerY = sizePx * 0.40;
  canvas.drawLine(
    Offset(sizePx * 0.22, dividerY),
    Offset(sizePx * 0.78, dividerY),
    Paint()
      ..color = accentColor.withAlpha((0.28 * 255).round())
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );

  final namePainter = TextPainter(
    text: TextSpan(
      text: memberName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: sizePx.toDouble() * 0.85);
  namePainter.paint(
    canvas,
    Offset(centerX - namePainter.width / 2, sizePx * 0.46),
  );

  final labelStyle = TextStyle(
    color: Colors.white.withAlpha((0.70 * 255).round()),
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
  const valueStyle = TextStyle(
    color: Colors.white,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  void paintCenteredText(String text, TextStyle style, double y) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: sizePx.toDouble() * 0.85);
    painter.paint(canvas, Offset(centerX - painter.width / 2, y));
  }

  paintCenteredText('Member since', labelStyle, sizePx * 0.64);
  paintCenteredText(
    memberSince == null ? '' : formatLocalDate(memberSince),
    valueStyle,
    sizePx * 0.68,
  );

  paintCenteredText('Total check-ins', labelStyle, sizePx * 0.76);
  paintCenteredText(totalCheckIns.toString(), valueStyle, sizePx * 0.80);

  final picture = recorder.endRecording();
  final image = await picture.toImage(sizePx, sizePx);
  final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (pngBytes == null) {
    throw StateError('Failed to encode snapshot as PNG');
  }
  return pngBytes.buffer.asUint8List();
}
