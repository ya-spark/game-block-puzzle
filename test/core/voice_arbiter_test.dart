import 'package:block_puzzle/core/audio/voice_arbiter.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeVoice implements VoiceOutput {
  final List<String> played = [];
  void Function()? _done;
  Duration left = const Duration(seconds: 3);

  @override
  Future<void> start(String asset, void Function() onFinished) async {
    played.add(asset);
    _done = onFinished;
  }

  @override
  Future<Duration?> remaining() async => left;

  void finish() => _done?.call();
}

void main() {
  test('priorities', () {
    expect(voicePriorityOf('game_over'), VoicePriority.high);
    expect(voicePriorityOf('better_than_the_best'), VoicePriority.high);
    for (final n in [
      'awesome',
      'combo',
      'excellent',
      'fantastic',
      'great',
      'incredible',
      'nice',
      'unbelievable',
      'unstoppable',
      'well_done',
      'you_did_it',
    ]) {
      expect(voicePriorityOf(n), VoicePriority.normal, reason: n);
    }
    expect(voicePriorityOf('get_ready'), VoicePriority.low);
    expect(voicePriorityOf('go'), VoicePriority.low);
    expect(voicePriorityOf('careful'), VoicePriority.low);
  });

  test('game_over waits for a praise line and plays after it', () async {
    final out = FakeVoice();
    final a = VoiceArbiter(out);
    await a.say('excellent', VoicePriority.normal);
    await a.say('game_over', VoicePriority.high);
    expect(out.played, ['excellent']);
    out.finish();
    expect(out.played, ['excellent', 'game_over']);
    out.finish();
    expect(a.speaking, isFalse);
  });

  test('newest waiting high line wins', () async {
    final out = FakeVoice();
    final a = VoiceArbiter(out);
    await a.say('excellent', VoicePriority.normal);
    await a.say('game_over', VoicePriority.high);
    await a.say('better_than_the_best', VoicePriority.high);
    out.finish();
    expect(out.played, ['excellent', 'better_than_the_best']);
  });

  test('a normal line is dropped while another is speaking', () async {
    final out = FakeVoice();
    final a = VoiceArbiter(out);
    await a.say('great', VoicePriority.normal);
    await a.say('nice', VoicePriority.normal);
    out.finish();
    expect(out.played, ['great']);
    expect(a.speaking, isFalse);
  });

  test(
    'a normal line within 1 s of the end waits; high pending beats it',
    () async {
      final out = FakeVoice()..left = const Duration(milliseconds: 800);
      final a = VoiceArbiter(out);
      await a.say('great', VoicePriority.normal);
      await a.say('go', VoicePriority.low);
      out.finish();
      expect(out.played, ['great', 'go']);
      await a.say('game_over', VoicePriority.high);
      await a.say('nice', VoicePriority.normal);
      out.finish();
      expect(out.played, ['great', 'go', 'game_over']);
    },
  );
}
