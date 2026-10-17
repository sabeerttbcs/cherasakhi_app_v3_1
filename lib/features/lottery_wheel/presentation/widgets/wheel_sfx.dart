import 'package:audioplayers/audioplayers.dart';

/// Low-latency tick pool (fast ticks overlap) + win chime.
class WheelSfx {
  WheelSfx() {
    for (var i = 0; i < 4; i++) {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop).ignore();
      _ticks.add(p);
    }
  }

  final List<AudioPlayer> _ticks = [];
  final AudioPlayer _win = AudioPlayer();
  int _cursor = 0;

  void tick() {
    final p = _ticks[_cursor++ % _ticks.length];
    p.play(AssetSource('sounds/tick.wav'), volume: 0.55, mode: PlayerMode.lowLatency).ignore();
  }

  void win() {
    _win.play(AssetSource('sounds/win.wav'), volume: 0.9).ignore();
  }

  void dispose() {
    for (final p in _ticks) {
      p.dispose().ignore();
    }
    _win.dispose().ignore();
  }
}
