import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Store page used in every shared message (the player's friends land there).
const kStoreUrl =
    'https://play.google.com/store/apps/details?id=com.orbitcommando.orbit_commando';

/// Opens the system share sheet with a picture and a message.
abstract interface class ShareService {
  Future<bool> sharePng(Uint8List png, String text);
}

class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<bool> sharePng(Uint8List png, String text) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/orbit_commando_score.png');
      await f.writeAsBytes(png, flush: true);
      final r = await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile(f.path, mimeType: 'image/png')],
        ),
      );
      return r.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Share failed: $e');
      return false;
    }
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => const SystemShareService(),
);
