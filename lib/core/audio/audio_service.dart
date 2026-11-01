import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays the narrator voice clips. Failures (missing plugin in tests, no audio device)
/// are swallowed: sound is never worth crashing a game.
class AudioService {
  AudioService({Random? random}) : _random = random ?? Random();

  final Random _random;
  AudioPlayer? _voice;

  /// Master switch, kept in sync with the Sound setting.
  bool enabled = true;

  /// Plays `assets/voice/<name>.mp3`, cutting off any clip still speaking.
  /// A name with `_02` variants may pass [variants] to pick one at random.
  Future<void> voice(String name, {int variants = 1}) async {
    if (!enabled) return;
    final n = variants <= 1 ? 1 : _random.nextInt(variants) + 1;
    final file = n == 1 ? name : '${name}_${n.toString().padLeft(2, '0')}';
    try {
      final p = _voice ??= AudioPlayer();
      await p.stop();
      await p.play(AssetSource('voice/$file.mp3'));
    } catch (e) {
      debugPrint('audio: $file failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _voice?.dispose();
    } catch (_) {}
  }
}
