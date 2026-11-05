import 'dart:typed_data';

/// Sharing through the system share sheet. The app sends nothing itself: the player picks
/// the target app. Game and UI code depend on this interface only.
abstract class ShareService {
  /// Shares a score; [image] is the share card PNG (may be null).
  Future<void> shareScore({required int score, Uint8List? image});

  Future<void> shareAchievement({required String title, Uint8List? image});

  /// Invites to the game. Does nothing while the app link is disabled.
  Future<void> shareApp();
}

/// Builds the texts and delegates the actual sending to [send].
abstract class BaseShareService implements ShareService {
  String get gameName;
  String get storeLink;
  bool get appLinkEnabled;

  String _withLink(String text) => appLinkEnabled ? '$text $storeLink' : text;

  String scoreText(int score) =>
      _withLink('I scored $score in $gameName! Can you beat it?');

  String achievementText(String title) =>
      _withLink('I unlocked "$title" in $gameName!');

  String appText() => _withLink('Try $gameName!');

  Future<void> send(String text, Uint8List? image);

  @override
  Future<void> shareScore({required int score, Uint8List? image}) =>
      send(scoreText(score), image);

  @override
  Future<void> shareAchievement({required String title, Uint8List? image}) =>
      send(achievementText(title), image);

  @override
  Future<void> shareApp() async {
    if (!appLinkEnabled) return;
    await send(appText(), null);
  }
}

/// Records what would be shared (tests).
class FakeShareService extends BaseShareService {
  FakeShareService({
    this.gameName = 'Block Puzzle',
    this.storeLink = 'https://play.google.com/store/apps/details?id=test',
    this.appLinkEnabled = false,
  });

  @override
  final String gameName;
  @override
  final String storeLink;
  @override
  final bool appLinkEnabled;

  final List<({String text, Uint8List? image})> sent = [];

  @override
  Future<void> send(String text, Uint8List? image) async =>
      sent.add((text: text, image: image));
}
