import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/audio/audio_service.dart';
import '../core/profile/profile_store.dart';
import '../core/services.dart';
import 'more_games_screen.dart';
import 'test_ids.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final p = s.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.grape,
        foregroundColor: Colors.white,
      ),
      body: KidPage(
        child: ListenableBuilder(
          listenable: p,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              KidPanel(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: TestIds.settingsSound,
                      title: const Text('Sound'),
                      subtitle: const Text('Master mute'),
                      value: p.data.soundOn,
                      onChanged: p.setSound,
                    ),
                    ListTile(
                      title: Text(
                        'Master volume: '
                        '${(p.data.masterVolume * 100).round()}%',
                      ),
                      subtitle: Slider(
                        key: TestIds.settingsVolume,
                        value: p.data.masterVolume,
                        divisions: 20,
                        onChanged: p.setMasterVolume,
                      ),
                    ),
                    _AmbienceRow(profile: p),
                    SwitchListTile(
                      key: TestIds.settingsVoice,
                      title: const Text('Voice'),
                      value: p.data.voiceOn,
                      onChanged: p.setVoice,
                    ),
                  ],
                ),
              ),
              KidPanel(
                child: ListTile(
                  title: const Text('Hand'),
                  subtitle: const Text('Mirrors back'),
                  trailing: SegmentedButton<bool>(
                    key: TestIds.settingsHand,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Right')),
                      ButtonSegment(value: true, label: Text('Left')),
                    ],
                    selected: {p.data.leftHanded},
                    onSelectionChanged: (v) => p.setLeftHanded(v.first),
                  ),
                ),
              ),
              KidPanel(
                child: SwitchListTile(
                  key: TestIds.settingsVibration,
                  title: const Text('Vibration'),
                  value: p.data.vibrationOn,
                  onChanged: p.setVibration,
                ),
              ),
              KidPanel(
                child: SwitchListTile(
                  key: TestIds.settingsReminders,
                  title: const Text('Daily reminder'),
                  subtitle: const Text('A local notification at 19:00'),
                  value: p.data.remindersOn,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await s.notifications.requestPermission();
                      if (!ok) return;
                      await s.notifications.scheduleDailyReminder(
                        hour: 19,
                        minute: 0,
                        title: s.config.displayName,
                        body: 'Your daily reward is waiting!',
                      );
                    } else {
                      await s.notifications.cancelAll();
                    }
                    await p.setReminders(v);
                  },
                ),
              ),
              KidPanel(
                child: SwitchListTile(
                  key: TestIds.settingsTips,
                  title: const Text('Show tips'),
                  subtitle: const Text('Small helpful cards now and then'),
                  value: p.tipsEnabled,
                  onChanged: p.setTipsEnabled,
                ),
              ),
              if (s.config.visibleMoreGames.isNotEmpty)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsMoreGames,
                    leading: const Icon(Icons.apps),
                    title: const Text('More games'),
                    onTap: () => openMoreGames(context),
                  ),
                ),
              if (s.share.hasLink)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsShareApp,
                    leading: const Icon(Icons.share),
                    title: const Text('Share app'),
                    onTap: s.share.shareApp,
                  ),
                ),
              if (s.ads.privacyOptionsRequired)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsPrivacy,
                    title: const Text('Ad privacy options'),
                    onTap: s.ads.showPrivacyOptions,
                  ),
                ),
              if (s.config.playGames.enabled)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsPlayGames,
                    title: const Text('Google Play Games'),
                    subtitle: Text(
                      s.identity.isSignedIn
                          ? 'Signed in as ${s.identity.current.displayName}. Progress is saved to your account.'
                          : 'Sign in to keep your score and progress',
                    ),
                    trailing: s.identity.isSignedIn
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: s.identity.isSignedIn
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await s.connectPlayGames();
                            if (!ok) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not sign in. Try again later.',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ),
              KidPanel(
                child: ListTile(
                  title: Text(s.config.displayName),
                  subtitle: Text(
                    kReleaseMode
                        ? 'Release build'
                        : 'Debug build (test ads only)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Background sound picker with a play button to hear a track before choosing it.
class _AmbienceRow extends StatefulWidget {
  const _AmbienceRow({required this.profile});
  final ProfileStore profile;

  @override
  State<_AmbienceRow> createState() => _AmbienceRowState();
}

class _AmbienceRowState extends State<_AmbienceRow> {
  final AmbiencePreview _preview = AmbiencePreview();

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.profile.data;
    // Ink text on the white panel: the dark app theme would otherwise paint it light.
    const style = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: KidColors.ink,
    );
    return ListTile(
      title: const Text('Background sound'),
      subtitle: Row(
        children: [
          DropdownButton<String>(
            key: TestIds.settingsAmbience,
            value: data.ambience,
            isDense: true,
            style: style,
            dropdownColor: Colors.white,
            iconEnabledColor: KidColors.ink,
            items: [
              for (final t in ambienceTracks)
                DropdownMenuItem(
                  value: t.$1,
                  child: Text(t.$2, style: style),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              widget.profile.setAmbience(v);
              if (_preview.playing != null) {
                _preview.stop().then((_) {
                  if (mounted) setState(() {});
                });
              }
            },
          ),
          IconButton(
            key: TestIds.settingsAmbiencePreview,
            tooltip: 'Preview',
            visualDensity: VisualDensity.compact,
            color: KidColors.ink,
            icon: Icon(
              _preview.playing == data.ambience
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
            ),
            onPressed: data.ambience == 'off'
                ? null
                : () async {
                    await _preview.toggle(data.ambience, data.masterVolume);
                    if (mounted) setState(() {});
                  },
          ),
        ],
      ),
    );
  }
}
