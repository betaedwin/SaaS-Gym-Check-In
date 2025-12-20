import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'training_snapshot_renderer.dart';

Future<XFile> buildTrainingSnapshotXFile({
  required String memberName,
  required DateTime? memberSince,
  required int totalCheckIns,
  required Color accentColor,
}) async {
  final bytes = await renderTrainingSnapshotPngBytes(
    memberName: memberName,
    memberSince: memberSince,
    totalCheckIns: totalCheckIns,
    accentColor: accentColor,
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/training_snapshot.png');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(
    file.path,
    mimeType: 'image/png',
    name: 'training_snapshot.png',
  );
}
