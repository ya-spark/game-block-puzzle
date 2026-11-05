import 'dart:typed_data';

/// Sharing through the system share sheet. The app sends nothing itself: the player picks
/// the target app. Game and UI code depend on this interface only.
abstract class ShareService {
  /// Shares a score; [image] is the share card PNG (may be null).
  Future<void> shareScore({required int score, Uint8List? image});

  Future<void> shareAchievement({required String title, Uint8List? image});

  /// True when share texts carry a link (and "Share app" is shown).
  bool get hasLink;

  /// Invites to the game. Does nothing while there is no share link.
  Future<void> shareApp();
}

/// Builds the texts and delegates the actual sending to [send].
abstract class BaseShareService implements ShareService {
  String get gameName;

  /// The link on its own line under the message; null adds none.
  String? get link;

  @override
  bool get hasLink => link != null;

  String _withLink(String text) => link == null ? text : '$text\n$link';

  String scoreText(int score) =>
      _withLink('This is my high score in $gameName: $score. Can you beat it?');

  String achievementText(String title) =>
      _withLink('I unlocked "$title" in $gameName! Can you beat it?');

  String appText() => _withLink('Try $gameName! Can you beat my score?');

  Future<void> send(String text, Uint8List? image);

  @override
  Future<void> shareScore({required int score, Uint8List? image}) =>
      send(scoreText(score), image);

  @override
  Future<void> shareAchievement({required String title, Uint8List? image}) =>
      send(achievementText(title), image);

  @override
  Future<void> shareApp() async {
    if (!hasLink) return;
    await send(appText(), null);
  }
}

/// Records what would be shared (tests).
class FakeShareService extends BaseShareService {
  FakeShareService({this.gameName = 'Block Puzzle', this.link});

  @override
  final String gameName;
  @override
  final String? link;

  final List<({String text, Uint8List? image})> sent = [];

  @override
  Future<void> send(String text, Uint8List? image) async =>
      sent.add((text: text, image: image));
}
