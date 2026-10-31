import 'package:flame_audio/flame_audio.dart';

class AppAudio {
  AppAudio._();
  static final AppAudio instance = AppAudio._();

  bool _enabled = true;
  bool _initialized = false;

  bool get enabled => _enabled;

  Future<void> init({bool enabled = true}) async {
    _enabled = enabled;
    if (_initialized) return;
    _initialized = true;
    FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll(['bleep.wav', 'bg_music.mp3']);
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      FlameAudio.bgm.stop();
    }
  }

  Future<void> playBleep() async {
    if (!_enabled) return;
    await FlameAudio.play('bleep.wav');
  }

  Future<void> startBgMusic() async {
    if (!_enabled) return;
    await FlameAudio.bgm.play('bg_music.mp3', volume: 0.25);
  }

  Future<void> stopBgMusic() async {
    await FlameAudio.bgm.stop();
  }

  void dispose() {
    FlameAudio.bgm.dispose();
  }
}
